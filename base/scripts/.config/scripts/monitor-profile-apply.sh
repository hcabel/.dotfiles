#!/usr/bin/env bash

CONFIG="$HOME/.config/hypr/monitor-profiles.json"
MONITORS=$(hyprctl monitors all -j)

declare -a MON_NAMES
declare -a MON_DESCS
declare -a MON_PRIOS
declare -a MON_PROFILES

MAX_PRIO=-9999
INDEX=0

while read -r mon; do
  NAME=$(echo "$mon" | jq -r '.name')
  DESC=$(echo "$mon" | jq -r '.description')

  PROFILE=$(jq -c --arg desc "$DESC" '
    .profiles | to_entries | map(select(.key as $k | $desc | contains($k))) | if length > 0 then .[0].value else null end
  ' "$CONFIG")

  # Fallback to default if no match is found
  if [[ "$PROFILE" == "null" || -z "$PROFILE" ]]; then
    PROFILE=$(jq -c '.default' "$CONFIG")
  fi

  PRIO=$(echo "$PROFILE" | jq -r '.priority // 0')

  MON_NAMES[$INDEX]="$NAME"
  MON_DESCS[$INDEX]="$DESC"
  MON_PRIOS[$INDEX]="$PRIO"
  MON_PROFILES[$INDEX]="$PROFILE"

  if (( PRIO > MAX_PRIO )); then
    MAX_PRIO=$PRIO
  fi

  INDEX=$((INDEX + 1))
done < <(echo "$MONITORS" | jq -c '.[]')

for ((i=0; i<INDEX; i++)); do
  NAME="${MON_NAMES[$i]}"
  DESC="${MON_DESCS[$i]}"
  PRIO="${MON_PRIOS[$i]}"
  PROFILE="${MON_PROFILES[$i]}"

  if (( PRIO == MAX_PRIO )); then
    SCALE=$(echo "$PROFILE" | jq -r '.scale // 1')
    MODE=$(echo "$PROFILE" | jq -r '.mode // "preferred"')
    POS=$(echo "$PROFILE" | jq -r '.position // "auto"')

    echo "[ENABLING] $NAME ($DESC): Prio $PRIO -> $MODE, $POS, $SCALE"
    hyprctl --quiet keyword monitor "$NAME,$MODE,$POS,$SCALE"
  else
    echo "[DISABLING] $NAME ($DESC): Prio $PRIO (Max is $MAX_PRIO)"
    hyprctl --quiet keyword monitor "$NAME,disable"
  fi
done
