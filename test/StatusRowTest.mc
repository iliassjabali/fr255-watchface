import Toybox.Lang;
import Toybox.Test;

// Unit tests for the status row: the battery level, the alarm and the width of
// a row of parts.

(:test)
function statusPercentIsZeroWithNoData(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.percent(null), 0);
    return true;
}

(:test)
function statusPercentRoundsDown(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.percent(61.4), 61);
    Test.assertEqual(StatusRow.percent(0.4), 0);
    return true;
}

(:test)
function statusPercentRoundsHalfUp(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.percent(61.5), 62);
    return true;
}

(:test)
function statusPercentIsFullAtTheTop(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.percent(99.6), 100);
    Test.assertEqual(StatusRow.percent(100.0), 100);
    return true;
}

(:test)
function statusPercentStopsAtOneHundred(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.percent(150.0), 100);
    return true;
}

(:test)
function statusPercentStopsAtZero(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.percent(-3.0), 0);
    return true;
}

(:test)
function statusFillWidthIsZeroForAnEmptyBattery(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.fillWidth(0, 23), 0);
    return true;
}

(:test)
function statusFillWidthRoundsDownAtHalf(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.fillWidth(50, 23), 11);
    return true;
}

(:test)
function statusFillWidthIsFullForAFullBattery(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.fillWidth(100, 23), 23);
    return true;
}

(:test)
function statusFillWidthStopsAtTheInnerWidth(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.fillWidth(120, 23), 23);
    return true;
}

(:test)
function statusFillWidthIsZeroForANegativePercent(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.fillWidth(-5, 23), 0);
    return true;
}

(:test)
function statusLowLevelIsTwentyPercent(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.LOW_PERCENT, 20);
    return true;
}

(:test)
function statusIsLowAtTwentyPercentAndBelow(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.isLow(0), true);
    Test.assertEqual(StatusRow.isLow(19), true);
    Test.assertEqual(StatusRow.isLow(20), true);
    return true;
}

(:test)
function statusIsNotLowAboveTwentyPercent(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.isLow(21), false);
    Test.assertEqual(StatusRow.isLow(100), false);
    return true;
}

(:test)
function statusHasAnAlarmForOneOrMore(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.hasAlarm(1), true);
    Test.assertEqual(StatusRow.hasAlarm(3), true);
    return true;
}

(:test)
function statusHasNoAlarmForZeroNegativeOrNoData(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.hasAlarm(0), false);
    Test.assertEqual(StatusRow.hasAlarm(-1), false);
    Test.assertEqual(StatusRow.hasAlarm(null), false);
    return true;
}

(:test)
function statusDaysTextRoundsToTheNearestDay(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.daysText(12.4, 50), "12d");
    Test.assertEqual(StatusRow.daysText(1.4, 50), "1d");
    Test.assertEqual(StatusRow.daysText(20.0, 50), "20d");
    return true;
}

(:test)
function statusDaysTextRoundsHalfUp(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.daysText(12.5, 50), "13d");
    return true;
}

(:test)
function statusDaysTextShowsOneDayAtOne(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.daysText(1.0, 50), "1d");
    return true;
}

(:test)
function statusDaysTextShowsLessThanOneDayBelowOne(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.daysText(0.99, 50), "<1d");
    Test.assertEqual(StatusRow.daysText(0.0, 50), "<1d");
    Test.assertEqual(StatusRow.daysText(-2.0, 50), "<1d");
    return true;
}

(:test)
function statusDaysTextShowsThePercentWithNoData(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.daysText(null, 50), "50%");
    Test.assertEqual(StatusRow.daysText(null, 100), "100%");
    return true;
}

(:test)
function statusWidthOfNoPartsIsZero(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.width([] as Array<Number>, 10), 0);
    return true;
}

(:test)
function statusWidthOfOnePartHasNoGap(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.width([30] as Array<Number>, 10), 30);
    return true;
}

(:test)
function statusWidthAddsTheGapBetweenParts(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.width([30, 11, 14] as Array<Number>, 10), 75);
    return true;
}
