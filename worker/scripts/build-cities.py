#!/usr/bin/env python3
"""Build data/cities.json by matching Habous Arabic city names with GeoNames Morocco.

Usage:
    python3 -I scripts/build-cities.py FIXTURE_JS MA_TXT OUT_CITIES_JSON OUT_UNMATCHED_MD

Data: GeoNames (https://www.geonames.org), licensed CC BY 4.0.
Only the Python standard library is used. Input files are treated as data.
"""
import json
import re
import sys
import unicodedata

DIACRITICS = re.compile("[\u064b-\u065f\u0670\u0640\u200b-\u200f\u202a-\u202e]")  # harakat, tatweel, bidi marks
ALEF_FORMS = str.maketrans("أإآٱ", "اااا")
SPACES = re.compile(r"[\s\-_'’.]+")


def normalize(text):
    """Normalize Arabic: no diacritics/tatweel, one alef, ta marbuta -> ha, alef maqsura -> ya."""
    text = unicodedata.normalize("NFKC", text)
    text = DIACRITICS.sub("", text).translate(ALEF_FORMS)
    text = text.replace("ة", "ه").replace("ى", "ي")
    return SPACES.sub(" ", text).strip()


def strip_article(text):
    return text[2:] if text.startswith("ال") and len(text) > 3 else text


def read_habous(path):
    """Return (cities, mean_dhuhr) where cities is [(id, arabic name)] and mean_dhuhr maps id -> minutes."""
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    payload = re.search(r"\.push\((\{.*\})\);?\s*$", text.strip(), re.S)
    data = json.loads(payload.group(1))
    cities = [(city["c"], city["n"]) for city in data["villes"]]
    mean_dhuhr = {}
    for city in data["villes"]:
        minutes = [int(row[2][:2]) * 60 + int(row[2][3:]) for row in city["h"]]
        mean_dhuhr[city["c"]] = sum(minutes) / len(minutes)
    return cities, mean_dhuhr


def read_geonames(path):
    """Return a dict: normalized Arabic name -> list of (rank, name, lat, lon)."""
    index = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            cols = line.rstrip("\n").split("\t")
            if len(cols) < 15:
                continue
            _, name, _, alternates, lat, lon, feature_class = cols[:7]
            population = int(cols[14] or 0)
            rank = (feature_class == "P", population)
            for alternate in alternates.split(","):
                if not re.search("[؀-ۿ]", alternate):
                    continue
                for key in {normalize(alternate), strip_article(normalize(alternate))}:
                    index.setdefault(key, []).append((rank, name, float(lat), float(lon)))
    return index


def match(index, arabic_name):
    key = normalize(arabic_name)
    for candidate_key in (key, strip_article(key)):
        candidates = index.get(candidate_key)
        if candidates:
            return max(candidates, key=lambda item: item[0])
    return None


# Well-known coordinates (id -> lat, lon). Used for the sanity check and the Dhuhr calibration.
ANCHORS = {
    1: (34.02, -6.84),  # Rabat
    14: (35.76, -5.80),  # Tanger
    58: (33.57, -7.59),  # Casablanca
    81: (34.03, -5.00),  # Fes
    104: (31.63, -7.99),  # Marrakech
    117: (30.42, -9.60),  # Agadir
}
ANCHOR_TOLERANCE_DEGREES = 0.2
# Solar noon moves by 4 minutes per degree of longitude. A match whose longitude predicts a
# Dhuhr time more than this far from the published one is a wrong namesake and is rejected.
DHUHR_TOLERANCE_MINUTES = 1.5


def fit_dhuhr_model(mean_dhuhr):
    """Least squares line dhuhr = a + b * lon over the anchor cities."""
    xs = [ANCHORS[i][1] for i in ANCHORS]
    ys = [mean_dhuhr[i] for i in ANCHORS]
    mean_x, mean_y = sum(xs) / len(xs), sum(ys) / len(ys)
    slope = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys)) / sum((x - mean_x) ** 2 for x in xs)
    return mean_y - slope * mean_x, slope


def check_anchors(matched):
    by_id = {item["id"]: item for item in matched}
    failures = []
    for city_id, (lat, lon) in ANCHORS.items():
        item = by_id.get(city_id)
        if item is None or abs(item["lat"] - lat) > ANCHOR_TOLERANCE_DEGREES or abs(item["lon"] - lon) > ANCHOR_TOLERANCE_DEGREES:
            failures.append(city_id)
    return failures


def main(argv):
    fixture, geonames, out_json, out_md = argv
    habous, mean_dhuhr = read_habous(fixture)
    index = read_geonames(geonames)
    intercept, slope = fit_dhuhr_model(mean_dhuhr)
    matched, unmatched, rejected = [], [], []
    for city_id, arabic in habous:
        found = match(index, arabic)
        if not found:
            unmatched.append((city_id, arabic, "no GeoNames match"))
            continue
        _, _, lat, lon = found
        error = mean_dhuhr[city_id] - (intercept + slope * lon)
        if abs(error) > DHUHR_TOLERANCE_MINUTES:
            unmatched.append((city_id, arabic, f"namesake rejected: Dhuhr differs by {error:+.1f} min from its longitude"))
            rejected.append(city_id)
            continue
        matched.append({"id": city_id, "n": arabic, "lat": round(lat, 4), "lon": round(lon, 4)})
    matched.sort(key=lambda item: item["id"])
    with open(out_json, "w", encoding="utf-8") as handle:
        rows = [json.dumps(item, ensure_ascii=False) for item in matched]
        handle.write("[\n" + ",\n".join(rows) + "\n]\n")
    lines = [
        "# Cities without coordinates",
        "",
        "These Habous cities are left out of `cities.json`: GeoNames has no Arabic match, or the",
        "match is a namesake elsewhere (its longitude contradicts the published Dhuhr time).",
        "Coordinates are never invented. Add them by hand after a review.",
        "",
        f"{len(unmatched)} of {len(habous)} cities are unmatched.",
        "",
        "| id | name | reason |",
        "|---|---|---|",
    ]
    lines += [f"| {city_id} | {name} | {reason} |" for city_id, name, reason in sorted(unmatched)]
    with open(out_md, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")
    print(f"matched {len(matched)} / {len(habous)} ({len(rejected)} namesakes rejected)")
    failures = check_anchors(matched)
    if failures:
        sys.exit(f"sanity check failed for city ids {failures}")
    print("sanity check passed for the six anchor cities")


if __name__ == "__main__":
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    main(sys.argv[1:])
