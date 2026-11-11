# FR255 Test Face

A Connect IQ watch face for the Garmin Forerunner 255 (`fr255`), with a small
Cloudflare Worker that gives it the official prayer times for Morocco.

## What the watch face shows

- **Center:** the minutes, large, in blue.
- **Rings**, from the edge to the center: heart rate (red), Body Battery
  (blue), stress (orange). The rings are open at the bottom.
- **Top:** the hour, the date, and the next prayer.
- **In the opening of the rings:** the next calendar event with a countdown,
  then the watch battery, the phone connection and the weather.

## Repository

| Path | Content |
|---|---|
| `source/` | The watch face, in Monkey C |
| `test/` | The unit tests of the watch face |
| `resources/` | The name, the launcher icon and the digit fonts |
| `worker/` | The Cloudflare Worker, in TypeScript. See `worker/README.md` |
| `tools/` | Scripts: fonts, CI build, copy to the watch |
| `design/layouts.html` | The layouts that were considered. Open it in a browser |
| `docs/INSTALL.txt` | The install steps for a person who gets the zip file |
| `ci/devices/` | The device file that the CI build needs |
| `CLAUDE.md` | The onboarding and the rules for an AI agent |

## Get the watch face with no build

Each release has `fr255-watchface.zip`, with the `.prg` file and the install
steps. Open the **Releases** page of the repository and download the zip file
of the last release. The repository is private, thus only people with access
can download it. For a person with no access, send the zip file.

The file is for the standard Forerunner 255. The 255 Music, the 255s and the
255s Music need their own build.

## Requirements for a build

- Connect IQ SDK 9.3.0, with the Forerunner 255 device, from the SDK Manager.
- Java 11 or higher.
- A developer key outside the repository, for example
  `~/.garmin/connectiq/developer_key.der`.

Put the SDK tools on the `PATH`:

```bash
export PATH=$PATH:`cat $HOME/Library/Application\ Support/Garmin/ConnectIQ/current-sdk.cfg`/bin
```

`CLAUDE.md` has the full onboarding, with a check for each step.

## Build and run

```bash
monkeyc -d fr255 -f monkey.jungle -o bin/fr255-watchface.prg -y ~/.garmin/connectiq/developer_key.der -w
connectiq
monkeydo bin/fr255-watchface.prg fr255
```

If the simulator window stays empty, stop the simulator and start it again.

## Tests

The unit tests are in `test/`. They use the Connect IQ test framework and run
in the simulator.

```bash
monkeyc -d fr255 -f monkey.jungle -o bin/test.prg -y ~/.garmin/connectiq/developer_key.der --unit-test
connectiq
monkeydo bin/test.prg fr255 -t
```

The tests cover the logic that has no access to the device:

- `source/EventTime.mc`: the minutes to the next calendar event and the
  countdown text.
- `source/Rings.mc`: the filled part of each ring, in degrees.
- `source/PrayerCalc.mc`: the prayer times from the position of the sun.
- `source/PrayerSchedule.mc`: the next prayer and its text.
- `source/PrayerStore.mc`: the official times that the web service sent.

The drawing code in `source/View.mc` has no unit tests. Check it in the
simulator or on the watch.

The Worker has its own tests. See `worker/README.md`.

## Install on a watch

Copy `bin/fr255-watchface.prg` to the `GARMIN/APPS` folder of the watch. The
Forerunner 255 uses MTP, thus macOS needs an MTP tool such as OpenMTP.

With OpenMTP installed, this script does the copy:

```bash
python3 tools/push_to_watch.py
```

Close OpenMTP and Garmin Express first. `docs/INSTALL.txt` has the steps for
Windows and for the selection of the watch face on the watch.

## Prayer times

The watch face shows the next prayer below the date, for example
`DHUHR 13:15`.

- **Near a listed city (25 km or less):** a background service asks the
  Worker for the official times of the Ministry of Habous. The request goes
  through the phone, one time for each day. The time shows with no mark.
- **In all other cases** (far from a listed city, no phone, no answer):
  `source/PrayerCalc.mc` calculates the times at the exact position of the
  watch: Fajr at 19 degrees, Isha at 17 degrees, standard Asr. It adds the
  margins of the official timetable: 3 minutes before sunrise, and 5 minutes
  after Dhuhr and Maghrib. The time shows with a mark, for example `~13:15`.
- **Accuracy of the calculation:** it agrees with the official times to 1
  minute for Casablanca, Tanger and Agadir, in October and November 2026.
  These comparisons are unit tests. The ministry published only these two
  months at the time of the work.
