# FR255 Test Face

A Connect IQ watch face for the Garmin Forerunner 255 (`fr255`).

The minutes fill the center of the screen. Three open rings show the heart
rate, the Body Battery and the stress. The watch face also shows the hour, the
date, the next prayer, the weather, the watch battery, the phone connection,
and the time of the next calendar event with a countdown.

## Requirements

- Connect IQ SDK 9.3.0, with the Forerunner 255 device, from the SDK Manager.
- Java 11 or higher.
- A developer key outside the repository, for example
  `~/.garmin/connectiq/developer_key.der`.

Put the SDK tools on the `PATH`:

```bash
export PATH=$PATH:`cat $HOME/Library/Application\ Support/Garmin/ConnectIQ/current-sdk.cfg`/bin
```

## Build and run

```bash
monkeyc -d fr255 -f monkey.jungle -o bin/fr255-watchface.prg -y ~/.garmin/connectiq/developer_key.der -w
connectiq
monkeydo bin/fr255-watchface.prg fr255
```

## Tests

The unit tests are in `test/`. They use the Connect IQ test framework and run
in the simulator.

```bash
monkeyc -d fr255 -f monkey.jungle -o bin/test.prg -y ~/.garmin/connectiq/developer_key.der --unit-test
connectiq
monkeydo bin/test.prg fr255 -t
```

The tests cover the logic that has no access to the device:

- `source/EventTime.mc`: the minutes to the next calendar event and the
  countdown text.
- `source/Rings.mc`: the filled part of each ring, in degrees.
- `source/PrayerCalc.mc`: the prayer times from the position of the sun.
- `source/PrayerSchedule.mc`: the next prayer and its text.
- `source/PrayerStore.mc`: the official times that the web service sent.

The drawing code in `source/View.mc` has no unit tests. Check it in the
simulator or on the watch.

## Prayer times

The watch face shows the next prayer below the date.

- **Official times:** A background service asks a Cloudflare Worker (`worker/`)
  for the times of the Ministry of Habous, for the nearest city. The request
  goes through the phone. The address is in `source/Config.mc`.
- **Fallback:** With no answer from the service, `source/PrayerCalc.mc`
  calculates the times from the position of the sun (Fajr 19 degrees, Isha 17
  degrees). A calculated time has a mark, for example `~13:15`. The official
  timetable adds margins that the calculation does not have: about 3 minutes
  before sunrise, and 5 minutes after Dhuhr and Maghrib.
- **Position:** the weather position, the last activity position, the last
  kept position, then Casablanca.

See `worker/README.md` for the Worker.

## Fonts

The watch has no number font that is large enough for the minutes. The digit
fonts in `resources/fonts` are Roboto Black (Apache License 2.0). To make them
again, run:

```bash
python3 tools/make_fonts.py
```

The script needs Google Chrome and an internet connection.

## Design

`design/layouts.html` shows the layouts that were considered. Open it in a
browser.

## Install on a watch

Copy `bin/fr255-watchface.prg` to the `GARMIN/APPS` folder of the watch. The
Forerunner 255 uses MTP, thus macOS needs an MTP tool such as OpenMTP.

With OpenMTP installed, this script does the copy:

```bash
python3 tools/push_to_watch.py
```

Close OpenMTP and Garmin Express first.
