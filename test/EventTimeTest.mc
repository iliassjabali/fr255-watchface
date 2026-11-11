import Toybox.Lang;
import Toybox.Test;

// Unit tests for the calendar event time logic.
// Run: monkeyc ... --unit-test, then monkeydo <prg> fr255 -t

function minutesOfDay(hour as Number, minute as Number) as Number {
    return hour * 60 + minute;
}

(:test)
function minutesUntilReads24HourTime(logger as Logger) as Boolean {
    Test.assertEqual(EventTime.minutesUntil("12:00", minutesOfDay(11, 15), true), 45);
    return true;
}

(:test)
function minutesUntilIsZeroAtTheEventTime(logger as Logger) as Boolean {
    Test.assertEqual(EventTime.minutesUntil("12:00", minutesOfDay(12, 0), true), 0);
    return true;
}

(:test)
function minutesUntilWrapsToTheNextDay(logger as Logger) as Boolean {
    Test.assertEqual(EventTime.minutesUntil("09:00", minutesOfDay(23, 30), true), 570);
    return true;
}

(:test)
function minutesUntilReadsShortPmMark(logger as Logger) as Boolean {
    Test.assertEqual(EventTime.minutesUntil("3:00p", minutesOfDay(14, 15), false), 45);
    return true;
}

(:test)
function minutesUntilReadsLongPmMark(logger as Logger) as Boolean {
    Test.assertEqual(EventTime.minutesUntil("3:00 PM", minutesOfDay(14, 15), false), 45);
    return true;
}

(:test)
function minutesUntilReadsNoonAsPm(logger as Logger) as Boolean {
    Test.assertEqual(EventTime.minutesUntil("12:30p", minutesOfDay(12, 0), false), 30);
    return true;
}

(:test)
function minutesUntilReadsMidnightAsAm(logger as Logger) as Boolean {
    Test.assertEqual(EventTime.minutesUntil("12:15a", minutesOfDay(23, 45), false), 30);
    return true;
}

(:test)
function minutesUntilPicksTheAfternoonForAnUnmarked12HourTime(logger as Logger) as Boolean {
    Test.assertEqual(EventTime.minutesUntil("3:00", minutesOfDay(14, 15), false), 45);
    return true;
}

(:test)
function minutesUntilPicksTheMorningForAnUnmarked12HourTime(logger as Logger) as Boolean {
    Test.assertEqual(EventTime.minutesUntil("3:00", minutesOfDay(2, 0), false), 60);
    return true;
}

(:test)
function minutesUntilIsNullForTextThatIsNotATime(logger as Logger) as Boolean {
    Test.assert(EventTime.minutesUntil("CAL", 0, true) == null);
    Test.assert(EventTime.minutesUntil("", 0, true) == null);
    Test.assert(EventTime.minutesUntil(":30", 0, true) == null);
    Test.assert(EventTime.minutesUntil("ab:cd", 0, true) == null);
    return true;
}

(:test)
function countdownTextSaysNowAtZero(logger as Logger) as Boolean {
    Test.assertEqual(EventTime.countdownText(0), "now");
    return true;
}

(:test)
function countdownTextShowsMinutesBelowOneHour(logger as Logger) as Boolean {
    Test.assertEqual(EventTime.countdownText(45), "in 45 min");
    return true;
}

(:test)
function countdownTextShowsHoursAndPaddedMinutes(logger as Logger) as Boolean {
    Test.assertEqual(EventTime.countdownText(60), "in 1 h 00");
    Test.assertEqual(EventTime.countdownText(125), "in 2 h 05");
    return true;
}
