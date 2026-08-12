{
  config,
  lib,
  pkgs,
  themeLib,
  ...
}:

# Wires the built themes into the session:
#   ~/.local/state/theme/all      → every theme, read-only, in the store
#   ~/.local/state/theme/current  → symlink to the active one (runtime state)
#
# Apps never read a theme directly; they read `current/<file>`. Switching is
# therefore a symlink flip plus a few reload signals, with no rebuild.

let
  cfg = config.hcabel.theme;

  themes = import ./build.nix { inherit pkgs themeLib; };

  stateDir = "${config.xdg.stateHome}/theme";
  currentDir = "${stateDir}/current";

  themeSwitcher = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = with pkgs; [
      jq
      coreutils
      findutils
      procps
      libnotify
    ];
    text = ''
      ALL="${themes.all}"
      STATE="${stateDir}"
      CURRENT="$STATE/current"
      DMS_CONFIG="${config.xdg.configHome}/DankMaterialShell/settings.json"

      usage() {
        cat <<'EOF'
      theme — switch the curated desktop theme

        theme list           list available themes
        theme current        print the active theme
        theme set <name>     switch to <name>
        theme next           cycle to the next theme
      EOF
      }

      list_themes() { find "$ALL" -maxdepth 1 -mindepth 1 -printf '%f\n' | sort; }

      current_theme() {
        if [ -L "$CURRENT" ]; then
          jq -r .name < "$CURRENT/meta.json"
        else
          echo "${cfg.default}"
        fi
      }

      apply() {
        local name="$1"
        if [ ! -d "$ALL/$name" ]; then
          echo "theme: unknown theme '$name'" >&2
          echo "available: $(list_themes | tr '\n' ' ')" >&2
          return 1
        fi

        mkdir -p "$STATE"
        ln -sfn "$ALL/$name" "$CURRENT.tmp"
        mv -Tf "$CURRENT.tmp" "$CURRENT"

        # DMS watches its custom theme file for changes, but it resolves
        # symlinks — so copy the content in to make the watcher fire.
        mkdir -p "$(dirname "$DMS_CONFIG")"
        install -m600 "$CURRENT/dms.json" \
          "${config.xdg.configHome}/DankMaterialShell/custom-theme.json"

        if [ -f "$DMS_CONFIG" ]; then
          tmp=$(mktemp)
          # Tolerate a malformed settings.json rather than aborting the switch
          # half-done with the symlink already flipped.
          if jq --arg f "${config.xdg.configHome}/DankMaterialShell/custom-theme.json" \
               '.currentThemeName = "custom" | .customThemeFile = $f' \
               "$DMS_CONFIG" > "$tmp" 2>/dev/null; then
            mv "$tmp" "$DMS_CONFIG"
          else
            rm -f "$tmp"
            echo "theme: could not patch $DMS_CONFIG (invalid JSON?), skipping" >&2
          fi
        fi

        # Reload everything that can be reloaded in place.
        if command -v hyprctl >/dev/null 2>&1 && [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
          hyprctl reload >/dev/null || true
        fi

        # DMS owns the wallpaper, so hand it the theme's image.
        if command -v dms >/dev/null 2>&1; then
          dms ipc call wallpaper set "$CURRENT/wallpaper.jpg" >/dev/null 2>&1 || true
        fi

        # Ghostty reloads config on SIGUSR2; already-open shells keep their
        # colours until the next prompt redraw.
        pkill -USR2 -x ghostty 2>/dev/null || true

        notify-send -a theme "Theme" "Switched to $name" 2>/dev/null || true
        echo "theme: now using '$name'"
      }

      case "''${1:-}" in
        list)    list_themes ;;
        current) current_theme ;;
        set)     [ $# -ge 2 ] || { usage; exit 1; }; apply "$2" ;;
        next)
          mapfile -t all < <(list_themes)
          cur=$(current_theme)
          idx=0
          # Written as an explicit `if` rather than `[ … ] && idx=$i`: under
          # `set -e` a false test as the last command in the loop body would
          # abort the script.
          for i in "''${!all[@]}"; do
            if [ "''${all[$i]}" = "$cur" ]; then
              idx=$i
            fi
          done
          apply "''${all[$(( (idx + 1) % ''${#all[@]} ))]}"
          ;;
        ""|-h|--help) usage ;;
        *) usage; exit 1 ;;
      esac
    '';
  };

in
{
  options.hcabel.theme = {
    default = lib.mkOption {
      type = lib.types.enum themes.names;
      default = "glass";
      description = ''
        Theme selected on a fresh machine, before anything has been switched
        at runtime. Existing selections are left alone across rebuilds.
      '';
    };
  };

  config = {
    home.packages = [ themeSwitcher ];

    # Expose the palette to the session so scripts and apps can read it
    # without parsing a config file.
    home.sessionVariables = {
      THEME_DIR = currentDir;
    };

    # Seed the selection on first activation only — never stomp a theme the
    # user switched to at runtime.
    home.activation.seedTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -L "${currentDir}" ]; then
        run mkdir -p "${stateDir}"
        run ln -sfn "${themes.all}/${cfg.default}" "${currentDir}"
      else
        # Repoint at the current build of the same theme so rebuilds pick up
        # generator changes without changing which theme is active.
        name="$(${pkgs.jq}/bin/jq -r .name < "${currentDir}/meta.json" 2>/dev/null || echo "${cfg.default}")"
        if [ -d "${themes.all}/$name" ]; then
          run ln -sfn "${themes.all}/$name" "${currentDir}"
        else
          run ln -sfn "${themes.all}/${cfg.default}" "${currentDir}"
        fi
      fi

      # Keep DMS's copy of the theme in step with the store build.
      run mkdir -p "${config.xdg.configHome}/DankMaterialShell"
      run install -m600 "${currentDir}/dms.json" \
        "${config.xdg.configHome}/DankMaterialShell/custom-theme.json"
    '';
  };
}
