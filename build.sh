#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building PlanReview..."
swift build -c release

echo "Updating app bundle..."
cp .build/release/PlanReview PlanReview.app/Contents/MacOS/

echo "Installing to /Applications..."
cp -R PlanReview.app /Applications/

echo "Done! You can now launch PlanReview from Spotlight or Applications."
