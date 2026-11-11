import Toybox.Lang;

// Pure layout arithmetic for the top of the face: the hour at the left and a
// column of text lines at its right, centered as one group. It has no access
// to the device.
module TopRow {

    // The width of the column: the largest width of its lines. No lines gives 0.
    function columnWidth(widths as Array<Number>) as Number {
        var widest = 0;
        for (var i = 0; i < widths.size(); i++) {
            if (widths[i] > widest) {
                widest = widths[i];
            }
        }
        return widest;
    }

    // The left edge of the group, so that the hour, the gap and the column
    // are centered on cx.
    function left(cx as Number, hourWidth as Number, gap as Number, columnWidth as Number) as Number {
        return cx - (hourWidth + gap + columnWidth) / 2;
    }
}