- **Position:** the weather position, the position of the last activity, the
  last kept position, then Casablanca. The watch does not start the GPS.
- **Privacy:** the watch sends its position to the Worker with two decimals,
  which is about 1 km.

The address of the Worker is in `source/Config.mc`.

## The Worker

`worker/` is a Cloudflare Worker with one route, `GET /prayers?lat&lon`. It
reads the month file of the ministry, finds the nearest listed city, and
gives the times of today and tomorrow as a small JSON. `worker/README.md` has
the API, the tests and the city data.

**Protection against abuse**

- **Rate limit:** 20 requests for each 60 seconds for each IP address, with
  the native Workers Rate Limiting binding of Cloudflare. It is set in
  `worker/wrangler.toml`, and `wrangler deploy` creates it. More requests get
  the code 429. Cloudflare counts in each of its locations, thus the limit is
  approximate, not exact.
- **Validation:** only the parameters `lat`, `lon` and `date`, a strict number
  format, the GET method only, and an address of 200 characters at most.

**Deploy:** the CI deploys the Worker. See the next section.

## CI

`.github/workflows/build.yml` runs on GitHub for each push to `main`, each
pull request, and each tag that starts with `v`. It has three jobs.

**Watch face**

1. It downloads the Connect IQ SDK for Linux from the public list of Garmin,
   and keeps it in the cache for the next runs. No Garmin login is necessary.
2. It puts the device file `ci/devices/fr255/compiler.json` in the Garmin
   folder. The compiler needs only this file of the device.
3. It gets a developer key. If the secret `CIQ_DEVELOPER_KEY_B64` exists, the
   key comes from it. If not, the run makes a new key.
4. `tools/ci_build.sh` builds the watch face, compiles the unit tests, and
   makes `fr255-watchface.zip` with the `.prg` file and `docs/INSTALL.txt`.
5. It keeps the zip file as an artifact of the run.
6. For a tag, it also attaches the zip file to a GitHub release.

**Worker**

It installs the packages, checks the types, and runs the Vitest tests.

**Deploy Worker**

It runs only on `main`, and only after the Worker job passes. It deploys the
Worker to Cloudflare with `wrangler deploy` when the folder `worker/` changed
in the push. A manual run of the workflow on `main` always deploys.

It needs two secrets of the repository:

- `CLOUDFLARE_API_TOKEN`: an API token from the Cloudflare dashboard, with the
  Workers permissions of the account. The template "Edit Cloudflare Workers"
  gives them. The zone permission of the template is not necessary, because
  the Worker uses the `workers.dev` address.
- `CLOUDFLARE_ACCOUNT_ID`: the ID of the Cloudflare account.

With no token, the job makes no deploy and shows a warning on the run.

**Make a release**

```bash
git tag -a v1.1.0 -m "Version 1.1.0"
git push origin v1.1.0
```

The CI then makes the release and attaches `fr255-watchface.zip`.

**Download the zip file of a run**

Open the **Actions** tab, open a run of "Build", and download
`fr255-watchface` in the section **Artifacts**. GitHub removes an artifact
after 90 days. A release keeps its zip file.

**Limits**

- The CI does not run the Monkey C unit tests, because they need the
  simulator. It only proves that they compile. Run them on your computer.
- With no key secret, each run signs the build with a new key. A file for a
  cable install works with all keys. To sign each build with your own key,
  store it as a secret:
  `base64 -i ~/.garmin/connectiq/developer_key.der | gh secret set CIQ_DEVELOPER_KEY_B64`

**Run the build script on your computer**

```bash
CIQ_SDK="$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")" \
CIQ_KEY="$HOME/.garmin/connectiq/developer_key.der" tools/ci_build.sh
```

## Fonts

The watch has no number font that is large enough for the minutes. The digit
fonts in `resources/fonts` are Roboto Black (Apache License 2.0). To make them
again, run:

```bash
python3 tools/make_fonts.py
```

The script needs Google Chrome and an internet connection.

## Platform limits

- A watch face cannot call the web. It uses a background service, with 5
  minutes at the minimum between two runs.
- Garmin gives only the time of the next calendar event to a watch face. The
  event name is not available.
- The screen has 64 colors, and the smallest text font is `FONT_XTINY`.

## Data and licenses

- Prayer times: the month files of the Ministry of Habous and Islamic Affairs,
  `https://www.habous.gov.ma/data/horaires-YYYY-MM.js`. The site states no
  license for them.
- City coordinates: GeoNames (https://www.geonames.org), CC BY 4.0.
- Digit fonts: Roboto Black, Apache License 2.0.
