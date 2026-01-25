#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# for rainbow borders animation

function random_hex() {
    random_hex=("0xff$(openssl rand -hex 3)")
    echo $random_hex
}

hex_1=$(random_hex)
hex_2=$(random_hex)
hex_3=$(random_hex)
hex_4=$(random_hex)
hex_5=$(random_hex)
hex_6=$(random_hex)
hex_7=$(random_hex)
hex_8=$(random_hex)
hex_9=$(random_hex)
hex_10=$(random_hex)

# rainbow colors only for active window
hyprctl keyword general:col.active_border $hex_1 $hex_2 $hex_3 $hex_4 $hex_5 $hex_6 $hex_7 $hex_8 $hex_9 $hex_10 270deg
hyprctl keyword group:col.border_active $hex_1 $hex_2 $hex_3 $hex_4 $hex_5 $hex_6 $hex_7 $hex_8 $hex_9 $hex_10 270deg
