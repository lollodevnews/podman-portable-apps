#!/bin/bash
set -e

# --- GLOBAL CONFIGURATION ---
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPTIONS_FILE="$BASE_DIR/options.json"
DOCKERFILE="$BASE_DIR/Dockerfile"
TAR_FILE="$BASE_DIR/app.tar"

# FOLDERS
SHARED_DIR="$BASE_DIR/shared"
SESSION_DIR="$BASE_DIR/_session"

# INTERNAL PATHS (All mapped to _session)
PODMAN_ROOT="$SESSION_DIR/storage"
RUNTIME_DIR="$SESSION_DIR/runtime"
INTERNAL_HOME="$SESSION_DIR/home" 
PODMAN_RUNROOT="/run/user/$(id -u)/portable_$(basename "$BASE_DIR")"

# --- HELPER: CHECK DEPENDENCIES ---
check_deps() {
    if ! command -v jq &> /dev/null; then echo "[X] Error: 'jq' is missing. Install it."; exit 1; fi
    if ! command -v xpra &> /dev/null; then echo "[X] Error: 'xpra' is missing. Install it."; exit 1; fi
    if ! command -v podman &> /dev/null; then echo "[X] Error: 'podman' is missing. Install it."; exit 1; fi
}

# --- HELPER: DETECT HOME FOLDER ---
detect_home() {
    IMG="$1"
    DETECTED=$(podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" run --rm \
        --entrypoint /bin/sh "$IMG" -c 'echo $HOME' 2>/dev/null)
    
    if [ -z "$DETECTED" ]; then
        echo "/home/appuser" # Fallback
    else
        echo "$DETECTED"
    fi
}

# --- HELPER: INITIALIZE DEFAULTS ---
init_defaults() {
    mkdir -p "$SHARED_DIR"

    if [ ! -f "$OPTIONS_FILE" ]; then
        echo "[-] options.json missing. Creating default..."
        cat <<EOF > "$OPTIONS_FILE"
{
    "app_display_name": "Portable App",
    "image_repo_tag": "portable-app:latest",
    "permissions": {
        "DataPersistance": { "value": "Y" },
        "SharedData": { "value": "Y" },
        "UserMapping": { "value": "Y" },
        "NetworkAccess": { "value": "Y" },
        "InputDevices": { "value": "N" },
        "SoundAccess": { "value": "Y" },
        "MicrophoneAccess": { "value": "N" },
        "WebcamAccess": { "value": "N" }
    },
    "port_mappings": [],
    "podman_extra_args": "",
    "xpra_extra_args": ""
}
EOF
    fi

    if [ ! -f "$DOCKERFILE" ]; then
        echo "[-] Dockerfile missing. Creating generic default..."
        cat <<EOF > "$DOCKERFILE"
FROM alpine:latest
RUN apk add --no-cache firefox ttf-dejavu font-noto adwaita-icon-theme dbus-x11 mesa-dri-gallium mesa-gl libx11 libxext libxrender xvfb pulseaudio pulseaudio-utils alsa-plugins-pulse alsa-utils xpra gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly v4l-utils xauth
RUN echo -e 'pcm.!default type pulse\nctl.!default type pulse' > /etc/asound.conf
RUN adduser -D -u 1000 appuser
RUN mkdir -p /home/appuser/.config/pulse && chown -R appuser:appuser /home/appuser/.config
USER appuser
WORKDIR /home/appuser
ENTRYPOINT ["/usr/bin/xpra", "start", "--start-child=/usr/bin/firefox", "--bind-tcp=0.0.0.0:14500", "--exit-with-children", "--daemon=no", "--opengl=no", "--mdns=no", "--notifications=no"] 
EOF
    fi
}

# ==============================================================================
# MODE 1: BUILD (Factory Reset)
# ==============================================================================
do_build() {
    check_deps
    
    if [ -d "$SESSION_DIR" ]; then
        echo "[-] Cleaning session directory (Factory Reset)..."
        rm -rf "$SESSION_DIR" 2>/dev/null || sudo rm -rf "$SESSION_DIR"
    fi

    init_defaults
    mkdir -p "$PODMAN_ROOT"

    APP_IMAGE=$(jq -r '.image_repo_tag' "$OPTIONS_FILE")
    echo "[-] Building Clean Docker Image: $APP_IMAGE..."
    
    podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" build --no-cache -t "$APP_IMAGE" .
    
    echo "[-] Saving to app.tar..."
    rm -f "$TAR_FILE"
    podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" save -o "$TAR_FILE" "$APP_IMAGE"
    
    echo "[-] Build Complete."
}

# ==============================================================================
# MODE 2: EXPORT (Snapshot Session)
# ==============================================================================
do_export() {
    check_deps
    if [ ! -f "$OPTIONS_FILE" ]; then echo "[X] options.json missing."; exit 1; fi
    
    mkdir -p "$PODMAN_ROOT"

    APP_IMAGE=$(jq -r '.image_repo_tag' "$OPTIONS_FILE")
    echo "[-] Preparing Snapshot Export for $APP_IMAGE..."

    # 1. STOP RUNNING CONTAINERS
    RUNNING_ID=$(podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" ps -q --filter ancestor="$APP_IMAGE-snapshot")
    if [ -z "$RUNNING_ID" ]; then
        RUNNING_ID=$(podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" ps -q --filter ancestor="$APP_IMAGE")
    fi
    if [ -n "$RUNNING_ID" ]; then
        echo "[-] Stopping running container to ensure data integrity..."
        podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" stop "$RUNNING_ID" >/dev/null
    fi
    
    # 2. SNAPSHOT LOGIC
    if [ -d "$INTERNAL_HOME" ] && [ "$(ls -A $INTERNAL_HOME)" ]; then
        echo "[-] Baking session data (_session/home) into the image..."
        
        # --- SMART ID DETECTION ---
        BASE_IMAGE_ID=""
        
        if podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" image exists "$APP_IMAGE"; then
             BASE_IMAGE_ID=$(podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" image inspect --format '{{.Id}}' "$APP_IMAGE")
        elif podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" image exists "localhost/$APP_IMAGE"; then
             BASE_IMAGE_ID=$(podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" image inspect --format '{{.Id}}' "localhost/$APP_IMAGE")
        elif podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" image exists "${APP_IMAGE}-snapshot"; then
             echo "[-] Base image is a previous snapshot."
             BASE_IMAGE_ID=$(podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" image inspect --format '{{.Id}}' "${APP_IMAGE}-snapshot")
        elif podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" image exists "localhost/${APP_IMAGE}-snapshot"; then
             echo "[-] Base image is a previous snapshot."
             BASE_IMAGE_ID=$(podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" image inspect --format '{{.Id}}' "localhost/${APP_IMAGE}-snapshot")
        else
             echo "[X] Error: Base image '$APP_IMAGE' (or snapshot) not found in storage."
             exit 1
        fi

        CONT_HOME=$(detect_home "$BASE_IMAGE_ID")
        echo "    Internal Home: $CONT_HOME"

        EXPORT_CTX="$SESSION_DIR/export_tmp"
        rm -rf "$EXPORT_CTX" 2>/dev/null
        mkdir -p "$EXPORT_CTX"
        
        cp -r "$INTERNAL_HOME/." "$EXPORT_CTX/"

        # Cleanup locks
        find "$EXPORT_CTX" -name ".parentlock" -delete
        find "$EXPORT_CTX" -name "lock" -delete
        find "$EXPORT_CTX" -name ".lock" -delete

        # Use ID in FROM
        cat <<EOF > "$EXPORT_CTX/Dockerfile"
FROM $BASE_IMAGE_ID
COPY --chown=1000:1000 . $CONT_HOME/
EOF

        SNAPSHOT_TAG="${APP_IMAGE}-snapshot"
        echo "    Building snapshot layer..."
        podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" build -t "$SNAPSHOT_TAG" "$EXPORT_CTX"
        
        EXPORT_IMAGE="$SNAPSHOT_TAG"
        rm -rf "$EXPORT_CTX"
    else
        echo "[-] No session data found. Exporting base image only."
        EXPORT_IMAGE="$APP_IMAGE"
    fi

    echo "[-] Saving $EXPORT_IMAGE to app.tar..."
    
    # Handle localhost prefix
    if ! podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" image exists "$EXPORT_IMAGE"; then
        if podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" image exists "localhost/$EXPORT_IMAGE"; then
            EXPORT_IMAGE="localhost/$EXPORT_IMAGE"
        fi
    fi

    rm -f "$TAR_FILE"
    podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" save -o "$TAR_FILE" "$EXPORT_IMAGE"

    echo "[-] Cleaning local session directory..."
    rm -rf "$SESSION_DIR" 2>/dev/null || sudo rm -rf "$SESSION_DIR"
    
    echo "[-] Export Complete: $TAR_FILE (Session cleared)"
}

# ==============================================================================
# MODE 3: IMPORT (Restore Session)
# ==============================================================================
do_import() {
    check_deps
    INPUT_FILE="$1"
    
    if [ -n "$INPUT_FILE" ]; then
        if [ ! -f "$INPUT_FILE" ]; then echo "[X] File not found: $INPUT_FILE"; exit 1; fi
        echo "[-] Importing $INPUT_FILE..."
        cp "$INPUT_FILE" "$TAR_FILE"
    elif [ ! -f "$TAR_FILE" ]; then
        echo "[X] No input file specified and app.tar not found."
        exit 1
    fi
    
    mkdir -p "$PODMAN_ROOT"

    echo "[-] Loading image..."
    LOAD_OUTPUT=$(podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" load -i "$TAR_FILE")
    echo "$LOAD_OUTPUT"

    if [ ! -f "$OPTIONS_FILE" ]; then
         LOADED_IMG=$(echo "$LOAD_OUTPUT" | grep "Loaded image" | awk '{print $3}')
         if [ -z "$LOADED_IMG" ]; then LOADED_IMG="portable-imported:latest"; fi
         cat <<EOF > "$OPTIONS_FILE"
{
    "app_display_name": "Imported App",
    "image_repo_tag": "$LOADED_IMG",
    "permissions": { "DataPersistance": { "value": "Y" }, "SharedData": { "value": "Y" }, "UserMapping": { "value": "Y" }, "NetworkAccess": { "value": "Y" }, "InputDevices": { "value": "N" }, "SoundAccess": { "value": "Y" }, "MicrophoneAccess": { "value": "N" }, "WebcamAccess": { "value": "N" } },
    "port_mappings": [], "podman_extra_args": "", "xpra_extra_args": ""
}
EOF
    fi
    init_defaults

    APP_IMAGE=$(jq -r '.image_repo_tag' "$OPTIONS_FILE")
    
    # Resolve correct tag
    if ! podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" image exists "$APP_IMAGE"; then
        if podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" image exists "${APP_IMAGE}-snapshot"; then
             APP_IMAGE="${APP_IMAGE}-snapshot"
        elif podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" image exists "localhost/${APP_IMAGE}-snapshot"; then
             APP_IMAGE="localhost/${APP_IMAGE}-snapshot"
        fi
    fi

    CONT_HOME=$(detect_home "$APP_IMAGE")
    
    mkdir -p "$INTERNAL_HOME"
    
    if [ -z "$(ls -A $INTERNAL_HOME)" ]; then
        echo "[-] Restoring session data from image to _session/home..."
        
        # --- FIX: ADD --userns=keep-id TO FIX PERMISSIONS ---
        podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" run --rm \
            --userns=keep-id \
            --entrypoint /bin/sh \
            --volume "$INTERNAL_HOME:/restore_target" \
            "$APP_IMAGE" \
            -c "cd $CONT_HOME && tar cf - . | (cd /restore_target && tar xf -)"
            
        echo "[-] Session restored."
    else
        echo "[!] Session already active. Skipping restore."
    fi

    echo "[-] Import Complete. Run './appAssistant.sh' to launch."
}

# ==============================================================================
# MODE 4: RUN
# ==============================================================================
do_run() {
    check_deps
    if [ ! -f "$OPTIONS_FILE" ]; then echo "[X] Config missing. Run './appAssistant.sh build' or 'import'"; exit 1; fi

    mkdir -p "$PODMAN_ROOT" "$INTERNAL_HOME" "$SHARED_DIR" "$RUNTIME_DIR"
    chmod 700 "$RUNTIME_DIR"
    rm -f "$INTERNAL_HOME/.Xauthority" 2>/dev/null || true
    
    HOST_PORT=14500
    while ss -lptn 2>/dev/null | grep -q ":$HOST_PORT "; do ((HOST_PORT++)); done
    echo "[-] Display Port: $HOST_PORT"

    APP_NAME=$(jq -r '.app_display_name' "$OPTIONS_FILE")
    APP_IMAGE=$(jq -r '.image_repo_tag' "$OPTIONS_FILE")
    
    # Use snapshot if available
    if podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" image exists "${APP_IMAGE}-snapshot"; then
        APP_IMAGE="${APP_IMAGE}-snapshot"
        echo "[-] Using Snapshot: $APP_IMAGE"
    elif podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" image exists "localhost/${APP_IMAGE}-snapshot"; then
        APP_IMAGE="localhost/${APP_IMAGE}-snapshot"
        echo "[-] Using Snapshot: $APP_IMAGE"
    fi

    if ! podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" image exists "$APP_IMAGE"; then
        if [ -f "$TAR_FILE" ]; then
            echo "[-] Loading Image..."
            podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" load -i "$TAR_FILE"
        else
            echo "[X] Image missing. Run './appAssistant.sh build' or 'import'."
            exit 1
        fi
    fi

    CONT_HOME=$(detect_home "$APP_IMAGE")
    echo "[-] Detected: $CONT_HOME"

    ARGS=()
    # Persistence
    if [ "$(jq -r '.permissions.DataPersistance.value' "$OPTIONS_FILE")" == "Y" ]; then
        ARGS+=("--volume" "$INTERNAL_HOME:$CONT_HOME")
        if [ "$CONT_HOME" != "/root" ]; then ARGS+=("--volume" "$INTERNAL_HOME:/root"); fi
    fi
    
    # Shared
    if [ "$(jq -r '.permissions.SharedData.value' "$OPTIONS_FILE")" == "Y" ]; then
        ARGS+=("--volume" "$SHARED_DIR:/shared")
    fi
    
    # User Mapping
    ARGS+=("--userns=keep-id")

    # --- NETWORK LOGIC ---
    NET_ACCESS=$(jq -r '.permissions.NetworkAccess.value' "$OPTIONS_FILE")
    if [ "$NET_ACCESS" == "Y" ]; then
        ARGS+=("--network" "bridge")
    else
        echo "[-] Network Access: BLOCKED (Isolated Network)"
        NETWORK_NAME="portable-net-offline"
        
        if ! podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" network exists "$NETWORK_NAME"; then
             echo "[-] Creating isolated network infrastructure..."
             podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" network create --internal "$NETWORK_NAME" >/dev/null
        fi
        ARGS+=("--network" "$NETWORK_NAME")
    fi
    # ---------------------

    ARGS+=("-p" "$HOST_PORT:14500")
    ARGS+=("-e" "PUID=$(id -u)" "-e" "PGID=$(id -g)")
    ARGS+=("-e" "XDG_RUNTIME_DIR=/run/user/1000")
    ARGS+=("--volume" "$RUNTIME_DIR:/run/user/1000")

    mapfile -t PORTS < <(jq -r '.port_mappings[] // empty' "$OPTIONS_FILE")
    for PORTMAP in "${PORTS[@]}"; do
        echo "[-] Mapping Port: $PORTMAP"
        ARGS+=("-p" "$PORTMAP")
    done

    XPRA_ARGS=""
    if [ "$(jq -r '.permissions.SoundAccess.value' "$OPTIONS_FILE")" == "Y" ]; then XPRA_ARGS+=" --speaker=on"; else XPRA_ARGS+=" --speaker=off"; fi
    if [ "$(jq -r '.permissions.MicrophoneAccess.value' "$OPTIONS_FILE")" == "Y" ]; then XPRA_ARGS+=" --microphone=on"; else XPRA_ARGS+=" --microphone=off"; fi
    if [ "$(jq -r '.permissions.WebcamAccess.value' "$OPTIONS_FILE")" == "Y" ]; then
        if [ -e "/dev/video0" ]; then ARGS+=("--device" "/dev/video0"); XPRA_ARGS+=" --webcam=on"; else XPRA_ARGS+=" --webcam=no"; fi
    else XPRA_ARGS+=" --webcam=no"; fi

    PODMAN_EXTRA=$(jq -r '.podman_extra_args // ""' "$OPTIONS_FILE")
    XPRA_EXTRA=$(jq -r '.xpra_extra_args // ""' "$OPTIONS_FILE")
    if [ -n "$PODMAN_EXTRA" ] && [ "$PODMAN_EXTRA" != "null" ]; then set -f; ARGS+=($PODMAN_EXTRA); set +f; fi
    if [ -n "$XPRA_EXTRA" ] && [ "$XPRA_EXTRA" != "null" ]; then XPRA_ARGS+=" $XPRA_EXTRA"; fi

    CONTAINER_NAME="portable-$RANDOM"
    echo "[-] Launching Container..."
    podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" run -d \
           --name "$CONTAINER_NAME" \
           --shm-size=2g \
           --security-opt label=disable \
           "${ARGS[@]}" \
           "$APP_IMAGE"
    
    sleep 3
    
    if ! podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" ps | grep -q "$CONTAINER_NAME"; then
        echo "[!] CRASH DETECTED. Logs:"
        podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" logs "$CONTAINER_NAME"
        podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" rm "$CONTAINER_NAME" >/dev/null 2>&1
        exit 1
    fi

    cleanup() {
        echo "[-] Shutting down..."
        podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" stop "$CONTAINER_NAME" >/dev/null 2>&1
        podman --root "$PODMAN_ROOT" --runroot "$PODMAN_RUNROOT" rm "$CONTAINER_NAME" >/dev/null 2>&1
    }
    trap cleanup INT TERM EXIT

    xpra attach tcp:127.0.0.1:$HOST_PORT \
        --title="$APP_NAME" \
        --opengl=no \
        --notifications=no \
        $XPRA_ARGS
}

case "$1" in
    build) do_build ;;
    export) do_export ;;
    import) do_import "$2" ;;
    *) do_run ;;
esac
