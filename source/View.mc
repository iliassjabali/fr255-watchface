import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;
import Toybox.WatchUi;
import Toybox.Weather;

// Layout: the minutes fill the center, and three open rings go around them.
// - Rings, from the edge to the center: heart rate, Body Battery, stress.
// - Top: the hour, small, with the date and the next prayer.
// - Opening at the bottom: the next calendar event, then the battery, the
//   phone and the weather.
class FaceView extends WatchUi.WatchFace {

    // Palette, from the 64 colors of the Forerunner 255 display.
    private const COLOR_ACCENT = 0x00AAFF;
    private const COLOR_DIM = 0xAAAAAA;
    private const COLOR_TRACK = 0x555555;
    private const COLOR_HEART = 0xFF0055;
    private const COLOR_STRESS = 0xFFAA00;
    private const COLOR_SUN = 0xFFFF55;

    private const RING_WIDTH = 6;
    private const DEFAULT_MAX_HEART_RATE = 190;

    private var _minuteFont as FontResource?;
    private var _hourFont as FontResource?;
    private var _nextEvent as String?;
    private var _bodyBattery as Number?;
    private var _stress as Number?;
    private var _prayers as PrayerProvider;

    function initialize() {
        WatchFace.initialize();
        _prayers = new PrayerProvider();
    }

    // The background service gave new prayer times.
    function onPrayerData() as Void {
        _prayers.invalidate();
    }

    function onLayout(dc as Dc) as Void {
        _minuteFont = WatchUi.loadResource(Rez.Fonts.Minutes) as FontResource;
        _hourFont = WatchUi.loadResource(Rez.Fonts.Hour) as FontResource;
    }

    function onShow() as Void {
        Complications.registerComplicationChangeCallback(method(:onComplicationChanged));
        subscribe(Complications.COMPLICATION_TYPE_CALENDAR_EVENTS);
        subscribe(Complications.COMPLICATION_TYPE_BODY_BATTERY);
        subscribe(Complications.COMPLICATION_TYPE_STRESS);
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
            } else if (type == Complications.COMPLICATION_TYPE_STRESS) {
                _stress = (value instanceof Number) ? value : null;
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

    // The maximum heart rate from the user profile. It is the top of zone 5.
    private function maxHeartRate() as Number {
        var zones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        if (zones != null && zones.size() > 5) {
            return zones[5];
        }
        return DEFAULT_MAX_HEART_RATE;
    }

    function onUpdate(dc as Dc) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        drawRing(dc, cx, cy, cx - 5, Rings.sweep(heartRate(), maxHeartRate()), COLOR_HEART);
        drawRing(dc, cx, cy, cx - 13, Rings.sweep(_bodyBattery, 100), COLOR_ACCENT);
        drawRing(dc, cx, cy, cx - 21, Rings.sweep(_stress, 100), COLOR_STRESS);

        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        drawTop(dc, cx, cy - 63, hour.format("%02d"), _prayers.current(clock));

        var minuteFont = _minuteFont;
        if (minuteFont != null) {
            dc.setColor(COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + 4, minuteFont, clock.min.format("%02d"),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        drawNextEvent(dc, cx, cy + 66, clock.hour * 60 + clock.min);
        drawStatusRow(dc, cx, cy + 92);
    }

    // An open ring: a grey track, and the filled part in the color of the value.
    private function drawRing(dc as Dc, cx as Number, cy as Number, radius as Number, sweep as Number, color as Number) as Void {
        dc.setPenWidth(RING_WIDTH);
        dc.setColor(COLOR_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, Rings.START_ANGLE, Rings.endAngle(Rings.FULL_SWEEP));
        if (sweep > 0) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, Rings.START_ANGLE, Rings.endAngle(sweep));
        }
        dc.setPenWidth(1);
    }

