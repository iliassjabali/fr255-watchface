import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

class FaceView extends WatchUi.WatchFace {

    // Palette, from the 64 colors of the Forerunner 255 display.
    // Amber is the one accent: the minutes, the step ticks and the step icon.
    private const COLOR_ACCENT = 0xFFAA00;
    private const COLOR_DIM = 0xAAAAAA;
    private const COLOR_TRACK = 0x555555;
    private const COLOR_HEART = 0xFF0055;
    private const COLOR_ENERGY = 0x00AAFF;
    private const COLOR_STEPS = 0xFFAA00;

    private var _nextEvent as String?;
    private var _bodyBattery as Number?;

    function initialize() {
        WatchFace.initialize();
    }

    function onShow() as Void {
        Complications.registerComplicationChangeCallback(method(:onComplicationChanged));
        subscribe(Complications.COMPLICATION_TYPE_CALENDAR_EVENTS);
        subscribe(Complications.COMPLICATION_TYPE_BODY_BATTERY);
    }

    function onHide() as Void {
        Complications.unsubscribeFromAllUpdates();
    }

    private function subscribe(type as Complications.Type) as Void {
        try {
            var id = new Complications.Id(type);
            Complications.subscribeToUpdates(id);
            readComplication(id);
        } catch (e) {
            // The device does not supply this complication.
        }
    }

    function onComplicationChanged(id as Complications.Id) as Void {
        readComplication(id);
        WatchUi.requestUpdate();
    }

    private function readComplication(id as Complications.Id) as Void {
        try {
            var value = Complications.getComplication(id).value;
            var type = id.getType();
            if (type == Complications.COMPLICATION_TYPE_CALENDAR_EVENTS) {
                _nextEvent = (value != null) ? value.toString() : null;
            } else if (type == Complications.COMPLICATION_TYPE_BODY_BATTERY) {
                _bodyBattery = (value instanceof Number) ? value : null;
            }
        } catch (e) {
            // Keep the last known value.
        }
    }

