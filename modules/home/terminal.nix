{ config, pkgs, ... }:

let
  themeDir = "${config.xdg.stateHome}/theme/current";
in
{
  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;

    settings = {
      # Colours, opacity, blur and font all arrive from the active theme.
      config-file = [ "${themeDir}/ghostty.conf" ];

      window-padding-x = 14;
      window-padding-y = 14;
      window-decoration = "none";
      confirm-close-surface = false;
      resize-overlay = "never";

      cursor-style = "block";
      cursor-style-blink = false;

      # Matches the copy/paste bindings your Hyprland config sends.
      keybind = [
        "ctrl+insert=copy_to_clipboard"
        "shift+insert=paste_from_clipboard"
        "ctrl+shift+comma=reload_config"
      ];

      shell-integration = "fish";
      shell-integration-features = "cursor,sudo,title";

      # Ghostty renders on the iGPU under PRIME offload; this keeps it there
      # rather than spinning up the dGPU for a terminal.
      gtk-single-instance = true;

      auto-update = "off"; # Nix owns updates
    };
  };

  # wl-clipboard, wl-kbptr, hyprshot and libnotify come from the system layer
  # (modules/nixos/desktop.nix) since the greeter and shell need them too.
  home.packages = with pkgs; [
    brightnessctl
    playerctl
  ];

  xdg.configFile."wl-kbptr/config".source =
    config.lib.file.mkOutOfStoreSymlink "${themeDir}/wl-kbptr.conf";
}