    // The hour, with the date and the next prayer at its right.
    // The hour and the date are centered as one group. The prayer starts
    // below the date and can be longer than the date.
    private function drawTop(dc as Dc, cx as Number, y as Number, hourText as String, prayer as Array<String>?) as Void {
        var font = Graphics.FONT_XTINY;
        var left = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateText = Lang.format("$1$ $2$ $3$", [today.day_of_week, today.day, today.month]).toUpper();

        var hourFont = _hourFont;
        var hourWidth = (hourFont != null) ? dc.getTextWidthInPixels(hourText, hourFont) : 0;
        var gap = 8;
        var x = cx - (hourWidth + gap + dc.getTextWidthInPixels(dateText, font)) / 2;

        if (hourFont != null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + hourWidth, y, hourFont, hourText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        x += hourWidth + gap;

        dc.setColor(COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y - 7, font, dateText, left);

        if (prayer != null) {
            dc.drawText(x, y + 11, font, prayer[0], left);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + dc.getTextWidthInPixels(prayer[0], font) + 5, y + 11, font, prayer[1], left);
        }
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
            dc.setColor(COLOR_SUN, Graphics.COLOR_TRANSPARENT);
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
            dc.setColor(COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(x - 3, y + 5, x - 5, y + 9);
            dc.drawLine(x + 2, y + 5, x, y + 9);
            dc.drawLine(x + 7, y + 5, x + 5, y + 9);
            dc.setPenWidth(1);
        }
    }

    // The next calendar event on one line: icon, start time, countdown.
    private function drawNextEvent(dc as Dc, cx as Number, y as Number, nowMinutes as Number) as Void {
        var font = Graphics.FONT_XTINY;
        var left = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        var event = _nextEvent;
        var text = (event != null) ? event : "No event";
        var minutes = (event != null)
            ? EventTime.minutesUntil(event, nowMinutes, System.getDeviceSettings().is24Hour)
            : null;
        var countdown = (minutes != null) ? "  " + EventTime.countdownText(minutes) : "";

        var iconWidth = 16;
        var gap = 7;
        var textWidth = dc.getTextWidthInPixels(text, font);
        var x = cx - (iconWidth + gap + textWidth + dc.getTextWidthInPixels(countdown, font)) / 2;

        dc.setColor(COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y - 6, iconWidth, 14);
        dc.fillRectangle(x, y - 6, iconWidth, 4);
        dc.fillRectangle(x + 3, y - 9, 2, 4);
        dc.fillRectangle(x + 11, y - 9, 2, 4);
        dc.fillRectangle(x + 4, y + 1, 3, 3);
        dc.fillRectangle(x + 9, y + 1, 3, 3);

        x += iconWidth + gap;
        dc.setColor((event != null) ? Graphics.COLOR_WHITE : COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, left);

        if (minutes != null) {
            // The accent marks an event that starts in 15 minutes or less.
            dc.setColor((minutes <= 15) ? COLOR_ACCENT : COLOR_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + textWidth, y, font, countdown, left);
        }
    }

    // The watch battery, the phone connection and the weather, centered as one
    // group in the opening of the rings.
    private function drawStatusRow(dc as Dc, cx as Number, y as Number) as Void {
        var font = Graphics.FONT_XTINY;
        var gap = 10;
        var batteryWidth = 27;
        var phoneWidth = 11;
        var iconWidth = 18;

        var conditions = Weather.getCurrentConditions();
        var temperature = (conditions != null) ? conditions.temperature : null;
        var tempText = null;
        if (conditions != null && temperature != null) {
            if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
                temperature = (temperature * 9) / 5 + 32;
            }
            tempText = temperature.format("%d") + "°";
        }

        var total = batteryWidth + gap + phoneWidth;
        if (tempText != null) {
            total += gap + iconWidth + 5 + dc.getTextWidthInPixels(tempText, font);
        }
        var x = cx - total / 2;

        // Battery
        var battery = System.getSystemStats().battery;
        dc.setPenWidth(1);
        dc.setColor(COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y - 6, 24, 13);
        dc.fillRectangle(x + 24, y - 2, 3, 5);
        dc.setColor((battery > 20) ? Graphics.COLOR_WHITE : COLOR_HEART, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + 2, y - 4, ((20 * battery) / 100).toNumber(), 9);
        x += batteryWidth + gap;

        // Phone
        var connected = System.getDeviceSettings().phoneConnected;
        var px = x + 5;
        dc.setPenWidth(2);
        dc.setColor(connected ? COLOR_ACCENT : COLOR_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(px - 5, y - 9, 11, 18, 2);
        dc.fillRectangle(px - 1, y + 4, 3, 2);
        if (!connected) {
            dc.setColor(COLOR_HEART, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(px - 8, y + 9, px + 8, y - 9);
        }
        dc.setPenWidth(1);
        x += phoneWidth + gap;

        // Weather
        if (conditions != null && tempText != null) {
            drawWeatherIcon(dc, x + 9, y, conditions.condition);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + iconWidth + 5, y, font, tempText,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
