{ pkgs, ... }:

{
  # ── compositor ─────────────────────────────────────────────────────────────
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    # uwsm gives the session proper systemd targets, which is what DMS's user
    # service binds to.
    withUWSM = true;
  };

  programs.hyprlock.enable = true;

  # ── shell ──────────────────────────────────────────────────────────────────
  programs.dms-shell = {
    enable = true;

    enableSystemMonitoring = true; # dgop — replaces btop in the bar
    enableVPN = true;
    enableDynamicTheming = true; # matugen, used only to reach GTK/Qt
    enableClipboardPaste = true; # wtype, for clipboard history paste
    enableCalendarEvents = false; # no khal setup

    systemd.enable = true;
  };

  # ── login screen ───────────────────────────────────────────────────────────
  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "hyprland";
    configHome = "/home/hcabel";
    logs.save = true;
  };

  # ── portals ────────────────────────────────────────────────────────────────
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [
      "hyprland"
      "gtk"
    ];
  };

  # ── session services ───────────────────────────────────────────────────────
  security.polkit.enable = true;
  services.hypridle.enable = true;

  # Polkit agent, so privilege prompts render as a themed dialog rather than
  # failing silently.
  systemd.user.services.hyprpolkitagent = {
    description = "Hyprland polkit authentication agent";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      # The package installs its binary under libexec, not bin — mirrors the
      # unit it ships itself at share/systemd/user/hyprpolkitagent.service.
      ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      Restart = "on-failure";
    };
  };

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.dms-greeter.enableGnomeKeyring = true;

  services.udisks2.enable = true; # removable media in the file manager
  services.gvfs.enable = true;

  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    hyprpolkitagent
    hyprpicker
    hyprshot
    wl-clipboard
    wl-kbptr
    libnotify

    nautilus # A graphical file manager for the cases yazi is wrong for.
    vesktop # Alternate client for Discord
  ];
}

