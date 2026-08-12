{ config, pkgs, ... }:

{
  imports = [
    ../modules/home/theme
    ../modules/home/hyprland
    ../modules/home/shell.nix
    ../modules/home/terminal.nix
    ../modules/home/git.nix
    ../modules/home/firefox.nix
    ../modules/home/yazi.nix
    ../modules/home/nvim.nix
    ../modules/home/lock.nix
    ../modules/home/dms.nix
  ];

  home = {
    username = "hcabel";
    homeDirectory = "/home/hcabel";
    stateVersion = "26.05";
  };

  # Which curated theme a fresh machine starts on. Switching at runtime with
  # `theme set <name>` does not require changing this.
  hcabel.theme.default = "glass";

  xdg.enable = true;

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  # GTK and Qt follow the theme's polarity and cursor; DMS refines the exact
  # colours through matugen once the session is up.
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  home.pointerCursor = {
    enable = true;
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    hyprcursor.enable = true;
  };

  programs.home-manager.enable = true;
}
