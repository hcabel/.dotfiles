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
#
# Two apps can't follow a symlink into the store and need the theme's content
# copied into their own config instead — DMS, which resolves symlinks before
# watching, and anything reading its settings through DMS. `theme-apply` below
# is the single place that does that copying, shared by the switcher and by
# home activation so the two can't drift.

let
  cfg = config.hcabel.theme;

  themes = import ./build.nix { inherit pkgs themeLib; };

  stateDir = "${config.xdg.stateHome}/theme";
  currentDir = cfg.currentDir;

  dmsConfigDir = "${config.xdg.configHome}/DankMaterialShell";
  dmsSettings = "${dmsConfigDir}/settings.json";
  dmsCustomTheme = "${dmsConfigDir}/custom-theme.json";
  dmsSessionDir = "${config.xdg.stateHome}/DankMaterialShell";
  dmsSession = "${dmsSessionDir}/session.json";

  # Installs one theme into the config files that need real content rather
  # than a symlink. Idempotent, and safe to run against a live session.
  #
  # DMS rewrites settings.json whenever anything changes in its settings UI,
  # so this merges over that file instead of owning it: the keys the theme has
  # an opinion about win, and every other preference set through the UI
  # survives. The bar is one of the keys the theme owns — its layout is part
  # of the theme, so reorder widgets in the theme rather than in the UI, or a
  # rebuild will put them back.
  themeApply = pkgs.writeShellApplication {
    name = "theme-apply";
    runtimeInputs = with pkgs; [
      jq
      coreutils
    ];
    text = ''
      dir="''${1:-}"
      if [ -z "$dir" ] || [ ! -d "$dir" ]; then
        echo "theme-apply: usage: theme-apply <theme-dir>" >&2
        exit 1
      fi

      mkdir -p "${dmsConfigDir}" "${dmsSessionDir}"

      # DMS watches its custom theme file for changes but resolves symlinks
      # first, so the content has to be copied in for the watcher to fire.
      install -m600 "$dir/dms.json" "${dmsCustomTheme}"

      # Merge the theme's settings fragment over DMS's own file. Objects deep
      # merge; barConfigs is replaced entry-by-entry on id so that extra bars
      # added through the UI are left alone.
      merge_settings() {
        jq --slurpfile seed "$dir/dms-settings.json" --arg themeFile "${dmsCustomTheme}" '
          ($seed[0]) as $s
          | . * ($s | del(.barConfigs))
          | .currentThemeName = "custom"
          | .customThemeFile  = $themeFile
          | .barConfigs = (
              ($s.barConfigs // [])
              + [ (.barConfigs // [])[] | select(.id != "default") ]
            )
        ' "$1"
      }

      if [ ! -f "${dmsSettings}" ]; then
        echo '{}' > "${dmsSettings}"
      fi

      tmp=$(mktemp)
      # Tolerate a malformed settings.json rather than aborting half-done with
      # the symlink already flipped.
      if merge_settings "${dmsSettings}" > "$tmp" 2>/dev/null; then
        mv "$tmp" "${dmsSettings}"
      else
        rm -f "$tmp"
        echo "theme-apply: could not patch ${dmsSettings} (invalid JSON?), skipping" >&2
      fi

      # The desktop wallpaper is DMS's, and it lives in session.json rather than
      # settings.json. Seeding the file rather than only going through IPC is
      # what gets a machine that has never logged in the right wallpaper on its
      # first session. (The login and lock screens don't read this — they take
      # the image straight from the theme directory.)
      wallpaper="$dir/wallpaper.jpg"
      if [ -f "$wallpaper" ]; then
        tmp=$(mktemp)
        if jq --arg w "$wallpaper" \
             '.wallpaperPath = $w | .wallpaperPathDark = $w' \
             "${dmsSession}" > "$tmp" 2>/dev/null; then
          mv "$tmp" "${dmsSession}"
        else
          rm -f "$tmp"
          printf '{"wallpaperPath":"%s","wallpaperPathDark":"%s"}\n' \
            "$wallpaper" "$wallpaper" > "${dmsSession}"
        fi
      fi
    '';
  };

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

        ${themeApply}/bin/theme-apply "$CURRENT"

        # Reload everything that can be reloaded in place.
        if command -v hyprctl >/dev/null 2>&1 && [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
          hyprctl reload >/dev/null || true
        fi

        # A running DMS has session.json already loaded, so the seed written
        # by theme-apply won't be noticed — hand it the image over IPC too.
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
      default = "saturn";
      description = ''
        Theme selected on a fresh machine, before anything has been switched
        at runtime. Existing selections are left alone across rebuilds.
      '';
    };

    currentDir = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${config.xdg.stateHome}/theme/current";
      description = ''
        Symlink to the active theme's directory. Every app that follows the
        theme reads its generated config from here, so this is the one place
        the path is spelled out.
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
        name="${cfg.default}"
      else
        # Repoint at the current build of the same theme so rebuilds pick up
        # generator changes without changing which theme is active.
        name="$(${pkgs.jq}/bin/jq -r .name < "${currentDir}/meta.json" 2>/dev/null || echo "${cfg.default}")"
        if [ ! -d "${themes.all}/$name" ]; then
          name="${cfg.default}"
        fi
      fi

      run mkdir -p "${stateDir}"
      run ln -sfn "${themes.all}/$name" "${currentDir}"
      run ${themeApply}/bin/theme-apply "${themes.all}/$name"
    '';
  };
}
