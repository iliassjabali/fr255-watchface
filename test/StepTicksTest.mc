import Toybox.Lang;
import Toybox.Test;

// Unit tests for the step goal ticks on the screen edge.

(:test)
function litTicksIsZeroWithNoSteps(logger as Logger) as Boolean {
    Test.assertEqual(StepTicks.lit(0, 10000), 0);
    return true;
}

(:test)
function litTicksIsHalfAtHalfTheGoal(logger as Logger) as Boolean {
    Test.assertEqual(StepTicks.lit(5000, 10000), 30);
    return true;
}

(:test)
function litTicksRoundsDown(logger as Logger) as Boolean {
    Test.assertEqual(StepTicks.lit(166, 10000), 0);
    Test.assertEqual(StepTicks.lit(167, 10000), 1);
    return true;
}

(:test)
function litTicksStopsAtAFullRing(logger as Logger) as Boolean {
    Test.assertEqual(StepTicks.lit(10000, 10000), 60);
    Test.assertEqual(StepTicks.lit(25000, 10000), 60);
    return true;
}

(:test)
function litTicksIsZeroWithNoData(logger as Logger) as Boolean {
    Test.assertEqual(StepTicks.lit(null, 10000), 0);
    Test.assertEqual(StepTicks.lit(5000, null), 0);
    Test.assertEqual(StepTicks.lit(5000, 0), 0);
    return true;
}
