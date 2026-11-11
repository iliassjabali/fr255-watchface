import Toybox.Lang;
import Toybox.Test;

// Unit tests for the prayer time calculation.
// The times are minutes of the day in UTC, in the order:
// Fajr, sunrise, Dhuhr, Asr, Maghrib, Isha.
// The expected values come from a reference calculation with the same
// standard formulas (Fajr 19 degrees, Isha 17 degrees, standard Asr).

const CASABLANCA_LAT = 33.5731d;
const CASABLANCA_LON = -7.5898d;

function assertTimesNear(actual as Array<Number>, expected as Array<Number>, tolerance as Number) as Void {
    Test.assertEqual(actual.size(), 6);
    for (var i = 0; i < 6; i++) {
        var difference = actual[i] - expected[i];
        if (difference < 0) {
            difference = -difference;
        }
        Test.assertMessage(difference <= tolerance,
            "time " + i + ": got " + actual[i] + ", expected " + expected[i]);
    }
}

(:test)
function prayerCalcCasablancaInNovember(logger as Logger) as Boolean {
    assertTimesNear(PrayerCalc.times(CASABLANCA_LAT, CASABLANCA_LON, 2026, 11, 11),
        [328, 418, 734, 909, 1050, 1131], 1);
    return true;
}

(:test)
function prayerCalcCasablancaAtTheSummerSolstice(logger as Logger) as Boolean {
    assertTimesNear(PrayerCalc.times(CASABLANCA_LAT, CASABLANCA_LON, 2026, 6, 21),
        [210, 321, 752, 976, 1184, 1281], 1);
    return true;
}

(:test)
function prayerCalcCasablancaInJanuary(logger as Logger) as Boolean {
    assertTimesNear(PrayerCalc.times(CASABLANCA_LAT, CASABLANCA_LON, 2026, 1, 15),
        [362, 455, 760, 926, 1065, 1148], 1);
    return true;
}

(:test)
function prayerCalcTangerIsEarlierInTheEvening(logger as Logger) as Boolean {
    assertTimesNear(PrayerCalc.times(35.7595d, -5.8340d, 2026, 11, 15),
        [326, 419, 728, 896, 1036, 1120], 1);
    return true;
}

(:test)
function prayerCalcAgadirInOctober(logger as Logger) as Boolean {
    assertTimesNear(PrayerCalc.times(30.4278d, -9.5981d, 2026, 10, 15),
        [316, 401, 744, 940, 1087, 1163], 1);
    return true;
}

// The official Habous times for Casablanca on 2026-11-11 are
// 05:28 06:55 12:20 15:10 17:35 18:51 (GMT). Fajr, Asr and Isha have no
// margin in the official timetable, thus the calculation must agree.
(:test)
function prayerCalcAgreesWithHabousForFajrAsrAndIsha(logger as Logger) as Boolean {
    var times = PrayerCalc.times(CASABLANCA_LAT, CASABLANCA_LON, 2026, 11, 11);
    assertTimesNear([times[0], times[3], times[5], 0, 0, 0], [328, 910, 1131, 0, 0, 0], 1);
    return true;
}

(:test)
function prayerCalcGivesTimesInTheOrderOfTheDay(logger as Logger) as Boolean {
    var times = PrayerCalc.times(CASABLANCA_LAT, CASABLANCA_LON, 2026, 3, 20);
    for (var i = 1; i < 6; i++) {
        Test.assert(times[i] > times[i - 1]);
    }
    return true;
}

// The official timetable has fixed margins: 3 minutes before sunrise, and
// 5 minutes after Dhuhr and Maghrib. With these margins, the calculation at
// the position of a city must agree with the official row of that city.
// The rows are from the Habous files for October and November 2026 (GMT).

(:test)
function prayerCalcWithMarginsAgreesWithHabousInCasablanca(logger as Logger) as Boolean {
    // 05:28 06:55 12:20 15:10 17:35 18:51
    assertTimesNear(PrayerCalc.officialTimes(CASABLANCA_LAT, CASABLANCA_LON, 2026, 11, 11),
        [328, 415, 740, 910, 1055, 1131], 1);
    // 05:04 06:29 12:22 15:33 18:06 19:20
    assertTimesNear(PrayerCalc.officialTimes(CASABLANCA_LAT, CASABLANCA_LON, 2026, 10, 11),
        [304, 389, 742, 933, 1086, 1160], 1);
    // 05:36 07:04 12:22 15:06 17:30 18:47
    assertTimesNear(PrayerCalc.officialTimes(CASABLANCA_LAT, CASABLANCA_LON, 2026, 11, 21),
        [336, 424, 742, 906, 1050, 1127], 1);
    return true;
}

(:test)
function prayerCalcWithMarginsAgreesWithHabousInTanger(logger as Logger) as Boolean {
    // 05:25 06:55 12:13 14:56 17:21 18:40
    assertTimesNear(PrayerCalc.officialTimes(35.7595d, -5.8340d, 2026, 11, 15),
        [325, 415, 733, 896, 1041, 1120], 1);
    return true;
}

(:test)
function prayerCalcWithMarginsAgreesWithHabousInAgadir(logger as Logger) as Boolean {
    // 05:15 06:37 12:29 15:40 18:12 19:23
    assertTimesNear(PrayerCalc.officialTimes(30.4278d, -9.5981d, 2026, 10, 15),
        [315, 397, 749, 940, 1092, 1163], 1);
    return true;
}

(:test)
function prayerCalcMarginsChangeOnlySunriseDhuhrAndMaghrib(logger as Logger) as Boolean {
    var pure = PrayerCalc.times(CASABLANCA_LAT, CASABLANCA_LON, 2026, 11, 11);
    var official = PrayerCalc.officialTimes(CASABLANCA_LAT, CASABLANCA_LON, 2026, 11, 11);
    Test.assertEqual(official[0], pure[0]);
    Test.assertEqual(official[1], pure[1] - 3);
    Test.assertEqual(official[2], pure[2] + 5);
    Test.assertEqual(official[3], pure[3]);
    Test.assertEqual(official[4], pure[4] + 5);
    Test.assertEqual(official[5], pure[5]);
    return true;
}
