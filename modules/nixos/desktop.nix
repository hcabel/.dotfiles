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
  # In modules/nixos/login.nix — a custom quickshell greeter sharing one QML
  # component with the lock screen. DMS's greeter is deliberately not used; its
  # layout is fixed and only its colours are themeable.

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

  # hypridle is deliberately *not* enabled here. The home-manager module in
  # modules/home/lock.nix owns it: it writes the config this machine actually
  # uses and defines the user unit, and a unit in ~/.config/systemd/user
  # shadows the one this module would stage in /etc/systemd/user anyway. The
  # NixOS module would also pull in hyprlock, which this setup replaces with
  # its own lock screen (modules/nixos/login.nix).

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
  # The greeter authenticates through greetd's own PAM stack; the lock screen's
  # is set up alongside it in modules/nixos/login.nix.
  security.pam.services.greetd.enableGnomeKeyring = true;

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
