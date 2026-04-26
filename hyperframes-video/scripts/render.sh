#!/bin/bash
set -e

cd "$(dirname "$0")/.."

OUTPUT_DIR="../../.build/renders"
mkdir -p "$OUTPUT_DIR"

npx hyperframes render . \
  --output "$OUTPUT_DIR/hoop-product-capabilities.mp4" \
  --quality high \
  --fps 60 \
  --video-bitrate 20M \
  --gpu

echo "==> Render complete: $OUTPUT_DIR/hoop-product-capabilities.mp4"
