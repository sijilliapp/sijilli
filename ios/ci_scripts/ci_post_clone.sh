#!/bin/bash

# Fail this script if any subcommand fails.
set -e

# Navigate to the root directory of the project.
cd "$CI_PRIMARY_REPOSITORY_PATH"

# 1. Install Flutter using git (shallow clone of stable branch)
echo "Cloning Flutter SDK..."
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# 1.5. Disable Swift Package Manager for Flutter to fall back to CocoaPods
echo "Disabling Swift Package Manager in Flutter..."
flutter config --no-enable-swift-package-manager

# 2. Precache Flutter artifacts for iOS
echo "Precaching Flutter iOS artifacts..."
flutter precache --ios

# 3. Get pub dependencies
echo "Getting Flutter packages..."
flutter pub get

# 4. Install Pods
echo "Installing CocoaPods dependencies..."
cd ios
pod install
