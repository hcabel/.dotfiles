{ ... }:

# Tag-based window rules, in Hyprland 0.55's `match:` syntax.
#
# Apps get tagged once, then rules act on tags. Your original had ~200 lines
# matching editors and messengers you don't run — this keeps the structure and
# trims the list to software that's actually installed.

{
  wayland.windowManager.hyprland.settings = {

    windowrule = [
      # ── tagging ────────────────────────────────────────────────────────────
      "match:class ^([Ff]irefox|org.mozilla.firefox|[Zz]en(-browser)?|[Cc]hromium|[Bb]rave-browser)$, tag +browser"
      "match:class ^(com.mitchellh.ghostty|[Gg]hostty|kitty)$, tag +terminal"
      "match:class ^([Dd]iscord|[Vv]esktop|[Ww]ebCord)$, tag +im"
      "match:class ^([Cc]ode|code-url-handler|dev.zed.Zed|[Nn]eovide|obsidian)$, tag +projects"
      "match:class ^([Ss]team|com.heroicgameslauncher.hgl|net.lutris.Lutris)$, tag +gamestore"
      "match:class ^(gamescope|steam_app_\\d+)$, tag +games"
      "match:class ^(com.obsproject.Studio)$, tag +screenshare"
      "match:class ^(org.gnome.Nautilus|[Tt]hunar|org.kde.dolphin)$, tag +file-manager"
      "match:class ^(mpv|vlc|io.github.celluloid_player.Celluloid)$, tag +video"
      "match:class ^(org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager|org.gnome.Settings)$, tag +settings"
      "match:class ^(org.gnome.Loupe|org.gnome.Evince|eog|evince)$, tag +viewer"
      "match:class ^(xdg-desktop-portal-gtk|org.freedesktop.impl.portal.desktop.gtk)$, tag +portal"

      # ── workspace routing ──────────────────────────────────────────────────
      "match:tag projects, workspace 2"
      "match:tag browser, workspace 4"
      "match:tag terminal, workspace 5"
      "match:tag im, workspace 7"
      "match:tag gamestore, workspace 8"
      "match:tag games, workspace 9"

      # ── floating ───────────────────────────────────────────────────────────
      "match:tag settings, float on, center on, size (monitor_w*0.6) (monitor_h*0.7)"
      "match:tag viewer, float on, center on, size (monitor_w*0.7) (monitor_h*0.7)"
      "match:tag portal, float on, center on"
      "match:class ^(org.gnome.Calculator)$, float on, center on, size (monitor_w*0.25) (monitor_h*0.35)"
      "match:title ^(Authentication Required)$, float on, center on"
      "match:title ^(Open Files|Save As|Select a File)$, float on, center on, size (monitor_w*0.7) (monitor_h*0.6)"
      # Steam's own subwindows float; the library itself does not.
      "match:class ^([Ss]team)$ match:title negative:^([Ss]team)$, float on, center on"

      # ── picture-in-picture ─────────────────────────────────────────────────
      "match:title ^(Picture-in-Picture)$, float on, pin on, keep_aspect_ratio on, size (monitor_w*0.28) (monitor_h*0.28), move 71% 4%"

      # ── opacity ────────────────────────────────────────────────────────────
      # Video and games must never be dimmed or blurred — it costs frames and
      # wrecks colour accuracy.
      "match:tag video, opacity 1.0, no_blur on"
      "match:tag games, opacity 1.0, no_blur on, idle_inhibit fullscreen"
      "match:tag gamestore, opacity 1.0"
      "match:tag screenshare, opacity 1.0, no_blur on"
      "match:fullscreen true, idle_inhibit fullscreen"

      # ── behaviour fixes ────────────────────────────────────────────────────
      # XWayland drag-and-drop surfaces steal focus without this.
      "match:class ^$ match:title ^$ match:xwayland 1 match:floating 1, no_focus on"
      "match:class ^(jetbrains-.*)$, no_initial_focus on"
    ];

    layerrule = [
      # The shell's own surfaces get the glass treatment.
      "match:namespace ^(quickshell.*)$, blur on"
      "match:namespace ^(quickshell.*)$, ignore_alpha 0.3"
      "match:namespace ^(dms.*)$, blur on"
      "match:namespace ^(dms.*)$, ignore_alpha 0.3"
      "match:namespace ^(notifications)$, blur on"
    ];
  };
}
