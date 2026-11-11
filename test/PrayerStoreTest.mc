import Toybox.Lang;
import Toybox.Test;

// Unit tests for the official times that the web service sent.
// The stored value is the JSON of the service:
// { "city" => 58, "date" => "2026-11-11", "today" => [...], "tomorrow" => [...] }

function storedDay() as Dictionary {
    return {
        "city" => 58,
        "date" => "2026-11-11",
        "today" => [328, 415, 740, 910, 1055, 1131],
        "tomorrow" => [329, 416, 740, 909, 1054, 1130]
    };
}

(:test)
function storeGivesTheTimesOfToday(logger as Logger) as Boolean {
    var times = PrayerStore.today(storedDay(), "2026-11-11", "2026-11-10") as Array<Number>;
    Test.assertEqual(times[0], 328);
    Test.assertEqual(times[5], 1131);
    return true;
}

// The watch got the data yesterday and has no phone today.
(:test)
function storeUsesTheTomorrowRowOnTheNextDay(logger as Logger) as Boolean {
    var times = PrayerStore.today(storedDay(), "2026-11-12", "2026-11-11") as Array<Number>;
    Test.assertEqual(times[0], 329);
    Test.assertEqual(times[5], 1130);
    return true;
}

(:test)
function storeGivesNothingForOldData(logger as Logger) as Boolean {
    Test.assert(PrayerStore.today(storedDay(), "2026-11-13", "2026-11-12") == null);
    return true;
}

(:test)
function storeGivesNothingOnTheNextDayWithNoTomorrowRow(logger as Logger) as Boolean {
    var data = storedDay();
    data.remove("tomorrow");
    Test.assert(PrayerStore.today(data, "2026-11-12", "2026-11-11") == null);
    return true;
}

(:test)
function storeGivesNothingForValuesThatAreNotTheServiceData(logger as Logger) as Boolean {
    Test.assert(PrayerStore.today(null, "2026-11-11", "2026-11-10") == null);
    Test.assert(PrayerStore.today(-104, "2026-11-11", "2026-11-10") == null);
    Test.assert(PrayerStore.today({ "date" => "2026-11-11" }, "2026-11-11", "2026-11-10") == null);
    Test.assert(PrayerStore.today({ "date" => "2026-11-11", "today" => [1, 2, 3] }, "2026-11-11", "2026-11-10") == null);
    return true;
}

(:test)
function storeGivesTheFajrOfTomorrow(logger as Logger) as Boolean {
    Test.assertEqual(PrayerStore.fajrTomorrow(storedDay(), "2026-11-11"), 329);
    return true;
}

(:test)
function storeGivesNoFajrOfTomorrowWhenTheRowIsAbsentOrOld(logger as Logger) as Boolean {
    var data = storedDay();
    data.remove("tomorrow");
    Test.assert(PrayerStore.fajrTomorrow(data, "2026-11-11") == null);
    Test.assert(PrayerStore.fajrTomorrow(storedDay(), "2026-11-12") == null);
    return true;
}

(:test)
function storeGivesTheTimesOfTomorrow(logger as Logger) as Boolean {
    var times = PrayerStore.tomorrow(storedDay(), "2026-11-11") as Array<Number>;
    Test.assertEqual(times[1], 416);
    Test.assertEqual(times[4], 1054);
    return true;
}

(:test)
function storeGivesNoTimesOfTomorrowWhenTheRowIsAbsentOrOld(logger as Logger) as Boolean {
    var data = storedDay();
    data.remove("tomorrow");
    Test.assert(PrayerStore.tomorrow(data, "2026-11-11") == null);
    Test.assert(PrayerStore.tomorrow(storedDay(), "2026-11-12") == null);
    Test.assert(PrayerStore.tomorrow(null, "2026-11-11") == null);
    return true;
}

(:test)
function storeIsFreshOnlyForTheDataOfToday(logger as Logger) as Boolean {
    Test.assert(PrayerStore.isFresh(storedDay(), "2026-11-11"));
    Test.assert(!PrayerStore.isFresh(storedDay(), "2026-11-12"));
    Test.assert(!PrayerStore.isFresh(null, "2026-11-11"));
    return true;
}

(:test)
function storeDateTextIsPadded(logger as Logger) as Boolean {
    Test.assertEqual(PrayerStore.dateText(2026, 3, 5), "2026-03-05");
    return true;
}
