# CLAUDE.md

A Connect IQ watch face for the Garmin Forerunner 255 (`fr255`, Monkey C), and
a Cloudflare Worker (`worker/`, TypeScript) that gives it the official Habous
prayer times.

`README.md` is the single source for the build, run and test commands.
`worker/README.md` is the single source for the Worker API.

## Onboarding

Do the steps in order. Each step is done when its check passes.

1. **SDK.** A human installs the Connect IQ SDK Manager, logs in with a Garmin
   account, downloads SDK 9.3.0 and the device "Forerunner 255", and sets the
   SDK as active. Java 11 or higher must be installed.
   Check: `cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"`
   prints an SDK path, and the folder `Devices/fr255` exists next to `Sdks`.
2. **Developer key**, outside the repository:
   `openssl genrsa -out ~/.garmin/connectiq/developer_key.pem 4096`, then
   `openssl pkcs8 -topk8 -inform PEM -outform DER -in ~/.garmin/connectiq/developer_key.pem -out ~/.garmin/connectiq/developer_key.der -nocrypt`.
   Check: `~/.garmin/connectiq/developer_key.der` exists.
3. **Watch face.** Run the build and the tests from `README.md`.
   Check: the test run ends with `PASSED (passed=N, failed=0, errors=0)`.
4. **Worker.** `cd worker && npm install`, then one test file:
   `npx vitest run test/handler.test.ts`. Check: the file passes, and
   `npx tsc --noEmit` exits with 0.
5. **Cloudflare**, only for a deploy. Check: `npx wrangler whoami` shows an
   account. If not, a human runs `npx wrangler login`.
6. **Watch**, only for an install. A human connects the watch with a USB data
   cable and closes OpenMTP and Garmin Express. Then
   `python3 tools/push_to_watch.py`. Check: it prints `Copied ...`.

## The simulator

- **You cannot see the simulator window.** A build that loads proves nothing
  about the display. For the display, ask the human for a screenshot.
- **Prove that the app runs** with a temporary `System.println`: its text shows
  in the output of `monkeydo`. Remove it before the commit.
- **Restart the simulator before each load.** It stops silently after a
  running `monkeydo` is killed: the window is empty and `monkeydo` prints
  nothing. `pkill -f "ConnectIQ.app/Contents/MacOS"`, then `connectiq`, wait
  10 seconds, then `monkeydo`.
- `monkeydo` does not return. Run it in the background with its output in a
  file, and read the file.

## Code rules

- **Test first.** Logic lives in modules with no device access: `EventTime`,
  `Rings`, `PrayerCalc`, `PrayerSchedule`, `PrayerStore`. `View` and
  `PrayerProvider` only connect them to the device and stay thin.
- **Background code.** All code that `PrayerService` uses carries the
  `(:background)` annotation (`Config`, `PrayerStore`, `FaceApp`).
- **Astronomy uses Double** (`1.0d`). `Math.PI` is a 32-bit Float, thus
  `PrayerCalc` has its own constant.
- **API level 5.2.** `Math.abs`, `Math.min` and `Math.max` are absent.
- **Worker tests run by file**, one file for each command.
- **The watch and the Worker share one JSON contract.** Change both sides in
  the same commit.

## Platform limits that shape the design

- The screen is round, 260 x 260, with 64 colors: each channel is `00`, `55`,
  `AA` or `FF`.
- `FONT_XTINY` is the smallest text. The system number fonts are too small for
  the minutes, thus `tools/make_fonts.py` makes the digit fonts.
- The rings leave a circle of radius 106 for the content. Draw a new layout in
  `design/layouts.html` first, then in `View.mc`.
- A watch face cannot call the web. It uses a background service: 5 minutes
  minimum between runs, 64 KB of memory, about 8 KB for the result.
- Garmin gives only the time of the next calendar event to a watch face. The
  event name is not available.

## Prayer times

- Near a listed city (25 km or less), the Worker gives the official row of the
  Habous month file `https://www.habous.gov.ma/data/horaires-YYYY-MM.js`.
- In all other cases, `PrayerCalc.officialTimes` calculates at the exact
  position and adds the margins of the timetable. The view shows a calculated
  time with the mark `~`.
- `worker/data/cities.json` holds only cities with a confirmed position.
  `worker/data/UNMATCHED.md` lists the others. Add a city only with a
  confirmed position.

## CI

- `README.md`, section "CI", explains the workflow. The CI builds the zip file
  and runs the Worker tests. It cannot run the Monkey C tests, thus run them
  in the simulator before each push.
- After a change to the workflow or to `tools/ci_build.sh`, run `actionlint`,
  `yamllint` and `shellcheck`, then confirm the run with `gh run watch`.

## Deploy and git

- Deploy the Worker with `npx wrangler deploy` in `worker/`, when the user asks.
  The public address is in `source/Config.mc`.
- This is a personal repository. Push with the GitHub account `iliassjabali`:
  `gh auth switch --user iliassjabali`, push, then switch back to the account
  that was active.
- Commit messages have no AI attribution.
