import Toybox.Lang;
import Toybox.Test;

// Unit tests for the selection and the text of the next prayer.
// A day has six times: Fajr, sunrise, Dhuhr, Asr, Maghrib, Isha.
// Sunrise is not a prayer, thus the next prayer is never the sunrise.
// The next sun event is the sunrise or the sunset (Maghrib).

const SCHEDULE_DAY = [328, 418, 734, 909, 1050, 1131];
const SCHEDULE_TOMORROW = [329, 417, 734, 909, 1049, 1130];

(:test)
function scheduleNextIsFajrBeforeDawn(logger as Logger) as Boolean {
    var next = PrayerSchedule.next(SCHEDULE_DAY, 329, 300) as Array<Number>;
    Test.assertEqual(next[0], PrayerSchedule.FAJR);
    Test.assertEqual(next[1], 328);
    return true;
}

(:test)
function scheduleNextSkipsTheSunrise(logger as Logger) as Boolean {
    var next = PrayerSchedule.next(SCHEDULE_DAY, 329, 400) as Array<Number>;
    Test.assertEqual(next[0], PrayerSchedule.DHUHR);
    Test.assertEqual(next[1], 734);
    return true;
}

(:test)
function scheduleNextIsTheFollowingPrayerAtTheExactTime(logger as Logger) as Boolean {
    var next = PrayerSchedule.next(SCHEDULE_DAY, 329, 734) as Array<Number>;
    Test.assertEqual(next[0], PrayerSchedule.ASR);
    Test.assertEqual(next[1], 909);
    return true;
}

(:test)
function scheduleNextIsIshaInTheEvening(logger as Logger) as Boolean {
    var next = PrayerSchedule.next(SCHEDULE_DAY, 329, 1100) as Array<Number>;
    Test.assertEqual(next[0], PrayerSchedule.ISHA);
    Test.assertEqual(next[1], 1131);
    return true;
}

(:test)
function scheduleNextIsTheFajrOfTomorrowAfterIsha(logger as Logger) as Boolean {
    var next = PrayerSchedule.next(SCHEDULE_DAY, 329, 1131) as Array<Number>;
    Test.assertEqual(next[0], PrayerSchedule.FAJR);
    Test.assertEqual(next[1], 329);
    return true;
}

(:test)
function scheduleNextIsNullAfterIshaWithNoDataForTomorrow(logger as Logger) as Boolean {
    Test.assert(PrayerSchedule.next(SCHEDULE_DAY, null, 1200) == null);
    return true;
}

(:test)
function scheduleToLocalAddsTheOffsetOfTheDevice(logger as Logger) as Boolean {
    Test.assertEqual(PrayerSchedule.toLocal(734, 0), 734);
    Test.assertEqual(PrayerSchedule.toLocal(734, 3600), 794);
    return true;
}

(:test)
function scheduleToLocalWrapsAtMidnight(logger as Logger) as Boolean {
    Test.assertEqual(PrayerSchedule.toLocal(1430, 3600), 50);
    Test.assertEqual(PrayerSchedule.toLocal(10, -3600), 1390);
    return true;
}

(:test)
function scheduleGlyphIsTheCharacterOfThePrayerFont(logger as Logger) as Boolean {
    Test.assertEqual(PrayerSchedule.glyph(PrayerSchedule.FAJR), "0");
    Test.assertEqual(PrayerSchedule.glyph(PrayerSchedule.DHUHR), "1");
    Test.assertEqual(PrayerSchedule.glyph(PrayerSchedule.ASR), "2");
    Test.assertEqual(PrayerSchedule.glyph(PrayerSchedule.MAGHRIB), "3");
    Test.assertEqual(PrayerSchedule.glyph(PrayerSchedule.ISHA), "4");
    return true;
}

(:test)
function scheduleTimeTextIsPaddedTo24Hours(logger as Logger) as Boolean {
    Test.assertEqual(PrayerSchedule.timeText(795, true), "13:15");
    Test.assertEqual(PrayerSchedule.timeText(5, true), "00:05");
    return true;
}

(:test)
function scheduleTimeTextMarksACalculatedTime(logger as Logger) as Boolean {
    Test.assertEqual(PrayerSchedule.timeText(795, false), "~13:15");
    return true;
}

(:test)
function scheduleNextSunIsTheSunriseBeforeDawn(logger as Logger) as Boolean {
    var sun = PrayerSchedule.nextSun(SCHEDULE_DAY, SCHEDULE_TOMORROW, 300) as Array<Number>;
    Test.assertEqual(sun[0], PrayerSchedule.SUNRISE);
    Test.assertEqual(sun[1], 418);
    return true;
}

(:test)
function scheduleNextSunIsTheSunsetDuringTheDay(logger as Logger) as Boolean {
    var sun = PrayerSchedule.nextSun(SCHEDULE_DAY, SCHEDULE_TOMORROW, 734) as Array<Number>;
    Test.assertEqual(sun[0], PrayerSchedule.SUNSET);
    Test.assertEqual(sun[1], 1050);
    return true;
}

(:test)
function scheduleNextSunIsTheSunriseOfTomorrowAfterTheSunset(logger as Logger) as Boolean {
    var sun = PrayerSchedule.nextSun(SCHEDULE_DAY, SCHEDULE_TOMORROW, 1200) as Array<Number>;
    Test.assertEqual(sun[0], PrayerSchedule.SUNRISE);
    Test.assertEqual(sun[1], 417);
    return true;
}

(:test)
function scheduleNextSunIsNullAfterTheSunsetWithNoDataForTomorrow(logger as Logger) as Boolean {
    Test.assert(PrayerSchedule.nextSun(SCHEDULE_DAY, null, 1200) == null);
    return true;
}

(:test)
function scheduleNextSunIsTheSunsetAtTheExactSunrise(logger as Logger) as Boolean {
    var sun = PrayerSchedule.nextSun(SCHEDULE_DAY, SCHEDULE_TOMORROW, 418) as Array<Number>;
    Test.assertEqual(sun[0], PrayerSchedule.SUNSET);
    Test.assertEqual(sun[1], 1050);
    return true;
}

(:test)
function scheduleNextSunIsTheSunriseOfTomorrowAtTheExactSunset(logger as Logger) as Boolean {
    var sun = PrayerSchedule.nextSun(SCHEDULE_DAY, SCHEDULE_TOMORROW, 1050) as Array<Number>;
    Test.assertEqual(sun[0], PrayerSchedule.SUNRISE);
    Test.assertEqual(sun[1], 417);
    return true;
}
