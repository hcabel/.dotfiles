#!/usr/bin/env bash

MONITOR_SCRIPT="$HOME/.config/scripts/monitor-profile-apply.sh"
LOCK_FILE="/tmp/hypr_monitor_cooldown"

# Ensure no leftover lockfile exists on startup
rm -f "$LOCK_FILE"

# Wait a brief moment to ensure Hyprland socket is fully initialized
sleep 2

TIMER_PID=""

# Listen to the Hyprland event socket
socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do
    if [[ "$line" == monitoraddedv2* ]] || [[ "$line" == monitorremovedv2* ]]; then

        # 1. If the lockfile exists, our script is currently changing settings.
        # Ignore these "echo" events!
        if [ -f "$LOCK_FILE" ]; then
            # echo "[IGNORED SCRIPT ECHO] $line"
            continue
        fi

        echo "[EVENT] $line"

        # 2. Debounce logic
        if [ -n "$TIMER_PID" ]; then
            kill "$TIMER_PID" 2>/dev/null
        fi

        # 3. Start countdown
        (
            sleep 1

            # Create the lockfile right before we change settings
            touch "$LOCK_FILE"

            echo "[ACTION] Hardware settled. Applying monitor profile..."
            bash "$MONITOR_SCRIPT"

            # Keep the listener deaf for 2 seconds to absorb Hyprland's echo events,
            # then delete the lockfile so it can listen for physical unplugs again.
            sleep 2
            rm -f "$LOCK_FILE"
        ) &

        TIMER_PID=$!
    fi
done
