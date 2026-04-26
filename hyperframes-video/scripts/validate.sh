#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "==> Running hyperframes lint..."
npx hyperframes lint

echo "==> Running hyperframes validate..."
npx hyperframes validate

echo "==> Validation passed!"
