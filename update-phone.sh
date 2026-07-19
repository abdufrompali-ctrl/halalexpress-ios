#!/usr/bin/env bash
# One-command update: grab the freshest CI build and install it on the iPhone.
# Usage: ./update-phone.sh   (phone plugged in via USB, answer the Apple ID login)
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Finding latest successful build on GitHub..."
RUN_ID=$(gh run list --workflow "Build iOS app" --status success --limit 1 --json databaseId --jq '.[0].databaseId')
[ -n "$RUN_ID" ] || { echo "No successful build found — did the last push fail CI?"; exit 1; }

echo "==> Downloading IPA from run $RUN_ID..."
rm -f dist/HalalExpress-unsigned.ipa
gh run download "$RUN_ID" --name HalalExpress-unsigned-ipa --dir dist

echo "==> Checking iPhone connection..."
idevice_id -l >/dev/null || { echo "iPhone not detected — plug it in and unlock it."; exit 1; }

echo "==> Signing & installing (answer the Apple ID prompts)..."
cd dist && ./sideloader install -i --singlethread HalalExpress-unsigned.ipa

echo "==> Done — check your phone."
