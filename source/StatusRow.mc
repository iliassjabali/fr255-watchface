import Toybox.Lang;

// Pure logic for the status row: the battery level, the alarm and the width
// of a row of parts. It has no access to the device.
module StatusRow {

    const LOW_PERCENT = 20;

    // The battery level as a whole number from 0 to 100, rounded to the
    // nearest. No data gives 0.
    function percent(battery as Float?) as Number {
        if (battery == null || battery <= 0.0) {
            return 0;
        }
        if (battery >= 100.0) {
            return 100;
        }
        return (battery + 0.5).toNumber();
    }

    // The text for the battery days that remain: a whole number of days and
    // the letter d, or "<1d" under one day. No data gives the percentage.
    function daysText(days as Float?, percent as Number) as String {
        if (days == null) {
            return percent.toString() + "%";
        }
        if (days < 1.0) {
            return "<1d";
        }
        return (days + 0.5).toNumber().toString() + "d";
    }

    // The width in pixels of the level bar, from 0 to the inner width.
    function fillWidth(percent as Number, innerWidth as Number) as Number {
        if (percent <= 0) {
            return 0;
        }
        var fill = (innerWidth * percent) / 100;
        return (fill > innerWidth) ? innerWidth : fill;
    }

    // True when the battery level is low.
    function isLow(percent as Number) as Boolean {
        return percent <= LOW_PERCENT;
    }

    // True when at least one alarm is set.
    function hasAlarm(alarmCount as Number?) as Boolean {
        return alarmCount != null && alarmCount >= 1;
    }

    // The total width of a row of parts, with the gap between two parts.
    function width(parts as Array<Number>, gap as Number) as Number {
        var total = 0;
        for (var i = 0; i < parts.size(); i++) {
            total += parts[i];
            if (i > 0) {
                total += gap;
            }
        }
        return total;
    }
}
