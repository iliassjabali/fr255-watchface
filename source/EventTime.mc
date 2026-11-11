import Toybox.Lang;

// Pure logic for the next calendar event. It has no access to the clock or
// the device settings, thus the unit tests can call it with fixed values.
module EventTime {

    const MINUTES_IN_DAY = 1440;

    // The minutes from now to an event time such as "12:00", "3:00p" or "3:00 PM".
    // nowMinutes is the number of minutes since midnight.
    // Returns null if the text is not a time.
    function minutesUntil(time as String, nowMinutes as Number, is24Hour as Boolean) as Number? {
        var colon = time.find(":");
        if (colon == null || colon == 0) {
            return null;
        }
        var hour = time.substring(0, colon).toNumber();
        var minute = time.substring(colon + 1, colon + 3).toNumber();
        if (hour == null || minute == null) {
            return null;
        }

        var lower = time.toLower();
        var isPm = lower.find("p") != null;
        var isAm = lower.find("a") != null;

        if (isPm || isAm) {
            if (isPm && hour < 12) {
                hour += 12;
            } else if (isAm && hour == 12) {
                hour = 0;
            }
            return wait(hour, minute, nowMinutes);
        }

        // A 12-hour time with no AM or PM mark: use the nearest future occurrence.
        if (!is24Hour && hour <= 12) {
            var morning = wait(hour % 12, minute, nowMinutes);
            var afternoon = wait(hour % 12 + 12, minute, nowMinutes);
            return (morning < afternoon) ? morning : afternoon;
        }
        return wait(hour, minute, nowMinutes);
    }

    // The minutes from nowMinutes to the next occurrence of hour:minute.
    function wait(hour as Number, minute as Number, nowMinutes as Number) as Number {
        return (hour * 60 + minute - nowMinutes + MINUTES_IN_DAY) % MINUTES_IN_DAY;
    }

    // The countdown as text: "now", "in 45 min" or "in 2 h 05".
    function countdownText(minutes as Number) as String {
        if (minutes == 0) {
            return "now";
        }
        if (minutes < 60) {
            return "in " + minutes + " min";
        }
        return "in " + (minutes / 60) + " h " + (minutes % 60).format("%02d");
    }
}
