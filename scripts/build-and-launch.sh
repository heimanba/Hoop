#!/usr/bin/env bash
set -euo pipefail

SCHEME="${SCHEME:-Hoop}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
PROJECT="${PROJECT:-Hoop.xcodeproj}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build/DerivedData}"
SCREENSHOT_PATH="${SCREENSHOT_PATH:-.build/screenshots/hoop.png}"
BUNDLE_ID="${BUNDLE_ID:-}"

if [[ "${SCREENSHOT_PATH}" != /* ]]; then
  SCREENSHOT_PATH="${PWD}/${SCREENSHOT_PATH}"
fi

DESTINATION="platform=iOS Simulator,name=${SIMULATOR_NAME}"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}-iphonesimulator/${SCHEME}.app"

echo "Building ${SCHEME} for ${SIMULATOR_NAME}"
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "${DESTINATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  build

if [[ -z "${BUNDLE_ID}" ]]; then
  BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${APP_PATH}/Info.plist")"
fi

DEVICE_ID="$(xcrun simctl list devices available "${SIMULATOR_NAME}" -j \
  | /usr/bin/python3 -c 'import json,sys
data=json.load(sys.stdin)
for devices in data.get("devices", {}).values():
    for device in devices:
        if device.get("isAvailable") and device.get("name") == sys.argv[1]:
            print(device["udid"])
            raise SystemExit
raise SystemExit(f"No available simulator named {sys.argv[1]!r}")' "${SIMULATOR_NAME}")"

echo "Booting ${SIMULATOR_NAME} (${DEVICE_ID})"
xcrun simctl boot "${DEVICE_ID}" 2>/dev/null || true
xcrun simctl bootstatus "${DEVICE_ID}" -b

echo "Installing ${APP_PATH}"
xcrun simctl install "${DEVICE_ID}" "${APP_PATH}"

echo "Launching ${BUNDLE_ID}"
xcrun simctl terminate "${DEVICE_ID}" "${BUNDLE_ID}" 2>/dev/null || true
xcrun simctl launch "${DEVICE_ID}" "${BUNDLE_ID}" &
LAUNCH_PID="$!"
for _ in {1..20}; do
  if ! kill -0 "${LAUNCH_PID}" 2>/dev/null; then
    wait "${LAUNCH_PID}"
    break
  fi
  sleep 1
done
if kill -0 "${LAUNCH_PID}" 2>/dev/null; then
  echo "Launch command is still attached after 20s; continuing to screenshot."
  kill "${LAUNCH_PID}" 2>/dev/null || true
fi
sleep 2

mkdir -p "$(dirname "${SCREENSHOT_PATH}")"
xcrun simctl io "${DEVICE_ID}" screenshot "${SCREENSHOT_PATH}"
echo "Screenshot written to ${SCREENSHOT_PATH}"
