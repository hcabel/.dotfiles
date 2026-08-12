{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./binds.nix
    ./rules.nix
    ./monitors.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    # The NixOS module owns the package so the portal and the compositor can
    # never drift apart.
    package = null;
    portalPackage = null;
    # Originally left this to uwsm. In practice dms-greeter launches Hyprland
    # via its own `start-hyprland` binary, bypassing uwsm entirely on at
    # least some boots — when that happens nothing ever starts
    # graphical-session.target, so dms/hypridle/hyprpolkitagent/sunshine
    # (everything bound to it) silently never come up. Letting Hyprland's
    # own exec-once announce readiness works regardless of which launcher
    # got it running.
    systemd.enable = true;

    # Hyprland 0.55 deprecated hyprlang in favour of Lua, and home-manager
    # defaults to Lua at stateVersion 26.05. Pinned back to hyprlang because:
    #   - .conf is only loaded if hyprland.lua is ABSENT, so this must be an
    #     either/or choice, not a mix;
    #   - the theme engine generates hyprlang, and the Lua `hl.bind()` API
    #     takes structured dispatchers rather than the legacy single string,
    #     so every bind would need rewriting and revalidating;
    #   - upstream keeps .conf working "for a few releases".
    # Only Lua-only features (user-defined layouts) are given up, none of
    # which are used here. Migration is contained: the Hyprland generator in
    # modules/home/theme/generators.nix, plus binds.nix and rules.nix.
    configType = "hyprlang";

    settings = {
      # ── input ────────────────────────────────────────────────────────────
      input = {
        kb_layout = "us";
        kb_options = "compose:caps";
        repeat_rate = 40;
        repeat_delay = 600;
        follow_mouse = 1;
        numlock_by_default = true;
        sensitivity = 0;
        float_switch_override_focus = false;

        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
          clickfinger_behavior = true;
          tap-to-click = true;
          scroll_factor = 0.4;
        };
      };

      gesture = [
        "3, horizontal, workspace"
        "4, down, dispatcher, exec, dms ipc call hypr toggleOverview"
      ];

      # ── layout ───────────────────────────────────────────────────────────
      general = {
        layout = "dwindle";
        resize_on_border = true;
      };

      dwindle = {
        preserve_split = true;
        special_scale_factor = 0.8;
      };

      master = {
        new_status = "master";
        new_on_top = true;
        mfact = 0.5;
      };

      # ── behaviour ────────────────────────────────────────────────────────
      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        vrr = 2;
        mouse_move_enables_dpms = true;
        focus_on_activate = false;
        initial_workspace_tracking = 0;
        middle_click_paste = false;
        enable_anr_dialog = true;
        anr_missed_pings = 15;
        allow_session_lock_restore = true;
      };

      binds = {
        workspace_back_and_forth = false;
        allow_workspace_cycles = true;
        pass_mouse_when_bound = false;
      };

      cursor = {
        sync_gsettings_theme = true;
        enable_hyprcursor = true;
        inactive_timeout = 3;
        warp_on_change_workspace = 2;
        # Hardware cursors are broken on NVIDIA under offload; software
        # cursors cost almost nothing and avoid the invisible-cursor bug.
        no_hardware_cursors = true;
      };

      xwayland.force_zero_scaling = true;

      ecosystem = {
        no_update_news = true;
        no_donation_nag = true;
      };

      # ── environment ──────────────────────────────────────────────────────
      env = [
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "XDG_SESSION_DESKTOP,Hyprland"

        "GDK_BACKEND,wayland,x11,*"
        "QT_QPA_PLATFORM,wayland;xcb"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
        "QT_AUTO_SCREEN_SCALE_FACTOR,1"
        "CLUTTER_BACKEND,wayland"
        "SDL_VIDEODRIVER,wayland"

        "MOZ_ENABLE_WAYLAND,1"
        "ELECTRON_OZONE_PLATFORM_HINT,auto"

        "GDK_SCALE,1"
        "QT_SCALE_FACTOR,1"
      ];

      # ── autostart ────────────────────────────────────────────────────────
      exec-once = [
        "${pkgs.hyprland}/bin/hypridle"
        "[workspace 4 silent] firefox"
        "[workspace 5 silent] ${pkgs.ghostty}/bin/ghostty"
        "[workspace 7 silent] ${pkgs.vesktop}/bin/vesktop"
      ];
    };

    # The theme supplies colours, gaps, rounding, blur, shadows, animations
    # and the cursor. It is the last thing sourced so it always wins.
    extraConfig = lib.mkAfter ''
      source = ${config.xdg.stateHome}/theme/current/hyprland.conf
    '';
  };
}
