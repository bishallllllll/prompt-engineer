# Voice-to-Prompt Engineering for Open WebUI (Fedora / Wayland)

This project provides a global key-driven pipeline that automates voice dictation (via OpenWhispr) and prompt refinement (using your custom `prompt-engineer` model in Open WebUI).

---

## How It Works

1.  **F8 (Dictate)**: Start recording using OpenWhispr. When stopped, the raw transcription is typed at the active cursor and copied to the clipboard.
2.  **F9 (Correct & Replace)**: Pressing F9 triggers the orchestrator script:
    *   Reads the text in the active editor (either a manual selection, or by auto-selecting backwards).
    *   Queries your local Open WebUI instance's `prompt-engineer` model.
    *   Copies the optimized prompt back to the clipboard.
    *   Pastes (`Ctrl+V` via `ydotool`) to replace the raw speech instantly.

---

## Files

*   `prompt_engineer.py`: Python client that queries the local Open WebUI Completions API.
*   `f9-test.sh`: Bash orchestrator that manages Wayland clipboard states, highlights raw text backwards, and simulates Ctrl+V paste.

---

## Setup Instructions

### 1. Requirements
Ensure the following packages are installed on your Fedora host:
```bash
sudo dnf install wl-clipboard ydotool
pip install keyboard pyperclip
```

### 2. Open WebUI API Key Configuration
The `prompt_engineer.py` script queries the local completions API at `http://127.0.0.1:3000/api/chat/completions` using an API key `sk-prompt-engineer-shortcut`.
Ensure your Open WebUI instance has API keys enabled in its environment configurations (`ENABLE_API_KEYS=true`).

### 3. Register Global Keyboard Shortcuts in GNOME
1.  Open **Settings** -> **Keyboard** -> **Keyboard Shortcuts** -> **Custom Shortcuts**.
2.  Add a new shortcut:
    *   **Name**: `Prompt Engineer`
    *   **Command**: `/path/to/your/f9-test.sh`
    *   **Shortcut**: `F9`
3.  Click **Add**.
