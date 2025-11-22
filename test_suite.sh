#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
TEST_DIR="tests/autopilot_$(date +%s)"
SCRIPT_SOURCE="./appAssistant.sh"
TEST_FILE_NAME="secret_test_file.txt"

log() { echo -e "${GREEN}[TEST] $1${NC}"; }
fail() { echo -e "${RED}[FAIL] $1${NC}"; exit 1; }

# 1. SETUP TEST ENVIRONMENT
log "Setting up test environment in $TEST_DIR..."
mkdir -p "$TEST_DIR"
cp "$SCRIPT_SOURCE" "$TEST_DIR/"
cd "$TEST_DIR"

# Create a lightweight Dummy App Config
cat <<EOF > options.json
{
    "app_display_name": "Test Dummy",
    "image_repo_tag": "test-dummy:latest",
    "permissions": {
        "DataPersistance": { "value": "Y" },
        "SharedData": { "value": "Y" },
        "UserMapping": { "value": "Y" },
        "NetworkAccess": { "value": "N" },
        "InputDevices": { "value": "N" },
        "SoundAccess": { "value": "N" },
        "MicrophoneAccess": { "value": "N" },
        "WebcamAccess": { "value": "N" }
    },
    "port_mappings": [],
    "podman_extra_args": "",
    "xpra_extra_args": ""
}
EOF

# Create a tiny Dockerfile (Alpine + Xpra + Touch)
cat <<EOF > Dockerfile
FROM alpine:latest
RUN apk add --no-cache xpra xauth xvfb
RUN adduser -D -u 1000 appuser
USER appuser
WORKDIR /home/appuser
# Keep container alive by running xpra
ENTRYPOINT ["/usr/bin/xpra", "start", "--start-child=/bin/sleep infinity", "--bind-tcp=0.0.0.0:14500", "--exit-with-children", "--daemon=no", "--opengl=no", "--mdns=no", "--notifications=no"]
EOF

# 2. TEST BUILD
log "Testing BUILD..."
./appAssistant.sh build > build.log 2>&1
if [ ! -f "app.tar" ]; then fail "Build failed: app.tar not created."; fi

# 3. TEST RUN & PERSISTENCE
log "Testing RUN & DATA CREATION..."
./appAssistant.sh > run.log 2>&1 &
APP_PID=$!
sleep 5 # Wait for podman to spin up

# Check if session folder exists
if [ ! -d "_session/home" ]; then fail "Session folder not created."; fi

# Simulate user creating data (Persistence Test)
echo "My Secret Data" > "_session/home/$TEST_FILE_NAME"
log "Created mock data: _session/home/$TEST_FILE_NAME"

# Kill the app (simulating closing the window)
kill $APP_PID 2>/dev/null || true
# Wait for container cleanup logic to fire
sleep 3

# 4. TEST EXPORT (SNAPSHOT)
log "Testing EXPORT (Snapshotting)..."
# We pipe "n" to say NO to encryption to keep the test automated
echo "n" | ./appAssistant.sh export > export.log 2>&1

# Verify session is wiped
if [ -d "_session" ]; then fail "Export did not clean up _session folder."; fi

# 5. TEST IMPORT (RESTORE)
log "Testing IMPORT (Restoration)..."
./appAssistant.sh import app.tar > import.log 2>&1

# 6. VERIFY DATA INTEGRITY
log "Verifying Persistence..."
if [ -f "_session/home/$TEST_FILE_NAME" ]; then
    CONTENT=$(cat "_session/home/$TEST_FILE_NAME")
    if [ "$CONTENT" == "My Secret Data" ]; then
        log "SUCCESS: Data restored correctly!"
    else
        fail "Data corruption: Content does not match."
    fi
else
    fail "Data loss: Test file was not restored."
fi

# CLEANUP
cd ../..
log "Cleaning up..."
rm -rf "$TEST_DIR"

echo -e "${GREEN}✅ ALL TESTS PASSED.${NC}"
