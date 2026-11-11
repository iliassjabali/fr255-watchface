import Toybox.Lang;

// Pure logic for the status row: the temperature in the unit of the watch
// and the width of a row of parts. It has no access to the device.
module StatusRow {

    // The temperature in the unit of the watch: Celsius, or Fahrenheit when
    // the unit is statute. A whole number stays a whole number. No data gives
    // null.
    function temperature(celsius as Numeric?, fahrenheit as Boolean) as Numeric? {
        if (celsius == null || !fahrenheit) {
            return celsius;
        }
        return (celsius * 9) / 5 + 32;
    }

    // The total width of a row of parts, with the gap between two parts.
    function width(parts as Array<Number>, gap as Number) as Number {
        var total = 0;
        for (var i = 0; i < parts.size(); i++) {
            total += parts[i];
            if (i > 0) {
                total += gap;
            }
        }
        return total;
    }
}
