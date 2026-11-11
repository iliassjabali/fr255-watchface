import Toybox.Lang;
import Toybox.Math;

// The prayer times from the position of the sun, with the standard formulas.
// This is the fallback when the official Habous times are not available.
// It has no access to the clock or the device, thus the unit tests can call it.
//
// Angles for Morocco: Fajr at 19 degrees and Isha at 17 degrees below the
// horizon. Asr is the standard one: the shadow of an object is as long as the
// object, plus its shadow at noon.
//
// The official Habous timetable adds fixed margins to the sun times: 3 minutes
// before sunrise, and 5 minutes after Dhuhr and Maghrib. officialTimes() adds
// the same margins, thus it agrees with the timetable to about 1 minute.
module PrayerCalc {

    // Minutes that the official timetable adds to each of the six times.
    const MARGINS = [0, -3, 5, 0, 5, 0];

    const FAJR_ANGLE = 19.0d;
    const ISHA_ANGLE = 17.0d;
    // The sun is at the horizon when its center is 0.833 degrees below it.
    const HORIZON_ANGLE = 0.833d;

    const PI = 3.141592653589793d;
    const MINUTES_IN_DAY = 1440;

    // The six times of a day, in minutes of the day in UTC:
    // Fajr, sunrise, Dhuhr, Asr, Maghrib, Isha.
    function times(lat as Double, lon as Double, year as Number, month as Number, day as Number) as Array<Number> {
        var jd = julian(year, month, day) - lon / 360.0d;
        var latRad = radians(lat);

        // Each time is a fraction of the day. Two passes are sufficient,
        // because the position of the sun changes slowly.
        var guess = [5.0d / 24, 6.0d / 24, 12.0d / 24, 13.0d / 24, 18.0d / 24, 18.0d / 24] as Array<Double>;
        var hours = guess;
        for (var pass = 0; pass < 2; pass++) {
            hours = [
                angleTime(jd, latRad, FAJR_ANGLE, guess[0], true),
                angleTime(jd, latRad, HORIZON_ANGLE, guess[1], true),
                noon(jd, guess[2]),
                asrTime(jd, latRad, guess[3]),
                angleTime(jd, latRad, HORIZON_ANGLE, guess[4], false),
                angleTime(jd, latRad, ISHA_ANGLE, guess[5], false)
            ] as Array<Double>;
            guess = [hours[0] / 24, hours[1] / 24, hours[2] / 24, hours[3] / 24, hours[4] / 24, hours[5] / 24] as Array<Double>;
        }

        var result = [] as Array<Number>;
        for (var i = 0; i < 6; i++) {
            // The hours are in local mean time. Remove the longitude to get UTC.
            var minutes = Math.floor((hours[i] - lon / 15.0d) * 60 + 0.5d).toNumber();
            result.add(((minutes % MINUTES_IN_DAY) + MINUTES_IN_DAY) % MINUTES_IN_DAY);
        }
        return result;
    }

    // The six times with the margins of the official timetable.
    function officialTimes(lat as Double, lon as Double, year as Number, month as Number, day as Number) as Array<Number> {
        var sunTimes = times(lat, lon, year, month, day);
        var result = [] as Array<Number>;
        for (var i = 0; i < 6; i++) {
            result.add(((sunTimes[i] + MARGINS[i]) % MINUTES_IN_DAY + MINUTES_IN_DAY) % MINUTES_IN_DAY);
        }
        return result;
    }

    // The Julian day number of a date at 0 h.
    function julian(year as Number, month as Number, day as Number) as Double {
        var y = year;
        var m = month;
        if (m <= 2) {
            y -= 1;
            m += 12;
        }
        var a = Math.floor(y / 100.0d);
        var b = 2 - a + Math.floor(a / 4.0d);
        return Math.floor(365.25d * (y + 4716)) + Math.floor(30.6001d * (m + 1)) + day + b - 1524.5d;
    }

    // The declination of the sun in radians, and the equation of time in hours.
    function sun(jd as Double) as Array<Double> {
        var d = jd - 2451545.0d;
        var g = radians(wrap(357.529d + 0.98560028d * d, 360.0d));
        var q = wrap(280.459d + 0.98564736d * d, 360.0d);
        var l = radians(wrap(q + 1.915d * Math.sin(g) + 0.020d * Math.sin(2 * g), 360.0d));
        var e = radians(23.439d - 0.00000036d * d);
        var rightAscension = wrap(degrees(Math.atan2(Math.cos(e) * Math.sin(l), Math.cos(l))) / 15.0d, 24.0d);
        var declination = Math.asin(Math.sin(e) * Math.sin(l));
        return [declination, q / 15.0d - rightAscension] as Array<Double>;
    }

    // The hour of the solar noon.
    function noon(jd as Double, dayFraction as Double) as Double {
        return wrap(12.0d - sun(jd + dayFraction)[1], 24.0d);
    }

    // The hour when the sun is at an angle below the horizon, before or after noon.
    function angleTime(jd as Double, latRad as Double, angle as Double, dayFraction as Double, beforeNoon as Boolean) as Double {
        var declination = sun(jd + dayFraction)[0];
        var cosine = (-Math.sin(radians(angle)) - Math.sin(declination) * Math.sin(latRad))
            / (Math.cos(declination) * Math.cos(latRad));
        // Near the poles the sun does not reach all angles. Stay in the range of acos.
        if (cosine > 1.0d) {
            cosine = 1.0d;
        } else if (cosine < -1.0d) {
            cosine = -1.0d;
        }
        var hourAngle = degrees(Math.acos(cosine)) / 15.0d;
        return noon(jd, dayFraction) + (beforeNoon ? -hourAngle : hourAngle);
    }

    // The hour of Asr: the shadow is the length of the object plus the shadow at noon.
    function asrTime(jd as Double, latRad as Double, dayFraction as Double) as Double {
        var declination = sun(jd + dayFraction)[0];
        var difference = latRad - declination;
        if (difference < 0) {
            difference = -difference;
        }
        var angle = -degrees(Math.atan(1.0d / (1.0d + Math.tan(difference))));
        return angleTime(jd, latRad, angle, dayFraction, false);
    }

    function radians(value as Double) as Double {
        return value * PI / 180.0d;
    }

    function degrees(value as Double) as Double {
        return value * 180.0d / PI;
    }

    // The value in the range from 0 to the modulus.
    function wrap(value as Double, modulus as Double) as Double {
        var result = value - modulus * Math.floor(value / modulus);
        return (result < 0) ? result + modulus : result;
    }
}
