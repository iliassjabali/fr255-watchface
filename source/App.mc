import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

(:background)
class FaceApp extends Application.AppBase {

    private var _view as FaceView?;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        scheduleFetch();
        var view = new FaceView();
        _view = view;
        return [ view ];
    }

    // The background service that asks the web service for the prayer times.
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [ new PrayerService() ];
    }

    // The answer of the background service: the JSON of the web service, or
    // an error code when the request failed.
    function onBackgroundData(data as Application.PersistableType) as Void {
        if (data instanceof Dictionary) {
            Storage.setValue(PrayerStore.KEY, data);
        } else if (data instanceof Number && data == Config.NO_CITY_NEAR) {
            // The watch is far from all cities of the timetable. Remove the
            // times of the last city, thus the view calculates the times at
            // the exact position.
            Storage.deleteValue(PrayerStore.KEY);
        }
        scheduleFetch();
        var view = _view;
        if (view != null) {
            view.onPrayerData();
        }
        WatchUi.requestUpdate();
    }

    // Run the background service again. The wait is short when the data of
    // today is absent, and long when the watch already has it.
    private function scheduleFetch() as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var today = PrayerStore.dateText(info.year, info.month as Number, info.day);
        var fresh = PrayerStore.isFresh(Storage.getValue(PrayerStore.KEY), today);
        Background.registerForTemporalEvent(new Time.Duration(fresh ? Config.FETCH_INTERVAL : Config.RETRY_INTERVAL));
    }
}
