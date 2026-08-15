{ ... }:

# Idle and lock behaviour.
#
# The lock screen is our own — the same QML the greeter draws, driven by PAM
# through ext-session-lock-v1, so it is a real lock rather than an overlay and
# the two screens cannot drift apart. See modules/nixos/login.nix, which
# provides the `saturn-lock` command called below; hyprlock is not installed.
#
# `loginctl lock-session` still works as the way to ask for a lock: hypridle
# subscribes to logind's Lock signal and runs `lock_cmd` in response. So the
# timeout and before-sleep entries below go through logind, and every other
# caller (the lid switch, a keybind) can too.

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "saturn-lock";
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
