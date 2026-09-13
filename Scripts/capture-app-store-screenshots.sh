#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="com.mfrankland.certwatch"
OUT_IPHONE="$ROOT/AppStoreAssets/iPhone-6.5"
OUT_IPAD="$ROOT/AppStoreAssets/iPad-13"
DERIVED="$ROOT/.build/DerivedData-Screenshots"

# App Store Connect — screenshots (PNG)
IPHONE_SCREENSHOT_W=1242
IPHONE_SCREENSHOT_H=2688
IPAD_SCREENSHOT_W=2064
IPAD_SCREENSHOT_H=2752

# App Store Connect — app previews (video; different from screenshots)
IPHONE_PREVIEW_W=886
IPHONE_PREVIEW_H=1920
IPAD_PREVIEW_W=1200
IPAD_PREVIEW_H=1600
PREVIEW_CLIP_SECONDS=5

mkdir -p "$OUT_IPHONE" "$OUT_IPAD" "$DERIVED"

IPHONE_NAME="${IPHONE_SIMULATOR:-iPhone 17 Pro Max}"
IPAD_NAME="${IPAD_SIMULATOR:-iPad Pro 13-inch (M5)}"

pick_simulator() {
  local name="$1"
  xcrun simctl list devices available | grep "$name" | grep -v unavailable | head -1 | sed -E 's/.*\(([A-F0-9a-f-]{36})\).*/\1/'
}

boot_and_prepare() {
  local udid="$1"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl ui "$udid" appearance dark
  xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 2>/dev/null || true
}

build_for_simulator() {
  local udid="$1"
  xcodebuild \
    -scheme CertWatch \
    -project "$ROOT/CertWatch.xcodeproj" \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$udid" \
    -derivedDataPath "$DERIVED" \
    build >/dev/null
}

resize_png() {
  local file="$1"
  local width="$2"
  local height="$3"
  sips -z "$height" "$width" "$file" >/dev/null
}

pixel_size() {
  sips -g pixelWidth -g pixelHeight "$1" 2>/dev/null | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w "×" h}'
}

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/CertWatch.app"

capture_set() {
  local udid="$1"
  local out_dir="$2"
  local prefix="$3"
  local target_w="$4"
  local target_h="$5"

  xcrun simctl install "$udid" "$APP_PATH"

  local scenes=(dashboard detail settings)
  for scene in "${scenes[@]}"; do
    xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$udid" "$BUNDLE_ID" -AppStoreScreenshot "$scene" >/dev/null
    sleep 2
    local file="$out_dir/${prefix}-${scene}.png"
    xcrun simctl io "$udid" screenshot "$file"
    resize_png "$file" "$target_w" "$target_h"
    echo "Saved $file ($(pixel_size "$file"))"
  done
}

build_preview_from_screenshots() {
  local out_dir="$1"
  local prefix="$2"
  local final_file="$3"
  local width="$4"
  local height="$5"

  local scale_pad="scale=${width}:${height}:force_original_aspect_ratio=decrease,pad=${width}:${height}:(ow-iw)/2:(oh-ih)/2,setsar=1"

  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Skipping $final_file — ffmpeg required to build preview from screenshots" >&2
    return 1
  fi

  ffmpeg -y \
    -loop 1 -t "$PREVIEW_CLIP_SECONDS" -i "$out_dir/${prefix}-dashboard.png" \
    -loop 1 -t "$PREVIEW_CLIP_SECONDS" -i "$out_dir/${prefix}-detail.png" \
    -loop 1 -t "$PREVIEW_CLIP_SECONDS" -i "$out_dir/${prefix}-settings.png" \
    -filter_complex \
    "[0:v]${scale_pad}[v0];[1:v]${scale_pad}[v1];[2:v]${scale_pad}[v2];[v0][v1][v2]concat=n=3:v=1:a=0[v]" \
    -map "[v]" -r 30 -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p -movflags +faststart \
    "$final_file" >/dev/null 2>&1

  local duration
  duration="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$final_file" 2>/dev/null || echo "?")"
  echo "Saved preview $final_file (${width}×${height}, ${duration}s)"
}

echo "Building CertWatch for screenshots…"

IPHONE_UDID="$(pick_simulator "$IPHONE_NAME")"
IPAD_UDID="$(pick_simulator "$IPAD_NAME")"

if [[ -z "$IPHONE_UDID" ]]; then
  echo "Could not find iPhone simulator matching: $IPHONE_NAME" >&2
  exit 1
fi

build_for_simulator "$IPHONE_UDID"
boot_and_prepare "$IPHONE_UDID"
capture_set "$IPHONE_UDID" "$OUT_IPHONE" "iphone" "$IPHONE_SCREENSHOT_W" "$IPHONE_SCREENSHOT_H"
build_preview_from_screenshots "$OUT_IPHONE" "iphone" "$OUT_IPHONE/iphone-preview.mp4" "$IPHONE_PREVIEW_W" "$IPHONE_PREVIEW_H"

if [[ -n "$IPAD_UDID" ]]; then
  boot_and_prepare "$IPAD_UDID"
  capture_set "$IPAD_UDID" "$OUT_IPAD" "ipad" "$IPAD_SCREENSHOT_W" "$IPAD_SCREENSHOT_H"
  build_preview_from_screenshots "$OUT_IPAD" "ipad" "$OUT_IPAD/ipad-preview.mp4" "$IPAD_PREVIEW_W" "$IPAD_PREVIEW_H"
else
  echo "Skipping iPad captures — no simulator matching: $IPAD_NAME"
fi

echo ""
echo "Done. App Store Connect sizes:"
echo "  iPhone 6.5\" screenshots → ${IPHONE_SCREENSHOT_W}×${IPHONE_SCREENSHOT_H}"
echo "  iPhone 6.5\" preview    → ${IPHONE_PREVIEW_W}×${IPHONE_PREVIEW_H} (iphone-preview.mp4, $((PREVIEW_CLIP_SECONDS * 3))s slideshow)"
echo "  iPad 13\" screenshots   → ${IPAD_SCREENSHOT_W}×${IPAD_SCREENSHOT_H}"
echo "  iPad 13\" preview       → ${IPAD_PREVIEW_W}×${IPAD_PREVIEW_H} (ipad-preview.mp4)"
echo ""
echo "Previews must be 15–30 seconds when uploading; trim in QuickTime if needed."
