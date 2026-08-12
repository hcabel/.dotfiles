{
  config,
  lib,
  pkgs,
  ...
}:

# Monitor profiles, ported from monitor-profiles.json + monitor-profile-apply.sh.
#
# Behaviour is unchanged: match each connected output by description substring,
# find the highest priority present, enable every monitor at that priority and
# disable the rest. So docking to the Iiyama blanks the laptop panel, and
# undocking brings it back.
#
# The profiles are Nix data now, so a typo is a build error rather than a
# silently-ignored jq lookup.

let
  cfg = config.hcabel.monitors;

  profileType = lib.types.submodule {
    options = {
      mode = lib.mkOption {
        type = lib.types.str;
        default = "preferred";
        description = "Resolution@refresh, or \"preferred\".";
      };
      position = lib.mkOption {
        type = lib.types.str;
        default = "auto";
        description = "Position, e.g. \"0x0\" or \"auto\".";
      };
      scale = lib.mkOption {
        type = lib.types.either lib.types.float lib.types.int;
        default = 1;
      };
      priority = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = ''
          Highest priority present wins; everything below it is switched off.
        '';
      };
    };
  };

  # Emit the profile table as a bash case statement — no runtime config file
  # to parse, and no jq needed for the lookup.
  matchProfile = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (desc: p: ''
      if [[ "$desc" == *"${desc}"* ]]; then
        echo "${p.mode}|${p.position}|${toString p.scale}|${toString p.priority}"
        return
      fi
    '') cfg.profiles
  );

  applyScript = pkgs.writeShellApplication {
    name = "monitor-profile-apply";
    runtimeInputs = with pkgs; [
      hyprland
      jq
    ];
    text = ''
      lookup() {
        local desc="$1"
      ${matchProfile}
        echo "${cfg.fallback.mode}|${cfg.fallback.position}|${toString cfg.fallback.scale}|${toString cfg.fallback.priority}"
      }

      names=(); descs=(); modes=(); poss=(); scales=(); prios=()
      max=-999999

      while IFS= read -r line; do
        name="''${line%%$'\t'*}"
        desc="''${line#*$'\t'}"

        IFS='|' read -r mode pos scale prio <<< "$(lookup "$desc")"

        names+=("$name"); descs+=("$desc")
        modes+=("$mode"); poss+=("$pos"); scales+=("$scale"); prios+=("$prio")

        # An explicit `if`, not `(( … )) && max=$prio`: under `set -e` a false
        # arithmetic test as the last command in the loop body would abort.
        if (( prio > max )); then
          max=$prio
        fi
      done < <(hyprctl monitors all -j | jq -r '.[] | "\(.name)\t\(.description)"')

      for i in "''${!names[@]}"; do
        if (( ''${prios[$i]} == max )); then
          echo "[enable ] ''${names[$i]} (''${descs[$i]}) → ''${modes[$i]}, ''${poss[$i]}, ''${scales[$i]}"
          hyprctl --quiet keyword monitor \
            "''${names[$i]},''${modes[$i]},''${poss[$i]},''${scales[$i]}"
        else
          echo "[disable] ''${names[$i]} (''${descs[$i]}) — priority ''${prios[$i]} < $max"
          hyprctl --quiet keyword monitor "''${names[$i]},disable"
        fi
      done
    '';
  };

  # Replaces monitor-listener.sh: react to hotplug instead of polling.
  listenScript = pkgs.writeShellApplication {
    name = "monitor-listener";
    runtimeInputs = [
      applyScript
      pkgs.socat
    ];
    text = ''
      socket="''${XDG_RUNTIME_DIR}/hypr/''${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
      socat -U - "UNIX-CONNECT:$socket" | while read -r event; do
        case "$event" in
          monitoradded*|monitorremoved*)
            sleep 0.5
            monitor-profile-apply
            ;;
        esac
      done
    '';
  };

in
{
  options.hcabel.monitors = {
    profiles = lib.mkOption {
      type = lib.types.attrsOf profileType;
      default = { };
      description = ''
        Keyed by a substring of the monitor description as reported by
        `hyprctl monitors all -j`.
      '';
    };

    fallback = lib.mkOption {
      type = profileType;
      default = { };
      description = "Applied to any monitor that matches no profile.";
    };
  };

  config = {
    # Your existing profiles, carried over from monitor-profiles.json.
    hcabel.monitors = {
      profiles = {
        # Laptop panels — either of the two you've had.
        "AU Optronics 0xD0A2" = {
          scale = 1.2;
          position = "0x0";
          priority = 0;
        };
        "Sharp Corporation 0x1548" = {
          scale = 1.2;
          position = "0x0";
          priority = 0;
        };
        # The desk monitor wins whenever it's plugged in.
        "Iiyama North America PL2730Q" = {
          mode = "2560x1440@59.95Hz";
          position = "0x0";
          scale = 1.0;
          priority = 1;
        };
      };

      fallback = {
        mode = "preferred";
        position = "auto";
        scale = 1;
        priority = 0;
      };
    };

    home.packages = [
      applyScript
      listenScript
    ];

    wayland.windowManager.hyprland.settings = {
      # Let the script own monitor layout; this is just a safe default for a
      # display that appears before the script runs.
      monitor = [ ",preferred,auto,1" ];

      exec-once = [
        "${applyScript}/bin/monitor-profile-apply"
        "${listenScript}/bin/monitor-listener"
      ];
    };
  };
}
