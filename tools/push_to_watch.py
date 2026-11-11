#!/usr/bin/env python3
"""Copy the watch face to a Garmin watch over USB (MTP).

macOS cannot open the storage of the Forerunner 255. This script uses the MTP
library that the OpenMTP app contains, thus OpenMTP must be installed
(`brew install --cask openmtp`). Close OpenMTP and Garmin Express first:
only one program can use the watch at a time.

Usage: python3 tools/push_to_watch.py [path/to/file.prg]
The default file is bin/fr255-watchface.prg.
"""
import ctypes
import json
import pathlib
import sys
import threading

ROOT = pathlib.Path(__file__).resolve().parent.parent
LIBRARY = "/Applications/OpenMTP.app/Contents/Resources/bin/arm64/kalam.dylib"
TARGET = "/GARMIN/APPS"

CALLBACK = ctypes.CFUNCTYPE(None, ctypes.c_char_p)
_keep = []  # The callbacks must stay alive while the library can call them.


def call(lib, name, payload=None, callbacks=1, timeout=300):
    """Call one function of the library and return its JSON result."""
    done = threading.Event()
    out = {}

    def on_done(text):
        out["result"] = json.loads(text.decode("utf-8", "replace"))
        done.set()

    def on_progress(_text):
        pass

    functions = [CALLBACK(on_progress) for _ in range(callbacks - 1)] + [CALLBACK(on_done)]
    _keep.extend(functions)
    function = getattr(lib, name)
    function.restype = None
    arguments = [ctypes.c_char_p(json.dumps(payload).encode())] if payload is not None else []
    function(*arguments, *functions)
    if not done.wait(timeout):
        sys.exit(f"{name}: no answer from the watch")
    result = out["result"]
    if result.get("error"):
        sys.exit(f"{name}: {result['error']}")
    return result


def names(result):
    return sorted(entry.get("name") for entry in (result.get("data") or []))


def main():
    source = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "bin" / "fr255-watchface.prg"
    if not source.is_file():
        sys.exit(f"File not found: {source}")
    if not pathlib.Path(LIBRARY).is_file():
        sys.exit("OpenMTP is not installed: brew install --cask openmtp")

    lib = ctypes.CDLL(LIBRARY)
    device = call(lib, "Initialize")["data"]["mtpDeviceInfo"]
    print("Watch:", device.get("Manufacturer"), device.get("Model"))
    try:
        storage = int(call(lib, "FetchStorages")["data"][0]["Sid"])

        def walk():
            return call(lib, "Walk", {"storageId": storage, "fullPath": TARGET, "recursive": False,
                                      "skipDisallowedFiles": False, "skipHiddenFiles": False})

        walk()  # Stops with an error if the folder does not exist.
        call(lib, "UploadFiles", {"storageId": storage, "sources": [str(source)], "destination": TARGET,
                                  "preprocessFiles": True}, callbacks=3)
        if source.name in names(walk()):
            print(f"Copied {source.name} ({source.stat().st_size} bytes) to {TARGET}")
        else:
            sys.exit("The file is not in the folder after the copy.")
    finally:
        call(lib, "Dispose")


if __name__ == "__main__":
    main()
