#!/bin/bash

# 1. Save current clipboard (which has the raw speech from OpenWhispr)
OLD_CLIPBOARD=$(wl-paste)

# 2. Put a unique marker in the clipboard to check if user has a manual selection
MARKER="NO_SELECTION_ACTIVE_$$"
echo -n "$MARKER" | wl-copy

# 3. Simulate Ctrl+C to copy active selection
sleep 0.05
ydotool key 29:1 46:1 46:0 29:0 # 29=Ctrl, 46=C
sleep 0.1

# 4. Check if clipboard changed
CURRENT_CLIPBOARD=$(wl-paste)

if [ "$CURRENT_CLIPBOARD" != "$MARKER" ] && [ -n "$CURRENT_CLIPBOARD" ]; then
    # --- Case A: User has manually highlighted text ---
    TEXT_TO_PROCESS="$CURRENT_CLIPBOARD"
    JUMPS=0
else
    # --- Case B: No manual selection active; we auto-select backwards ---
    # Restore the raw speech to clipboard
    echo -n "$OLD_CLIPBOARD" | wl-copy
    
    # Calculate jumps for OLD_CLIPBOARD safely using stdin
    JUMPS=$(echo -n "$OLD_CLIPBOARD" | python3 -c "import sys, re; print(len(re.findall(r'\w+|[^\w\s]+', sys.stdin.read())))")
    
    if [ "$JUMPS" -gt 0 ]; then
        # Select the text backwards (Hold Ctrl+Shift, press Left JUMPS times)
        # Use -d 6 to insert a 6ms delay between events to prevent key drops
        YDO_SELECT="key -d 6 29:1 42:1"
        for ((i=0; i<JUMPS; i++)); do
            YDO_SELECT="$YDO_SELECT 105:1 105:0"
        done
        YDO_SELECT="$YDO_SELECT 42:0 29:0"
        
        ydotool $YDO_SELECT
        sleep 0.1
        
        # Copy the newly highlighted text (which contains any manual edits in the editor!)
        ydotool key 29:1 46:1 46:0 29:0
        sleep 0.1
        
        TEXT_TO_PROCESS=$(wl-paste)
    else
        TEXT_TO_PROCESS="$OLD_CLIPBOARD"
    fi
fi

# Check if we have text to process
if [ -z "$TEXT_TO_PROCESS" ] || [ "$TEXT_TO_PROCESS" = "$MARKER" ]; then
    notify-send "Prompt Engineer" "No text found to process."
    exit 0
fi

# Show status notification
notify-send "Prompt Engineer" "Processing text from editor..." -t 1500

# Save to a temporary file
echo "$TEXT_TO_PROCESS" > /tmp/f9_raw.txt

# Call the prompt-engineer component
/home/monarch/bin/prompt_engineer.py /tmp/f9_raw.txt > /tmp/f9_output.txt 2> /tmp/f9_error.txt

if [ $? -ne 0 ]; then
    ERR_MSG=$(cat /tmp/f9_error.txt)
    notify-send "Prompt Engineer Error" "Failed to process prompt: $ERR_MSG"
    exit 1
fi

OUTPUT_PROMPT=$(cat /tmp/f9_output.txt)

if [ -n "$OUTPUT_PROMPT" ]; then
    # Copy the prompt back to the clipboard
    echo -n "$OUTPUT_PROMPT" | wl-copy
    
    # Paste (Ctrl+V) to overwrite the selection (since it remains highlighted in both cases)
    sleep 0.1
    ydotool key 29:1 47:1 47:0 29:0
    
    notify-send "Prompt Engineer" "Done! Prompt replaced successfully."
else
    notify-send "Prompt Engineer Error" "Received empty prompt from model."
fi
