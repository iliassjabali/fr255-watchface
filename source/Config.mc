import Toybox.Lang;

// Settings of the watch face.
(:background)
module Config {

    // The web service that gives the official Habous prayer times.
    // Set this to the address of your Cloudflare Worker after the deploy.
    const WORKER_URL = "https://fr255-prayers.iliassjabali.workers.dev";

    // Casablanca. Used when the watch has no position.
    const DEFAULT_LAT = 33.5731d;
    const DEFAULT_LON = -7.5898d;

    // The answer of the web service when no city of the timetable is near.
    const NO_CITY_NEAR = 404;

    // Seconds between two runs of the background service.
    // The service makes no request when it already has the data of today.
    const FETCH_INTERVAL = 3600;
    // Seconds before a new try when the data of today is absent.
    const RETRY_INTERVAL = 900;
}
