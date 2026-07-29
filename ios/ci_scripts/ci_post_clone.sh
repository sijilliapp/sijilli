#!/bin/bash

# Fail this script if any subcommand fails.
set -e

# Navigate to the root directory of the project.
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Increase network reliability for Flutter package downloader
export PUB_MAX_RETRIES=10

# 1. Install Flutter using git (shallow clone of stable branch)
if [ -d "$HOME/flutter" ]; then
    echo "Flutter SDK already exists. Skipping clone."
else
    MAX_ATTEMPTS=5
    attempt=1
    while [ $attempt -le $MAX_ATTEMPTS ]; do
        echo "Cloning Flutter SDK (Attempt $attempt of $MAX_ATTEMPTS)..."
        # Remove any partial clone before retrying
        rm -rf "$HOME/flutter"
        if git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"; then
            echo "Flutter SDK cloned successfully."
            break
        else
            echo "Clone failed. Retrying in 5 seconds..."
            sleep 5
            attempt=$((attempt+1))
        fi
    done
    if [ $attempt -gt $MAX_ATTEMPTS ]; then
        echo "Failed to clone Flutter SDK after $MAX_ATTEMPTS attempts."
        exit 35
    fi
fi

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

# Retry pod install in case of transient CDN connection failures
MAX_POD_ATTEMPTS=3
pod_attempt=1
while [ $pod_attempt -le $MAX_POD_ATTEMPTS ]; do
    echo "Running pod install (Attempt $pod_attempt of $MAX_POD_ATTEMPTS)..."
    if pod install; then
        echo "CocoaPods dependencies installed successfully."
        break
    else
        echo "pod install failed. Retrying in 5 seconds..."
        sleep 5
        pod_attempt=$((pod_attempt+1))
    fi
done
if [ $pod_attempt -gt $MAX_POD_ATTEMPTS ]; then
    echo "Failed to install CocoaPods dependencies after $MAX_POD_ATTEMPTS attempts."
    exit 35
fi
