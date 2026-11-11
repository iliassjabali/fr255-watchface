import Toybox.Activity;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;

// Gives the next prayer and the next sunrise or sunset to the view. It uses the official times from the web
// service when the watch is near a city of the timetable. In all other cases
// it calculates the times at the exact position, with the official margins.
// The logic is in PrayerStore, PrayerCalc and PrayerSchedule, which have unit
// tests. This class only connects them to the device.
class PrayerProvider {

    private const SECONDS_IN_DAY = 86400;

    // The result is kept for one minute, because the view can draw each second.
    private var _minute as Number = -1;
    private var _current as Array<String>?;
    private var _sunMinute as Number = -1;
    private var _sun as Array<Number or String>?;

    // The calculated times are kept for one day. They are in UTC.
    private var _calcDay as String = "";
    private var _calcToday as Array<Number>?;
    private var _calcTomorrow as Array<Number>?;

    function initialize() {
    }

    // Forget the kept result, for example after new data from the service.
    function invalidate() as Void {
        _minute = -1;
        _sunMinute = -1;
    }

    // The next prayer as [name, time text], or null if it is not known.
    function current(clock as System.ClockTime) as Array<String>? {
        var nowMinutes = clock.hour * 60 + clock.min;
        if (nowMinutes != _minute) {
            _minute = nowMinutes;
            _current = find(nowMinutes, clock.timeZoneOffset);
        }
        return _current;
    }

    // The next sunrise or sunset as [PrayerSchedule.SUNRISE or SUNSET, time
    // text], or null if it is not known. The times are the sunrise and the
    // Maghrib of the same timetable as the prayers.
    function sun(clock as System.ClockTime) as Array<Number or String>? {
        var nowMinutes = clock.hour * 60 + clock.min;
        if (nowMinutes != _sunMinute) {
            _sunMinute = nowMinutes;
            _sun = findSun(nowMinutes, clock.timeZoneOffset);
        }
        return _sun;
    }

    private function findSun(nowMinutes as Number, offset as Number) as Array<Number or String>? {
        var now = Time.now();
        var today = dayText(now);
        var stored = Storage.getValue(PrayerStore.KEY);
        var todayTimes = PrayerStore.today(stored, today, dayText(now.subtract(new Time.Duration(SECONDS_IN_DAY)) as Time.Moment));
        var tomorrowTimes = PrayerStore.tomorrow(stored, today);

        // The calculated times fill each day that the service did not send.
        if (todayTimes == null || tomorrowTimes == null) {
            calculate(now, today, position());
            if (todayTimes == null) {
                todayTimes = _calcToday;
            }
            if (tomorrowTimes == null) {
                tomorrowTimes = _calcTomorrow;
            }
        }
        if (todayTimes == null) {
            return null;
        }
        var next = PrayerSchedule.nextSun(local(todayTimes, offset),
            (tomorrowTimes != null) ? local(tomorrowTimes, offset) : null, nowMinutes);
        // The text has no mark for a calculated time: the line has no space for it.
        return (next != null) ? [next[0], PrayerSchedule.timeText(next[1], true)] : null;
    }

    private function find(nowMinutes as Number, offset as Number) as Array<String>? {
        var now = Time.now();
        var today = dayText(now);
        var position = position();

        var stored = Storage.getValue(PrayerStore.KEY);
        var official = PrayerStore.today(stored, today, dayText(now.subtract(new Time.Duration(SECONDS_IN_DAY)) as Time.Moment));
        if (official != null) {
            var next = PrayerSchedule.next(local(official, offset), localOrNull(PrayerStore.fajrTomorrow(stored, today), offset), nowMinutes);
            if (next != null) {
                return text(next, true);
            }
        }

        calculate(now, today, position);
        var calcToday = _calcToday;
        if (calcToday == null) {
            return null;
        }
        var calcTomorrow = _calcTomorrow;
        var fajrTomorrow = localOrNull((calcTomorrow != null) ? calcTomorrow[0] : null, offset);
        if (official != null) {
            // The official prayers of today are done, and the service did not
            // send the Fajr of tomorrow.
            return (fajrTomorrow != null) ? text([PrayerSchedule.FAJR, fajrTomorrow], false) : null;
        }
        var nextCalc = PrayerSchedule.next(local(calcToday, offset), fajrTomorrow, nowMinutes);
        return (nextCalc != null) ? text(nextCalc, false) : null;
    }

    // Calculate the times of today and of tomorrow, one time for each day.
    private function calculate(now as Time.Moment, today as String, position as Array<Double>) as Void {
        if (today.equals(_calcDay)) {
            return;
        }
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        _calcToday = PrayerCalc.officialTimes(position[0], position[1], info.year, info.month as Number, info.day);
        var next = Gregorian.info(now.add(new Time.Duration(SECONDS_IN_DAY)), Time.FORMAT_SHORT);
        _calcTomorrow = PrayerCalc.officialTimes(position[0], position[1], next.year, next.month as Number, next.day);
        _calcDay = today;
    }

    // The position as [latitude, longitude] in degrees, with no GPS start.
    // Order: the weather position, the position of the last activity, the
    // last position that the watch face kept, then the default city.
    private function position() as Array<Double> {
        var location = null;
        var conditions = Weather.getCurrentConditions();
        if (conditions != null) {
            location = conditions.observationLocationPosition;
        }
        if (location == null) {
            var info = Activity.getActivityInfo();
            if (info != null) {
                location = info.currentLocation;
            }
        }

        var stored = Storage.getValue(PrayerStore.POSITION_KEY);
        var kept = (stored instanceof Array && stored.size() == 2) ? stored as Array<Double> : null;

        if (location != null) {
            var degrees = location.toDegrees();
            // Keep the position for the background service. Write only after a
            // real move, because each write uses the flash memory.
            if (kept == null || distant(kept[0], degrees[0]) || distant(kept[1], degrees[1])) {
                Storage.setValue(PrayerStore.POSITION_KEY, [degrees[0], degrees[1]]);
            }
            return [degrees[0], degrees[1]];
        }
        return (kept != null) ? kept : [Config.DEFAULT_LAT, Config.DEFAULT_LON];
    }

    private function distant(a as Double, b as Double) as Boolean {
        var difference = a - b;
        return difference > 0.01d || difference < -0.01d;
    }

    private function dayText(moment as Time.Moment) as String {
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        return PrayerStore.dateText(info.year, info.month as Number, info.day);
    }

    private function local(times as Array<Number>, offset as Number) as Array<Number> {
        var result = [] as Array<Number>;
        for (var i = 0; i < times.size(); i++) {
            result.add(PrayerSchedule.toLocal(times[i], offset));
        }
        return result;
    }

    private function localOrNull(minutes as Number?, offset as Number) as Number? {
        return (minutes != null) ? PrayerSchedule.toLocal(minutes, offset) : null;
    }

    private function text(next as Array<Number>, official as Boolean) as Array<String> {
        return [PrayerSchedule.glyph(next[0]), PrayerSchedule.timeText(next[1], official)];
    }
}