    private function heartRate() as Number? {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) {
            return info.currentHeartRate;
        }
        var sample = ActivityMonitor.getHeartRateHistory(1, true).next();
        if (sample != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
            return sample.heartRate;
        }
        return null;
    }

    // Layout: an asymmetric instrument dial.
    // - Edge: 60 ticks that light up with the progress to the step goal.
    // - Left: the time, stacked, as the one bold element.
    // - Right: a quiet column with heart rate, energy and steps.
    // - Top and bottom: status, date, weather and the next calendar event.
    function onUpdate(dc as Dc) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var vcenter = Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var activity = ActivityMonitor.getInfo();
        drawStepTicks(dc, cx, cy, activity);
        drawStatusRow(dc, cx, cy - 106);

        var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateText = Lang.format("$1$ $2$ $3$", [today.day_of_week, today.day, today.month]).toUpper();
        drawDateAndWeather(dc, cx, cy - 82, dateText);

        // Time, stacked and aligned to the right on the divider.
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        var timeRight = cx - 5;
        var timeJustify = Graphics.TEXT_JUSTIFY_RIGHT | vcenter;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(timeRight, cy - 33, Graphics.FONT_NUMBER_THAI_HOT, hour.format("%02d"), timeJustify);
        dc.setColor(COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(timeRight, cy + 33, Graphics.FONT_NUMBER_THAI_HOT, clock.min.format("%02d"), timeJustify);

        // Divider
        dc.setColor(COLOR_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx + 5, cy - 56, cx + 5, cy + 57);

        // Heart rate, energy (Body Battery), steps
        var iconX = cx + 24;
        var valueX = cx + 42;
        var valueJustify = Graphics.TEXT_JUSTIFY_LEFT | vcenter;
        var hr = heartRate();
        var steps = activity.steps;

        drawHeart(dc, iconX, cy - 38);
        drawBolt(dc, iconX, cy);
        drawSteps(dc, iconX, cy + 38);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(valueX, cy - 38, Graphics.FONT_TINY, (hr != null) ? hr.toString() : "--", valueJustify);
        dc.drawText(valueX, cy, Graphics.FONT_TINY, (_bodyBattery != null) ? _bodyBattery.toString() : "--", valueJustify);
        dc.drawText(valueX, cy + 38, Graphics.FONT_TINY, (steps != null) ? steps.toString() : "--", valueJustify);

        drawNextEvent(dc, cx, cy + 79);
    }

    // 60 ticks on the screen edge. The lit ticks show the progress to the step goal.
    private function drawStepTicks(dc as Dc, cx as Number, cy as Number, activity as ActivityMonitor.Info) as Void {
        var steps = activity.steps;
        var goal = activity.stepGoal;
        var lit = 0;
        if (steps != null && goal != null && goal > 0) {
            lit = (60 * steps) / goal;
            if (lit > 60) {
                lit = 60;
            }
        }

        var outer = cx - 1;
        dc.setPenWidth(2);
        for (var i = 0; i < 60; i++) {
            var angle = (i * Math.PI) / 30;
            var sin = Math.sin(angle);
            var cos = Math.cos(angle);
            var inner = (i % 5 == 0) ? outer - 9 : outer - 5;
            dc.setColor((i < lit) ? COLOR_ACCENT : COLOR_TRACK, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx + inner * sin, cy - inner * cos, cx + outer * sin, cy - outer * cos);
        }
        dc.setPenWidth(1);
    }

    // Watch battery and phone connection, centered as one group.
    private function drawStatusRow(dc as Dc, cx as Number, y as Number) as Void {
        var font = Graphics.FONT_XTINY;
        var battery = System.getSystemStats().battery;
        var batteryText = battery.format("%d") + "%";
        var textWidth = dc.getTextWidthInPixels(batteryText, font);
        var x = cx - (27 + 5 + textWidth + 12 + 11) / 2;

        // Battery
        dc.setPenWidth(1);
        dc.setColor(COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y - 6, 24, 13);
        dc.fillRectangle(x + 24, y - 2, 3, 5);
        dc.setColor((battery > 20) ? Graphics.COLOR_WHITE : COLOR_HEART, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + 2, y - 4, ((20 * battery) / 100).toNumber(), 9);
        dc.setColor(COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 32, y, font, batteryText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Phone
        var connected = System.getDeviceSettings().phoneConnected;
        var px = x + 32 + textWidth + 12 + 5;
        dc.setPenWidth(2);
        dc.setColor(connected ? COLOR_ENERGY : COLOR_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(px - 5, y - 9, 11, 18, 2);
        dc.fillRectangle(px - 1, y + 4, 3, 2);
        if (!connected) {
            dc.setColor(COLOR_HEART, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(px - 8, y + 9, px + 8, y - 9);
        }
        dc.setPenWidth(1);
    }

    // The date, then a weather icon and the temperature on the same line.
    private function drawDateAndWeather(dc as Dc, cx as Number, y as Number, dateText as String) as Void {
        var font = Graphics.FONT_XTINY;
        var left = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        var conditions = Weather.getCurrentConditions();
        var temperature = (conditions != null) ? conditions.temperature : null;

        if (conditions == null || temperature == null) {
            dc.setColor(COLOR_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, font, dateText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
            temperature = (temperature * 9) / 5 + 32;
        }
        var tempText = temperature.format("%d") + "°";
        var dateWidth = dc.getTextWidthInPixels(dateText, font);
        var gap = 12;
        var iconWidth = 18;
        var x = cx - (dateWidth + gap + iconWidth + 5 + dc.getTextWidthInPixels(tempText, font)) / 2;

        dc.setColor(COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, dateText, left);
        x += dateWidth + gap;
        drawWeatherIcon(dc, x + iconWidth / 2, y, conditions.condition);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + iconWidth + 5, y, font, tempText, left);
    }

    // Sun for clear weather, cloud with drops for rain and snow, cloud for all other conditions.
    private function drawWeatherIcon(dc as Dc, x as Number, y as Number, condition as Number?) as Void {
        var clear = condition == Weather.CONDITION_CLEAR || condition == Weather.CONDITION_FAIR
            || condition == Weather.CONDITION_MOSTLY_CLEAR || condition == Weather.CONDITION_PARTLY_CLEAR;
        var wet = condition == Weather.CONDITION_RAIN || condition == Weather.CONDITION_LIGHT_RAIN
            || condition == Weather.CONDITION_HEAVY_RAIN || condition == Weather.CONDITION_SHOWERS
            || condition == Weather.CONDITION_SCATTERED_SHOWERS || condition == Weather.CONDITION_DRIZZLE
            || condition == Weather.CONDITION_THUNDERSTORMS || condition == Weather.CONDITION_SNOW
            || condition == Weather.CONDITION_LIGHT_SNOW || condition == Weather.CONDITION_HEAVY_SNOW;

        if (clear) {
            dc.setColor(COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, 4);
            dc.drawLine(x - 8, y, x + 9, y);
            dc.drawLine(x, y - 8, x, y + 9);
            dc.drawLine(x - 6, y - 6, x + 7, y + 7);
            dc.drawLine(x - 6, y + 6, x + 7, y - 7);
            return;
        }

        var cloudY = wet ? y - 3 : y;
        dc.setColor(COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - 4, cloudY + 1, 4);
        dc.fillCircle(x + 1, cloudY - 2, 5);
        dc.fillCircle(x + 6, cloudY + 2, 3);
        dc.fillRectangle(x - 4, cloudY + 1, 10, 5);
        if (wet) {
            dc.setColor(COLOR_ENERGY, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(x - 3, y + 5, x - 5, y + 9);
            dc.drawLine(x + 2, y + 5, x, y + 9);
            dc.drawLine(x + 7, y + 5, x + 5, y + 9);
            dc.setPenWidth(1);
        }
    }

    private function drawHeart(dc as Dc, x as Number, y as Number) as Void {
        dc.setColor(COLOR_HEART, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - 4, y - 3, 5);
        dc.fillCircle(x + 4, y - 3, 5);
        dc.fillPolygon([[x - 9, y - 1], [x + 9, y - 1], [x, y + 9]]);
    }

    private function drawBolt(dc as Dc, x as Number, y as Number) as Void {
        dc.setColor(COLOR_ENERGY, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x + 3, y - 10], [x - 7, y + 1], [x - 1, y + 1], [x - 3, y + 10], [x + 7, y - 2], [x + 1, y - 2]]);
    }

    private function drawSteps(dc as Dc, x as Number, y as Number) as Void {
        dc.setColor(COLOR_STEPS, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(x - 5, y + 2, 3, 6);
        dc.fillEllipse(x + 5, y - 2, 3, 6);
    }

    // The next calendar event on two lines: icon and start time, then the countdown.
    private function drawNextEvent(dc as Dc, cx as Number, y as Number) as Void {
        var font = Graphics.FONT_XTINY;
        var left = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var event = _nextEvent;
        var text = (event != null) ? event : "No event";
        var iconWidth = 16;
        var gap = 7;
        var x = cx - (iconWidth + gap + dc.getTextWidthInPixels(text, font)) / 2;

        dc.setColor(COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y - 6, iconWidth, 14);
        dc.fillRectangle(x, y - 6, iconWidth, 4);
        dc.fillRectangle(x + 3, y - 9, 2, 4);
        dc.fillRectangle(x + 11, y - 9, 2, 4);
        dc.fillRectangle(x + 4, y + 1, 3, 3);
        dc.fillRectangle(x + 9, y + 1, 3, 3);

        dc.setColor((event != null) ? Graphics.COLOR_WHITE : COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + iconWidth + gap, y, font, text, left);

        var minutes = (event != null) ? minutesUntil(event) : null;
        if (minutes != null) {
            // Amber marks an event that starts in 15 minutes or less.
            dc.setColor((minutes <= 15) ? COLOR_ACCENT : COLOR_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y + 20, font, countdownText(minutes), center);
        }
    }

    private function countdownText(minutes as Number) as String {
        if (minutes == 0) {
            return "now";
        }
        if (minutes < 60) {
            return "in " + minutes + " min";
        }
        return "in " + (minutes / 60) + " h " + (minutes % 60).format("%02d");
    }

    // The minutes from now to an event time such as "12:00", "3:00p" or "3:00 PM".
    // Returns null if the text is not a time.
    private function minutesUntil(time as String) as Number? {
        var colon = time.find(":");
        if (colon == null || colon == 0) {
            return null;
        }
        var hour = time.substring(0, colon).toNumber();
        var minute = time.substring(colon + 1, colon + 3).toNumber();
        if (hour == null || minute == null) {
            return null;
        }

        var lower = time.toLower();
        var isPm = lower.find("p") != null;
        var isAm = lower.find("a") != null;
        var clock = System.getClockTime();
        var now = clock.hour * 60 + clock.min;

        if (isPm || isAm) {
            if (isPm && hour < 12) {
                hour += 12;
            } else if (isAm && hour == 12) {
                hour = 0;
            }
            return (hour * 60 + minute - now + 1440) % 1440;
        }

        var wait = (hour * 60 + minute - now + 1440) % 1440;
        // A 12-hour time with no AM or PM mark: use the nearest future occurrence.
        if (!System.getDeviceSettings().is24Hour && hour <= 12) {
            var other = ((hour % 12 + 12) * 60 + minute - now + 1440) % 1440;
            var first = ((hour % 12) * 60 + minute - now + 1440) % 1440;
            wait = (first < other) ? first : other;
        }
        return wait;
    }
}
