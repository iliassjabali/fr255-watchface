import Toybox.Lang;
import Toybox.Test;

// Unit tests for the top row: the width of the column of text lines and the
// left edge of the group (the hour and the column).

(:test)
function topRowColumnWidthOfNoLinesIsZero(logger as Logger) as Boolean {
    Test.assertEqual(TopRow.columnWidth([] as Array<Number>), 0);
    return true;
}

(:test)
function topRowColumnWidthOfOneLineIsItsWidth(logger as Logger) as Boolean {
    Test.assertEqual(TopRow.columnWidth([40] as Array<Number>), 40);
    return true;
}

(:test)
function topRowColumnWidthIsTheLargestWidth(logger as Logger) as Boolean {
    Test.assertEqual(TopRow.columnWidth([38, 57, 37] as Array<Number>), 57);
    Test.assertEqual(TopRow.columnWidth([57, 38] as Array<Number>), 57);
    return true;
}

(:test)
function topRowLeftCentersTheGroup(logger as Logger) as Boolean {
    Test.assertEqual(TopRow.left(130, 60, 8, 52), 70);
    return true;
}

(:test)
function topRowLeftRoundsTheHalfWidthDown(logger as Logger) as Boolean {
    Test.assertEqual(TopRow.left(130, 60, 8, 57), 68);
    return true;
}

(:test)
function topRowLeftWithNoContentIsTheCenterMinusHalfTheGap(logger as Logger) as Boolean {
    Test.assertEqual(TopRow.left(130, 0, 8, 0), 126);
    return true;
}
