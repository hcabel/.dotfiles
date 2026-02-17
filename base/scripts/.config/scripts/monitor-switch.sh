#!/usr/bin/env bash

# Replace eDP-1 with your actual laptop monitor name
LAPTOP_MONITOR="eDP-1"

handle() {
  case $1 in
    monitoradded*)
      # When any monitor is added, disable the laptop monitor
      hyprctl keyword monitor "$LAPTOP_MONITOR, disable"
      ;;
    monitorremoved*)
      # When a monitor is removed, check if there are any external monitors left
      # If not, re-enable the laptop monitor
      NUM_MONITORS=$(hyprctl monitors | grep "Monitor" | wc -l)
      if [ "$NUM_MONITORS" -eq 0 ]; then
        hyprctl keyword monitor "$LAPTOP_MONITOR, preferred, auto, 1.33"
      fi
      ;;
  esac
}

# Listen to the Hyprland socket for events
socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do handle "$line"; done
