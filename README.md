# 📦 Podman Portable Apps

A lightweight, rootless container manager that turns Dockerfiles into fully portable, self-contained Linux applications with GUI, audio, and persistent states.

## 🚀 Features
* **True Portability:** Export your app + settings + history into a single `.tar` file.
* **Snapshot System:** Save your session state (extensions, open tabs, history) and restore it anywhere.
* **Hardware Integration:** Automatic Xpra integration for GUI, Audio (PulseAudio), and Webcam support.
* **Rootless & Secure:** Runs entirely in user-space using Podman. No `sudo` required.
* **Sandbox Mode:** Optional network isolation (offline mode) while keeping GUI access.

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

### 4. Restore / Import
Restore the app on a different machine (or after a cleanup):
```bash
./appAssistant.sh import app.tar
```

## ⚙️ Configuration (`options.json`)
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
