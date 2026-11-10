import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class FaceView extends WatchUi.WatchFace {

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        var timeText = Lang.format("$1$:$2$", [hour.format("%02d"), clock.min.format("%02d")]);

        var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateText = Lang.format("$1$ $2$ $3$ $4$", [today.day_of_week, today.day, today.month, today.year]);

        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;
        var justify = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        dc.drawText(centerX, centerY - 20, Graphics.FONT_NUMBER_HOT, timeText, justify);
        dc.drawText(centerX, centerY + 55, Graphics.FONT_SMALL, dateText, justify);
    }
}
