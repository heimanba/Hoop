#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_SCRIPT="${SCRIPT_DIR}/build-and-launch.sh"

SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
VIDEO_CODEC="${VIDEO_CODEC:-h264}"
VIDEO_PATH="${VIDEO_PATH:-.build/recordings/hoop-$(date +%Y%m%d-%H%M%S).mov}"
RECORD_ONLY="${RECORD_ONLY:-0}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Builds and launches Hoop in Simulator by default, then starts Simulator video capture.
Press Ctrl+C to stop recording and finalize the .mov file.

Options:
  --record-only         Skip build and launch; record from the current booted simulator.
  --simulator NAME      Override the simulator name (default: ${SIMULATOR_NAME}).
  --output PATH         Write the recording to PATH.
  --codec CODEC         Video codec: h264 or hevc (default: ${VIDEO_CODEC}).
  -h, --help            Show this help text.

Environment overrides:
  SIMULATOR_NAME, VIDEO_PATH, VIDEO_CODEC, RECORD_ONLY

Examples:
  $(basename "$0")
  $(basename "$0") --record-only
  SIMULATOR_NAME="iPhone 17 Pro" $(basename "$0")
  VIDEO_PATH=".build/recordings/demo.mov" $(basename "$0") --record-only
EOF
}

resolve_named_device_id() {
  xcrun simctl list devices available "${SIMULATOR_NAME}" -j \
    | /usr/bin/python3 -c 'import json,sys
data=json.load(sys.stdin)
target=sys.argv[1]
for devices in data.get("devices", {}).values():
    for device in devices:
        if device.get("isAvailable") and device.get("name") == target:
            print(device["udid"])
            raise SystemExit
raise SystemExit(f"No available simulator named {target!r}")' "${SIMULATOR_NAME}"
}

resolve_booted_device_id() {
  xcrun simctl list devices booted -j \
    | /usr/bin/python3 -c 'import json,sys
data=json.load(sys.stdin)
for devices in data.get("devices", {}).values():
    for device in devices:
        if device.get("state") == "Booted":
            print(device["udid"])
            raise SystemExit
raise SystemExit(1)'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --record-only)
      RECORD_ONLY=1
      shift
      ;;
    --simulator)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --simulator" >&2
        exit 1
      fi
      SIMULATOR_NAME="$2"
      shift 2
      ;;
    --output)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --output" >&2
        exit 1
      fi
      VIDEO_PATH="$2"
      shift 2
      ;;
    --codec)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --codec" >&2
        exit 1
      fi
      VIDEO_CODEC="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "${VIDEO_CODEC}" != "h264" && "${VIDEO_CODEC}" != "hevc" ]]; then
  echo "Unsupported codec: ${VIDEO_CODEC}. Use h264 or hevc." >&2
  exit 1
fi

if [[ "${VIDEO_PATH}" != /* ]]; then
  VIDEO_PATH="${REPO_ROOT}/${VIDEO_PATH}"
fi

mkdir -p "$(dirname "${VIDEO_PATH}")"

cd "${REPO_ROOT}"

if [[ "${RECORD_ONLY}" != "1" ]]; then
  echo "Building and launching Hoop on ${SIMULATOR_NAME}"
  SIMULATOR_NAME="${SIMULATOR_NAME}" "${BUILD_SCRIPT}"
  DEVICE_ID="$(resolve_named_device_id)"
else
  if DEVICE_ID="$(resolve_booted_device_id 2>/dev/null)"; then
    echo "Using booted simulator ${DEVICE_ID}"
  else
    DEVICE_ID="$(resolve_named_device_id)"
    echo "Booting ${SIMULATOR_NAME} (${DEVICE_ID})"
    xcrun simctl boot "${DEVICE_ID}" 2>/dev/null || true
    xcrun simctl bootstatus "${DEVICE_ID}" -b
  fi
fi

echo "Recording simulator video to ${VIDEO_PATH}"
echo "Press Ctrl+C to stop recording."
xcrun simctl io "${DEVICE_ID}" recordVideo --codec="${VIDEO_CODEC}" --force "${VIDEO_PATH}"
