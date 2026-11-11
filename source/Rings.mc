import Toybox.Lang;

// Pure logic for the open rings on the screen edge.
// A ring starts at the lower left, goes clockwise over the top, and stops at
// the lower right. The angles are in the system of Dc.drawArc: 0 degrees is
// 3 o'clock, and the angle increases counterclockwise.
module Rings {

    const START_ANGLE = 225;
    const FULL_SWEEP = 270;

    // The degrees of the ring that are filled for a value, from 0 to 270.
    function sweep(value as Number?, max as Number?) as Number {
        if (value == null || max == null || max <= 0 || value <= 0) {
            return 0;
        }
        var degrees = (FULL_SWEEP * value) / max;
        return (degrees > FULL_SWEEP) ? FULL_SWEEP : degrees;
    }

    // The angle where a clockwise arc of the given sweep stops.
    function endAngle(sweepDegrees as Number) as Number {
        return (START_ANGLE - sweepDegrees + 360) % 360;
    }
}
