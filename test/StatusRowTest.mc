import Toybox.Lang;
import Toybox.Test;

// Unit tests for the status row: the temperature in the unit of the watch and
// the width of a row of parts.

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

(:test)
function statusTemperatureStaysCelsiusForMetricUnits(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.temperature(18, false), 18);
    return true;
}

(:test)
function statusTemperatureFreezingPointIs32Fahrenheit(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.temperature(0, true), 32);
    return true;
}

(:test)
function statusTemperatureConvertsToFahrenheit(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.temperature(18, true), 64);
    return true;
}

(:test)
function statusTemperatureConvertsANegativeValue(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.temperature(-10, true), 14);
    Test.assertEqual(StatusRow.temperature(-10, false), -10);
    return true;
}

(:test)
function statusTemperatureConvertsAFloat(logger as Logger) as Boolean {
    Test.assertEqual(StatusRow.temperature(10.0, true), 50.0);
    return true;
}

(:test)
function statusTemperatureIsNullWithNoData(logger as Logger) as Boolean {
    Test.assert(StatusRow.temperature(null, true) == null);
    Test.assert(StatusRow.temperature(null, false) == null);
    return true;
}
