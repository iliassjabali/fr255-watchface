import Toybox.Lang;

// The next prayer of the day and its text.
// A day has six times, in minutes of the day:
// Fajr, sunrise, Dhuhr, Asr, Maghrib, Isha. Sunrise is not a prayer.
module PrayerSchedule {

    const FAJR = 0;
    const DHUHR = 1;
    const ASR = 2;
    const MAGHRIB = 3;
    const ISHA = 4;

    const MINUTES_IN_DAY = 1440;

    // The position of each prayer in the six times of a day.
    const TIME_INDEX = [0, 2, 3, 4, 5];
    // Short names, because the line on the screen is narrow.
    const NAMES = ["FAJR", "DHUHR", "ASR", "MAGH", "ISHA"];

    // The first prayer after now, as [prayer, minutes of the day].
    // After Isha it is the Fajr of tomorrow, or null if that time is unknown.
    function next(today as Array<Number>, fajrTomorrow as Number?, nowMinutes as Number) as Array<Number>? {
        for (var prayer = 0; prayer < TIME_INDEX.size(); prayer++) {
            var minutes = today[TIME_INDEX[prayer]];
            if (minutes > nowMinutes) {
                return [prayer, minutes];
            }
        }
        return (fajrTomorrow != null) ? [FAJR, fajrTomorrow] : null;
    }

    // Minutes of the day in UTC to the local time of the device.
    function toLocal(utcMinutes as Number, offsetSeconds as Number) as Number {
        return ((utcMinutes + offsetSeconds / 60) % MINUTES_IN_DAY + MINUTES_IN_DAY) % MINUTES_IN_DAY;
    }

    function name(prayer as Number) as String {
        return NAMES[prayer];
    }

    // The time as "13:15". A calculated time has a mark: "~13:15".
    function timeText(minutes as Number, official as Boolean) as String {
        var text = (minutes / 60).format("%02d") + ":" + (minutes % 60).format("%02d");
        return official ? text : "~" + text;
    }
}
