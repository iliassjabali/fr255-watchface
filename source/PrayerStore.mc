import Toybox.Lang;

// The official prayer times that the web service sent, as kept in Storage.
// The value is the JSON of the service:
// { "city" => 58, "date" => "2026-11-11", "today" => [...], "tomorrow" => [...] }
// The times are minutes of the day in UTC. The module has no access to the
// device, thus the unit tests and the background service can use it.
(:background)
module PrayerStore {

    // Storage keys.
    const KEY = "prayers";
    const POSITION_KEY = "pos";

    // The official times of today, or null if the data is absent or too old.
    // Data from yesterday is still useful: its row for tomorrow is today.
    function today(data, todayText as String, yesterdayText as String) as Array<Number>? {
        if (!(data instanceof Dictionary)) {
            return null;
        }
        var date = data["date"];
        if (todayText.equals(date)) {
            return row(data, "today");
        }
        if (yesterdayText.equals(date)) {
            return row(data, "tomorrow");
        }
        return null;
    }

    // The official Fajr of tomorrow, or null if the service did not send it.
    function fajrTomorrow(data, todayText as String) as Number? {
        if (!(data instanceof Dictionary) || !todayText.equals(data["date"])) {
            return null;
        }
        var times = row(data, "tomorrow");
        return (times != null) ? times[0] : null;
    }

    // True if the data is from today, thus no new request is necessary.
    function isFresh(data, todayText as String) as Boolean {
        return (data instanceof Dictionary) && todayText.equals(data["date"]) && row(data, "today") != null;
    }

    // A date as "2026-03-05", the format of the web service.
    function dateText(year as Number, month as Number, day as Number) as String {
        return year.format("%04d") + "-" + month.format("%02d") + "-" + day.format("%02d");
    }

    // The six times of one row, or null if the row is absent or not complete.
    function row(data as Dictionary, key as String) as Array<Number>? {
        var times = data[key];
        if (times instanceof Array && times.size() == 6) {
            return times as Array<Number>;
        }
        return null;
    }
}
