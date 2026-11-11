import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// The background service. A watch face cannot call the web directly, thus
// this service asks the web service for the official prayer times and gives
// the answer to the watch face.
(:background)
class PrayerService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var today = PrayerStore.dateText(info.year, info.month as Number, info.day);
        if (PrayerStore.isFresh(Storage.getValue(PrayerStore.KEY), today)) {
            Background.exit(null);
            return;
        }

        var lat = Config.DEFAULT_LAT;
        var lon = Config.DEFAULT_LON;
        var position = Storage.getValue(PrayerStore.POSITION_KEY);
        if (position instanceof Array && position.size() == 2) {
            lat = position[0] as Double;
            lon = position[1] as Double;
        }

        // Two decimals are about 1 km. The service needs only the nearest city.
        Communications.makeWebRequest(
            Config.WORKER_URL + "/prayers",
            { "lat" => lat.format("%.2f"), "lon" => lon.format("%.2f"), "date" => today },
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onResponse)
        );
    }

    // Gives the JSON to the watch face, or the error code when the request failed.
    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        if (code == 200 && data instanceof Dictionary) {
            Background.exit(data);
        } else {
            Background.exit(code);
        }
    }
}
