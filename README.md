# FR255 Test Face

A Connect IQ watch face for the Garmin Forerunner 255 (`fr255`).

It shows the time, the date, the weather, the watch battery, the phone
connection, the heart rate, the Body Battery, the steps, and the time of the
next calendar event with a countdown.

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
- `source/StepTicks.mc`: the number of lit ticks for the step goal.

The drawing code in `source/View.mc` has no unit tests. Check it in the
simulator or on the watch.

## Install on a watch

Copy `bin/fr255-watchface.prg` to the `GARMIN/APPS` folder of the watch. The
Forerunner 255 uses MTP, thus macOS needs an MTP tool such as OpenMTP.
