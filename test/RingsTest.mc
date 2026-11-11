import Toybox.Lang;
import Toybox.Test;

// Unit tests for the open rings on the screen edge.
// A ring starts at the lower left, goes over the top, and stops at the lower
// right. A full ring is 270 degrees.

(:test)
function ringSweepIsZeroWithNoData(logger as Logger) as Boolean {
    Test.assertEqual(Rings.sweep(null, 100), 0);
    Test.assertEqual(Rings.sweep(50, null), 0);
    Test.assertEqual(Rings.sweep(50, 0), 0);
    return true;
}

(:test)
function ringSweepIsHalfAtHalfTheMaximum(logger as Logger) as Boolean {
    Test.assertEqual(Rings.sweep(50, 100), 135);
    return true;
}

(:test)
function ringSweepIsFullAtTheMaximum(logger as Logger) as Boolean {
    Test.assertEqual(Rings.sweep(100, 100), 270);
    return true;
}

(:test)
function ringSweepStopsAtAFullRing(logger as Logger) as Boolean {
    Test.assertEqual(Rings.sweep(150, 100), 270);
    return true;
}

(:test)
function ringSweepIsZeroForANegativeValue(logger as Logger) as Boolean {
    Test.assertEqual(Rings.sweep(-5, 100), 0);
    return true;
}

(:test)
function ringSweepUsesTheMaximumOfTheValue(logger as Logger) as Boolean {
    // A heart rate of 62 with a maximum of 180.
    Test.assertEqual(Rings.sweep(62, 180), 93);
    return true;
}

(:test)
function ringEndAngleIsTheStartForAnEmptyRing(logger as Logger) as Boolean {
    Test.assertEqual(Rings.endAngle(0), 225);
    return true;
}

(:test)
function ringEndAngleIsTheTopAtHalf(logger as Logger) as Boolean {
    Test.assertEqual(Rings.endAngle(135), 90);
    return true;
}

(:test)
function ringEndAngleWrapsBelowZero(logger as Logger) as Boolean {
    Test.assertEqual(Rings.endAngle(225), 0);
    Test.assertEqual(Rings.endAngle(226), 359);
    return true;
}

(:test)
function ringEndAngleIsTheLowerRightForAFullRing(logger as Logger) as Boolean {
    Test.assertEqual(Rings.endAngle(270), 315);
    return true;
}
