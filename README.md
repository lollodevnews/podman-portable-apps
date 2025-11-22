# 📦 Podman Portable Apps

A lightweight, rootless container manager that turns Dockerfiles into fully portable, self-contained Linux applications with GUI, audio, and **granular permission control**.

## 🚀 Features
* **True Portability:** Export your app + settings + history into a single `.tar` file.
* **Snapshot System:** Save your session state (extensions, open tabs, history) and restore it anywhere.
* **Hardware Integration:** Automatic Xpra integration for GUI, Audio (PulseAudio), and Webcam support.
* **Rootless & Secure:** Runs entirely in user-space using Podman. No `sudo` required.
* **Sandbox Model:** **Granular control over network and hardware access** ensures the container is isolated from the host.

## 🛠️ Requirements
* Linux OS
* `podman`
* `xpra`
* `jq`

## ⚡ Quick Start

### 1. Build an App
Enter any app directory (e.g., Firefox) and build the base image:
```bash
cd firefox
./appAssistant.sh build
```

### 2. Run the App
Launch the portable container:
```bash
./appAssistant.sh
```

### 3. Snapshot & Export
Save your current progress (cookies, extensions, work) to a portable file:
```bash
./appAssistant.sh export
```
*Creates an `app.tar` file containing the software AND your data.*
It will ask for a password, in case you want to encrypt your exported setup.

### 4. Restore / Import
Restore the app on a different machine (or after a cleanup):
```bash
./appAssistant.sh import app.tar
```

## 🛡️ The Permission Model (Security & Isolation)

The `appAssistant.sh` script enforces security by adhering to strict Podman principles, ensuring the container cannot escape its boundaries:

1.  **Rootless Execution:** Containers run as the current user, not as the system administrator, limiting damage exposure.
2.  **Explicit Data Mapping:** Data is only shared via the `shared/` folder. All app configuration (home directory) is managed inside the volatile `_session/` folder.
3.  **Network Isolation:** By setting `"NetworkAccess": "N"` in `options.json`, the app is forced onto a private internal network, blocking all outbound traffic to the public internet while allowing the local GUI connection (Xpra) to function.

## ⚙️ Configuration (`options.json`)

This file defines the applications unique identity, its container image name, and all runtime permissions. It must be present in the root directory for the `build` and `run` commands to execute.

### File Structure Breakdown

| Field | Purpose | Example |
| :--- | :--- | :--- |
| `app_display_name` | Name displayed in the Xpra window title. | `"Portable VLC"` |
| `image_repo_tag` | The local name used to tag the container image (must be unique). | `"portable-vlc:latest"` |
| `port_mappings` | Array of `HOST:CONTAINER` port strings for network access (e.g., web servers). | `["8080:80"]` |
| `podman_extra_args` | String of flags passed directly to the `podman run` command. | `"--cpus 2"` |
| `xpra_extra_args` | String of flags passed directly to the `xpra attach` command. | `"--webcam=yes"` |
| `permissions` | Object containing Y/N toggles for hardware and isolation. (See table below). | |

### Permission Toggles
Each app has an `options.json` file to control permissions:

| Setting | Description |
| :--- | :--- |
| **DataPersistance** | `Y` = Save changes to `_session`. `N` = Amnesic mode (wipe on close). |
| **SharedData** | `Y` = Mounts the local `shared/` folder into the container. |
| **NetworkAccess** | `Y` = Internet access. `N` = Offline (Internal network only). |
| **Sound/Webcam** | hardware access controls. |

## 🤖 Generating New Apps with Gemini
You can use Google Gemini to generate the configuration files for any Linux application you want to make portable.

**Copy and paste this prompt into Gemini:**

> "I need a Dockerfile and options.json for a portable version of **[APP NAME]** using Alpine Linux and Xpra.
>
> **Requirements:**
> 1. **Base:** `alpine:latest`
> 2. **Install:** The app, `xpra`, `xauth`, `xvfb`, `ttf-dejavu` (and any audio/video deps).
> 3. **User:** Create a user with UID 1000.
> 4. **Entrypoint:** Must launch `xpra start --start-child=...` pointing to the app binary.
> 5. **Options.json:** Must include the standard `appAssistant` structure with `permissions` and `port_mappings`."

## 🏗️ Architecture
* **_session/**: Contains the live state (storage, home dir, runtime).
* **shared/**: A folder for moving files in/out of the container.
* **app.tar**: The frozen portable state.

## 🤝 Credits
Developed with assistance from Google Gemini.

## 📜 License
MIT
