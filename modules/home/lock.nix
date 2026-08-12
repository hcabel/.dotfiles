{ config, ... }:

let
  themeDir = "${config.xdg.stateHome}/theme/current";
in
{
  # hyprlock's whole appearance is themed, so the config is just a source line.
  programs.hyprlock = {
    enable = true;
    extraConfig = ''
      source = ${themeDir}/hyprlock.conf
    '';
  };

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
        inhibit_sleep = 3; # wait until the screen is actually locked
      };

      listener = [
        {
          # Dim the backlight as a warning before locking.
          timeout = 300; # 5 min
          on-timeout = "brightnessctl -s set 10";
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 600; # 10 min
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 660; # 11 min
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on && brightnessctl -r";
        }
        {
          # Plain suspend, not suspend-then-hibernate: hibernation needs a
          # swap area at least as large as RAM, and this machine runs zram
          # rather than disk swap.
          timeout = 1800; # 30 min
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };
}
