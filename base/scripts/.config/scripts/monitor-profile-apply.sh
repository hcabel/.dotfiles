#!/usr/bin/env bash

CONFIG="$HOME/.config/hypr/monitor-profiles.json"

MONITORS=$(hyprctl monitors -j)

apply_monitor() {
  local name="$1"
  local desc="$2"
  local index="$3"

  USING_DEFAULT=false
  PROFILE=$(jq -r --arg desc "$desc" '.profiles[$desc]' "$CONFIG")
  if [[ "$PROFILE" == "null" ]]; then
    USING_DEFAULT=true
    PROFILE=$(jq '.default' "$CONFIG")
  fi

  SCALE=$(echo "$PROFILE" | jq -r '.scale // 1')
  MODE=$(echo "$PROFILE" | jq -r '.mode // "preferred"')
  POS=$(echo "$PROFILE" | jq -r '.position // "auto"')

  if $USING_DEFAULT; then
    echo "$name ($desc): Default"
  else
    echo "$name ($desc): $MODE, $POS, $SCALE"
  fi
  hyprctl --quiet keyword monitor "$name,$MODE,$POS,$SCALE"
}

# Loop monitors
INDEX=0

echo "$MONITORS" | jq -c '.[]' | while read -r mon; do
  NAME=$(echo "$mon" | jq -r '.name')
  DESC=$(echo "$mon" | jq -r '.description')

  apply_monitor "$NAME" "$DESC" "$INDEX"

  INDEX=$((INDEX + 1))
done
