{ lib, pkgs, ... }:

let
  wsKeys = lib.genList (i: {
    ws = toString (i + 1);
    code = "code:${toString (i + 10)}";
  }) 10;

  workspaceBinds = lib.concatMap (k: [
    "SUPER, ${k.code}, workspace, ${k.ws}"
    "SUPER CTRL, ${k.code}, movetoworkspace, ${k.ws}"
    "SUPER CTRL ALT, ${k.code}, movetoworkspacesilent, ${k.ws}"
  ]) wsKeys;

  # Open a new terminal in the focused terminal's directory when there is one.
  terminalCwd = pkgs.writeShellScript "terminal-cwd" ''
    pid=$(${pkgs.hyprland}/bin/hyprctl activewindow -j \
      | ${pkgs.jq}/bin/jq -r '.pid // empty')
    if [ -n "$pid" ]; then
      # Walk to the deepest child (the shell inside the terminal) and read its cwd.
      child=$pid
      while true; do
        next=$(${pkgs.procps}/bin/pgrep -P "$child" | head -n1)
        [ -z "$next" ] && break
        child=$next
      done
      cwd=$(readlink "/proc/$child/cwd" 2>/dev/null || true)
      [ -d "$cwd" ] && { echo "$cwd"; exit 0; }
    fi
    echo "$HOME"
  '';
in
{
  wayland.windowManager.hyprland.settings = {

    "$mod" = "SUPER";
    "$terminal" = "${pkgs.ghostty}/bin/ghostty";
    "$browser" = "firefox";

    bind =
      [
        # ── launching ──────────────────────────────────────────────────────
        "$mod, return, exec, $terminal --working-directory=$(${terminalCwd})"
        "$mod SHIFT, return, exec, $terminal"
        "$mod SHIFT, F, exec, $terminal -e ${pkgs.yazi}/bin/yazi"
        "$mod, B, exec, $browser"
        "$mod SHIFT, B, exec, $browser --private-window"

        # ── shell (DMS replaces rofi / swaync / wlogout / waybar) ──────────
        "$mod, space, exec, dms ipc call spotlight toggle"
        "$mod, N, exec, dms ipc call notifications toggle"
        "$mod, U, exec, dms ipc call control-center toggle"
        "$mod ALT, V, exec, dms ipc call clipboard toggle"
        "$mod, Escape, exec, dms ipc call powermenu toggle"
        "$mod, O, exec, dms ipc call dash open overview"
        "$mod SHIFT, P, exec, dms ipc call processlist toggle"
        "$mod, slash, exec, dms ipc call hypr toggleBinds"
        "$mod, grave, exec, dms ipc call hypr toggleOverview"

        # ── keyboard pointer control ───────────────────────────────────────
        "$mod, S, exec, ${pkgs.wl-kbptr}/bin/wl-kbptr -o modes=floating,click -o mode_floating.source=detect"
        "$mod SHIFT, S, exec, ${pkgs.wl-kbptr}/bin/wl-kbptr -o modes=tile,click"

        # ── window management ──────────────────────────────────────────────
        "$mod, W, killactive"
        "$mod, F, togglefloating"
        ", F11, fullscreen, 0"

        # focus
        "$mod, LEFT, movefocus, l"
        "$mod, RIGHT, movefocus, r"
        "$mod, UP, movefocus, u"
        "$mod, DOWN, movefocus, d"

        # swap
        "$mod ALT, LEFT, swapwindow, l"
        "$mod ALT, RIGHT, swapwindow, r"
        "$mod ALT, UP, swapwindow, u"
        "$mod ALT, DOWN, swapwindow, d"

        # resize — by keysym, not scancode: this deliberately wants the
        # literal +/- characters (so on a US layout, grow is $mod+Shift+=
        # since that's what produces "+"), not just "whatever key sits at
        # this physical position".
        "$mod, PLUS, resizeactive, 100 0"
        "$mod, MINUS, resizeactive, -100 0"
        "$mod SHIFT, PLUS, resizeactive, 0 100"
        "$mod SHIFT, MINUS, resizeactive, 0 -100"

        # ── groups ─────────────────────────────────────────────────────────
        "$mod, G, togglegroup"
        "$mod ALT, G, moveoutofgroup"
        "$mod ALT, LEFT, moveintogroup, l"
        "$mod ALT, RIGHT, moveintogroup, r"
        "$mod ALT, UP, moveintogroup, u"
        "$mod ALT, DOWN, moveintogroup, d"
        "$mod ALT, TAB, changegroupactive, f"
        "$mod ALT SHIFT, TAB, changegroupactive, b"
        "$mod CTRL, LEFT, changegroupactive, b"
        "$mod CTRL, RIGHT, changegroupactive, f"
      ]
      ++ workspaceBinds
      ++ (lib.genList (i: "$mod ALT, code:${toString (i + 10)}, changegroupactive, ${toString (i + 1)}") 5)
      ++ [
        # ── screenshots (F6 family, as you had them) ───────────────────────
        "$mod, F6, exec, ${pkgs.hyprshot}/bin/hyprshot -m output --clipboard-only"
        "$mod SHIFT, F6, exec, ${pkgs.hyprshot}/bin/hyprshot -m region --clipboard-only"
        "ALT, F6, exec, ${pkgs.hyprshot}/bin/hyprshot -m window --clipboard-only"
        "$mod CTRL, F6, exec, ${pkgs.hyprshot}/bin/hyprshot -m region -o ~/Pictures/Screenshots"
      ];

    # Repeating binds (held keys)
    binde = [
      "$mod, PLUS, resizeactive, 100 0"
      "$mod, MINUS, resizeactive, -100 0"
    ];

    # Media / hardware keys — routed through DMS so they render its OSD.
    bindel = [
      ", XF86AudioRaiseVolume, exec, dms ipc call audio increment 5"
      ", XF86AudioLowerVolume, exec, dms ipc call audio decrement 5"
      ", XF86MonBrightnessUp, exec, dms ipc call brightness increment 5 backlight:intel_backlight"
      ", XF86MonBrightnessDown, exec, dms ipc call brightness decrement 5 backlight:intel_backlight"
      ", XF86KbdBrightnessUp, exec, dms ipc call brightness increment 10"
      ", XF86KbdBrightnessDown, exec, dms ipc call brightness decrement 10"
    ];

    bindl = [
      ", XF86AudioMute, exec, dms ipc call audio mute"
      ", XF86AudioMicMute, exec, dms ipc call audio mute-mic"
      ", XF86AudioNext, exec, dms ipc call mpris next"
      ", XF86AudioPrev, exec, dms ipc call mpris previous"
      ", XF86AudioPlay, exec, dms ipc call mpris play"
      ", XF86AudioPause, exec, dms ipc call mpris pause"
      ", XF86Sleep, exec, systemctl suspend"
      ", switch:on:Lid Switch, exec, dms ipc call lock lock"
    ];

    # Mouse
    bindm = [
      "$mod, mouse:272, movewindow"
      "$mod, mouse:273, resizewindow"
    ];

    # Scroll through workspaces / group members
    bindn = [ ];
  };

  # Scroll bindings need their own list because they repeat.
  wayland.windowManager.hyprland.extraConfig = ''
    bind = $mod, mouse_down, workspace, e+1
    bind = $mod, mouse_up, workspace, e-1
    bind = $mod ALT, mouse_down, changegroupactive, f
    bind = $mod ALT, mouse_up, changegroupactive, b

    bind = $mod SHIFT, T, exec, theme next
  '';
}
