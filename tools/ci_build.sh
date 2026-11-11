#!/usr/bin/env bash
# Build the watch face and make the zip file to share.
#
# The script needs:
#   CIQ_SDK   the folder of the Connect IQ SDK (it contains bin/monkeyc)
#   CIQ_KEY   the developer key (.der) that signs the build
#
# The compiler reads the device file from the Garmin folder of the user. On
# Linux this is ~/.Garmin/ConnectIQ/Devices. The build needs only the file
# compiler.json of the device, which is in ci/devices.
#
# Result: dist/fr255-watchface.prg and dist/fr255-watchface.zip
set -euo pipefail

: "${CIQ_SDK:?Set CIQ_SDK to the folder of the Connect IQ SDK}"
: "${CIQ_KEY:?Set CIQ_KEY to the developer key file}"

root="$(cd "$(dirname "$0")/.." && pwd)"
device="fr255"
out="$root/dist"

case "$(uname -s)" in
  Darwin) devices="$HOME/Library/Application Support/Garmin/ConnectIQ/Devices" ;;
  *) devices="$HOME/.Garmin/ConnectIQ/Devices" ;;
esac
if [ ! -f "$devices/$device/compiler.json" ]; then
  mkdir -p "$devices/$device"
  cp "$root/ci/devices/$device/compiler.json" "$devices/$device/"
fi

rm -rf "$out"
mkdir -p "$out"
cd "$root"

echo "Build the watch face"
"$CIQ_SDK/bin/monkeyc" -d "$device" -f monkey.jungle -o "$out/fr255-watchface.prg" -y "$CIQ_KEY" -w

# The unit tests need the simulator, which the CI does not have. This build
# only proves that the test code compiles.
echo "Compile the unit tests"
"$CIQ_SDK/bin/monkeyc" -d "$device" -f monkey.jungle -o "$out/test.prg" -y "$CIQ_KEY" --unit-test
rm -f "$out"/test.prg "$out"/*.debug.xml
rm -rf "$out/gen" "$out/internal-mir" "$out/external-mir"

echo "Make the zip file"
cp docs/INSTALL.txt "$out/INSTALL.txt"
(cd "$out" && zip -q fr255-watchface.zip fr255-watchface.prg INSTALL.txt)
rm -f "$out/INSTALL.txt"
ls -l "$out"
