{ lib, themeLib }:

# Each generator takes a theme and returns the text of one app's themed
# config. They all read their own view via `forApp`, so an app override in a
# theme automatically flows through here with no extra plumbing.

let
  inherit (themeLib)
    forApp
    toHyprRgb
    toHyprRgba
    stripHash
    alphaHex
    ;

  # Round a float to `n` decimals for config formats that dislike Nix's
  # default six-decimal `toString` output.
  f2 =
    x:
    let
      scaled = builtins.floor (x * 100.0 + 0.5);
      whole = scaled / 100;
      frac = lib.mod scaled 100;
    in
    "${toString whole}.${lib.fixedWidthString 2 "0" (toString frac)}";

  # Animation durations are authored at speed 1.0 and divided by the theme's
  # speed multiplier, so one number makes a whole theme snappier or lazier.
  dur = style: base: f2 (base / style.animations.speed);
in
rec {

  # ── Hyprland ──────────────────────────────────────────────────────────────
  hyprland =
    theme:
    let
      t = forApp theme "hyprland";
      p = t.palette;
      s = t.style;

      # A theme can hand-author its own borderGradient (glass, tokyo-night,
      # rose-pine do), but one that doesn't still gets a rotating border —
      # built from its own seven curated hues (every theme's palette has
      # these, lib/theme.nix requires it), not a fixed rainbow that ignores
      # which theme is active. "Random colour, but in the theme's colours."
      gradient =
        if s.borderGradient != null then
          s.borderGradient
        else
          with p; [
            red
            orange
            yellow
            green
            cyan
            blue
            magenta
          ];
      angle = if s.borderAngle != null then s.borderAngle else 45;

      borderCols = lib.concatMapStringsSep " " toHyprRgb gradient + " ${toString angle}deg";
    in
    ''
      # Generated from theme "${theme.name}" — do not edit.
      # Source: modules/home/theme/themes/${theme.name}.nix

      general {
        border_size = ${toString s.borderSize}
        gaps_in = ${toString s.gaps.inner}
        gaps_out = ${toString s.gaps.outer}

        col.active_border = ${borderCols}
        col.inactive_border = ${toHyprRgb p.borderInactive}
      }

      decoration {
        rounding = ${toString s.rounding}

        active_opacity = ${f2 s.opacity.active}
        inactive_opacity = ${f2 s.opacity.inactive}
        fullscreen_opacity = ${f2 s.opacity.fullscreen}

        blur {
          enabled = ${lib.boolToString s.blur.enable}
          size = ${toString s.blur.size}
          passes = ${toString s.blur.passes}
          noise = ${f2 s.blur.noise}
          contrast = ${f2 s.blur.contrast}
          brightness = ${f2 s.blur.brightness}
          vibrancy = ${f2 s.blur.vibrancy}
          vibrancy_darkness = ${f2 s.blur.vibrancyDarkness}
        }

        shadow {
          enabled = ${lib.boolToString s.shadow.enable}
          range = ${toString s.shadow.range}
          render_power = ${toString s.shadow.power}
          offset = ${s.shadow.offset}
          color = ${toHyprRgba p.base 0.6}
        }
      }

      group {
        col.border_active = ${toHyprRgb p.border}
        col.border_inactive = ${toHyprRgb p.borderInactive}

        groupbar {
          font_family = ${s.fonts.mono}
          font_size = ${toString s.fonts.sizeSmall}
          col.active = ${toHyprRgb p.accent}
          col.inactive = ${toHyprRgb p.surface}
          text_color = ${toHyprRgb p.text}
        }
      }

      animations {
        enabled = ${lib.boolToString s.animations.enable}

        bezier = wind, 0.05, 0.9, 0.1, 1.05
        bezier = winIn, 0.1, 1.1, 0.1, 1.1
        bezier = winOut, 0.3, -0.3, 0, 1
        bezier = liner, 1, 1, 1, 1
        bezier = md3_decel, 0.05, 0.7, 0.1, 1
        bezier = menu_decel, 0.1, 1, 0, 1
        bezier = menu_accel, 0.38, 0.04, 1, 0.07

        animation = windows,      1, ${dur s 6.0},  wind, slide
        animation = windowsIn,    1, ${dur s 6.0},  winIn, slide
        animation = windowsOut,   1, ${dur s 5.0},  winOut, slide
        animation = windowsMove,  1, ${dur s 5.0},  wind, slide
        animation = fade,         1, ${dur s 3.0},  md3_decel
        animation = layersIn,     1, ${dur s 3.0},  menu_decel, slide
        animation = layersOut,    1, ${dur s 1.6},  menu_accel
        animation = fadeLayersIn, 1, ${dur s 2.0},  menu_decel
        animation = fadeLayersOut,1, ${dur s 4.5},  menu_accel
        animation = workspaces,   1, ${dur s 5.0},  wind
        animation = specialWorkspace, 1, ${dur s 3.0}, md3_decel, slidevert
        animation = border,       1, ${dur s 1.0},  liner
        # Rotating gradient — the declarative replacement for RainbowBorders.sh.
        # Always on: the border colour is always a gradient now (explicit or
        # auto-derived above), never a flat single colour.
        animation = borderangle,  1, 30, liner, loop
      }

      # Cursor
      env = HYPRCURSOR_THEME,${s.cursor.name}
      env = HYPRCURSOR_SIZE,${toString s.cursor.size}
      env = XCURSOR_THEME,${s.cursor.name}
      env = XCURSOR_SIZE,${toString s.cursor.size}
    '';

  # ── hyprlock ──────────────────────────────────────────────────────────────
  hyprlock =
    theme:
    let
      t = forApp theme "hyprlock";
      p = t.palette;
      s = t.style;
    in
    ''
      # Generated from theme "${theme.name}" — do not edit.

      background {
        monitor =
        # Every theme dir ships a wallpaper.jpg — either the theme's own image
        # or a gradient generated from its palette at build time.
        path = ~/.local/state/theme/current/wallpaper.jpg
        color = ${toHyprRgb p.base}
        blur_passes = ${toString s.blur.passes}
        blur_size = ${toString s.blur.size}
        brightness = 0.7
      }

      animations {
        enabled = ${lib.boolToString s.animations.enable}
      }

      input-field {
        monitor =
        size = 400, 60
        position = 0, -80
        halign = center
        valign = center

        outline_thickness = ${toString s.borderSize}
        rounding = ${toString s.rounding}

        inner_color = ${toHyprRgba p.surface s.opacity.panel}
        outer_color = ${toHyprRgb p.accent}
        font_color = ${toHyprRgb p.text}
        check_color = ${toHyprRgb p.accentAlt}
        fail_color = ${toHyprRgb p.red}

        font_family = ${s.fonts.mono}
        placeholder_text = <span foreground="##${stripHash p.muted}">Password</span>
        fail_text = <span foreground="##${stripHash p.red}">$FAIL ($ATTEMPTS)</span>

        fade_on_empty = false
        shadow_passes = 0
      }

      label {
        monitor =
        text = $TIME
        color = ${toHyprRgb p.text}
        font_size = 96
        font_family = ${s.fonts.sans}
        position = 0, 120
        halign = center
        valign = center
      }

      label {
        monitor =
        text = cmd[update:60000] date +"%A, %d %B"
        color = ${toHyprRgb p.subtle}
        font_size = 20
        font_family = ${s.fonts.sans}
        position = 0, 40
        halign = center
        valign = center
      }

      auth {
        fingerprint:enabled = true
      }
    '';

  # ── Ghostty ───────────────────────────────────────────────────────────────
  ghostty =
    theme:
    let
      t = forApp theme "ghostty";
      p = t.palette;
      s = t.style;
    in
    ''
      # Generated from theme "${theme.name}" — do not edit.

      background = ${stripHash p.base}
      foreground = ${stripHash p.text}
      cursor-color = ${stripHash p.accent}
      selection-background = ${stripHash p.overlay}
      selection-foreground = ${stripHash p.text}

      palette = 0=${p.overlay}
      palette = 1=${p.red}
      palette = 2=${p.green}
      palette = 3=${p.yellow}
      palette = 4=${p.blue}
      palette = 5=${p.magenta}
      palette = 6=${p.cyan}
      palette = 7=${p.text}
      palette = 8=${p.muted}
      palette = 9=${p.red}
      palette = 10=${p.green}
      palette = 11=${p.orange}
      palette = 12=${p.blue}
      palette = 13=${p.magenta}
      palette = 14=${p.cyan}
      palette = 15=${p.text}

      background-opacity = ${f2 s.opacity.terminal}
      ${lib.optionalString s.blur.enable "background-blur-radius = ${toString s.blur.size}"}

      font-family = ${s.fonts.mono}
      font-size = ${toString s.fonts.size}
    '';

  # ── DankMaterialShell ─────────────────────────────────────────────────────
  # DMS speaks Material 3 colour roles. We map our curated palette onto them
  # so the shell renders our exact colours, and set matugen_type to
  # scheme-fidelity so the GTK/Qt palette it derives for unconverted apps
  # stays as close to our source colours as its algorithm allows.
  dms =
    theme:
    let
      t = forApp theme "dms";
      p = t.palette;
    in
    builtins.toJSON {
      name = theme.name;
      matugen_type = "scheme-fidelity";

      primary = p.accent;
      primaryText = p.base;
      primaryContainer = p.overlay;

      secondary = p.accentAlt;
      surfaceTint = p.accent;

      surface = p.surface;
      surfaceText = p.text;
      surfaceVariant = p.overlay;
      surfaceVariantText = p.subtle;
      surfaceContainer = p.surface;
      surfaceContainerHigh = p.overlay;
      surfaceContainerHighest = p.overlay;

      background = p.base;
      backgroundText = p.text;

      outline = p.muted;

      error = p.red;
      warning = p.orange;
      info = p.blue;
    };

  # ── fish ──────────────────────────────────────────────────────────────────
  fish =
    theme:
    let
      t = forApp theme "fish";
      p = t.palette;
      c = col: stripHash col;
    in
    ''
      # Generated from theme "${theme.name}" — do not edit.

      set -g fish_color_normal        ${c p.text}
      set -g fish_color_command       ${c p.accent}
      set -g fish_color_keyword       ${c p.magenta}
      set -g fish_color_quote         ${c p.green}
      set -g fish_color_redirection   ${c p.cyan}
      set -g fish_color_end           ${c p.orange}
      set -g fish_color_error         ${c p.red}
      set -g fish_color_param         ${c p.subtle}
      set -g fish_color_comment       ${c p.muted}
      set -g fish_color_selection     --background=${c p.overlay}
      set -g fish_color_search_match  --background=${c p.overlay}
      set -g fish_color_operator      ${c p.cyan}
      set -g fish_color_escape        ${c p.magenta}
      set -g fish_color_autosuggestion ${c p.muted}
      set -g fish_color_cwd           ${c p.accentAlt}
      set -g fish_color_user          ${c p.green}
      set -g fish_color_host          ${c p.blue}
      set -g fish_color_valid_path    --underline

      set -g fish_pager_color_progress    ${c p.muted}
      set -g fish_pager_color_prefix      ${c p.accent} --bold
      set -g fish_pager_color_completion  ${c p.text}
      set -g fish_pager_color_description ${c p.muted}

      # Git prompt colours (used by conf.d/prompt.fish)
      set -g __fish_git_prompt_color_branch       ${c p.magenta} --bold
      set -g __fish_git_prompt_color_dirtystate   ${c p.cyan}
      set -g __fish_git_prompt_color_stagedstate  ${c p.yellow}
      set -g __fish_git_prompt_color_invalidstate ${c p.red}
      set -g __fish_git_prompt_color_cleanstate   ${c p.green} --bold
    '';

  # ── lazygit ───────────────────────────────────────────────────────────────
  lazygit =
    theme:
    let
      t = forApp theme "lazygit";
      p = t.palette;
    in
    builtins.toJSON {
      gui.theme = {
        activeBorderColor = [
          p.accent
          "bold"
        ];
        inactiveBorderColor = [ p.muted ];
        searchingActiveBorderColor = [
          p.accentAlt
          "bold"
        ];
        optionsTextColor = [ p.blue ];
        selectedLineBgColor = [ p.overlay ];
        cherryPickedCommitBgColor = [ p.overlay ];
        cherryPickedCommitFgColor = [ p.accent ];
        unstagedChangesColor = [ p.red ];
        defaultFgColor = [ p.text ];
      };
    };

  # ── yazi ──────────────────────────────────────────────────────────────────
  yazi =
    theme:
    let
      t = forApp theme "yazi";
      p = t.palette;
    in
    ''
      # Generated from theme "${theme.name}" — do not edit.

      [mgr]
      cwd = { fg = "${p.cyan}" }
      hovered = { fg = "${p.base}", bg = "${p.accent}" }
      preview_hovered = { underline = true }
      find_keyword = { fg = "${p.yellow}", italic = true }
      find_position = { fg = "${p.magenta}", bg = "reset", italic = true }
      marker_selected = { fg = "${p.green}", bg = "${p.green}" }
      marker_copied = { fg = "${p.yellow}", bg = "${p.yellow}" }
      marker_cut = { fg = "${p.red}", bg = "${p.red}" }
      tab_active = { fg = "${p.base}", bg = "${p.accent}" }
      tab_inactive = { fg = "${p.text}", bg = "${p.overlay}" }
      border_style = { fg = "${p.muted}" }

      [mode]
      normal_main = { fg = "${p.base}", bg = "${p.accent}", bold = true }
      select_main = { fg = "${p.base}", bg = "${p.green}", bold = true }
      unset_main  = { fg = "${p.base}", bg = "${p.red}", bold = true }

      [status]
      progress_label = { fg = "${p.text}", bold = true }
      progress_normal = { fg = "${p.accent}", bg = "${p.overlay}" }
      progress_error = { fg = "${p.red}", bg = "${p.overlay}" }

      [input]
      border = { fg = "${p.accent}" }
      title = { fg = "${p.text}" }

      [pick]
      border = { fg = "${p.accent}" }
      active = { fg = "${p.magenta}", bold = true }
      inactive = { fg = "${p.text}" }

      [confirm]
      border = { fg = "${p.accent}" }
      title = { fg = "${p.accent}" }

      [notify]
      title_info = { fg = "${p.green}" }
      title_warn = { fg = "${p.yellow}" }
      title_error = { fg = "${p.red}" }
    '';

  # ── wl-kbptr ──────────────────────────────────────────────────────────────
  wl-kbptr =
    theme:
    let
      t = forApp theme "wl-kbptr";
      p = t.palette;
      s = t.style;
      # wl-kbptr wants #rrggbbaa
      a = col: alpha: "${col}${alphaHex alpha}";
    in
    ''
      # Generated from theme "${theme.name}" — do not edit.

      [general]
      home_row_keys=
      modes=tile,bisect
      cancellation_status_code=0

      [mode_tile]
      label_color=${a p.text 1.0}
      label_select_color=${a p.accent 1.0}
      unselectable_bg_color=${a p.base 0.67}
      selectable_bg_color=${a p.surface 0.88}
      selectable_border_color=${a p.border 1.0}
      label_font_family=${s.fonts.mono}
      label_font_size=8 50% 100
      label_symbols=abcdefghijklmnorstuvwxyz

      [mode_floating]
      source=detect
      label_color=${a p.text 1.0}
      label_select_color=${a p.accent 1.0}
      unselectable_bg_color=${a p.base 0.67}
      selectable_bg_color=${a p.surface 0.88}
      selectable_border_color=${a p.border 1.0}
      label_font_family=${s.fonts.mono}
      label_font_size=12 50% 100
      label_symbols=abcdefghijklmnorstuvwxyz

      [mode_bisect]
      label_color=${a p.text 1.0}
      label_font_size=20
      label_font_family=${s.fonts.mono}
      label_padding=12
      pointer_size=20
      pointer_color=${a p.red 1.0}
      unselectable_bg_color=${a p.base 0.67}
      even_area_bg_color=${a p.surface 0.75}
      even_area_border_color=${a p.border 1.0}
      odd_area_bg_color=${a p.overlay 0.5}
      odd_area_border_color=${a p.accent 1.0}
      history_border_color=${a p.muted 1.0}

      [mode_split]
      pointer_size=20
      pointer_color=${a p.red 1.0}
      bg_color=${a p.base 0.67}
      area_bg_color=${a p.surface 0.75}
      vertical_color=${a p.border 1.0}
      horizontal_color=${a p.accentAlt 1.0}
      history_border_color=${a p.muted 1.0}

      [mode_click]
      button=left
    '';

  # ── Neovim ────────────────────────────────────────────────────────────────
  # Your nvim config lives in its own repo, so rather than generate a
  # colorscheme we expose the palette as a Lua table it can require().
  nvim =
    theme:
    let
      t = forApp theme "nvim";
      p = t.palette;
      s = t.style;
      entries = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (k: v: "    ${k} = \"${v}\",") p
      );
    in
    ''
      -- Generated from theme "${theme.name}" — do not edit.
      -- Consume from your nvim config with:
      --   local ok, theme = pcall(dofile, vim.fn.expand("~/.local/state/theme/current/nvim.lua"))
      return {
        name = "${theme.name}",
        polarity = "${theme.polarity}",
        font = "${s.fonts.mono}",
        palette = {
      ${entries}
        },
      }
    '';

  # ── bat ───────────────────────────────────────────────────────────────────
  bat =
    theme:
    let
      t = forApp theme "bat";
    in
    ''
      --theme=${if t.polarity == "dark" then "ansi" else "GitHub"}
      --style=numbers,changes
      --italic-text=always
    '';

  # ── delta (git pager) ─────────────────────────────────────────────────────
  delta =
    theme:
    let
      t = forApp theme "delta";
      p = t.palette;
    in
    ''
      # Generated from theme "${theme.name}" — do not edit.
      [delta]
          syntax-theme = ansi
          minus-style = normal "${p.red}"
          minus-emph-style = normal "${p.red}"
          plus-style = syntax "${p.green}"
          plus-emph-style = syntax "${p.green}"
          line-numbers-zero-style = "${p.muted}"
          line-numbers-left-style = "${p.muted}"
          line-numbers-right-style = "${p.muted}"
          file-style = "${p.accent}" bold
          file-decoration-style = "${p.muted}" ul
          hunk-header-style = "${p.subtle}"
          hunk-header-decoration-style = "${p.muted}" box
    '';

  # ── GTK ───────────────────────────────────────────────────────────────────
  # DMS themes GTK via matugen, but it only runs after login. This gives GTK a
  # correct palette immediately and covers the case where matugen is off.
  gtk =
    theme:
    let
      t = forApp theme "gtk";
      p = t.palette;
      s = t.style;
    in
    ''
      /* Generated from theme "${theme.name}" — do not edit. */
      @define-color theme_bg_color ${p.base};
      @define-color theme_base_color ${p.surface};
      @define-color theme_fg_color ${p.text};
      @define-color theme_text_color ${p.text};
      @define-color theme_selected_bg_color ${p.accent};
      @define-color theme_selected_fg_color ${p.base};
      @define-color borders ${p.muted};
      @define-color warning_color ${p.orange};
      @define-color error_color ${p.red};
      @define-color success_color ${p.green};
      @define-color accent_color ${p.accent};
      @define-color accent_bg_color ${p.accent};
      @define-color accent_fg_color ${p.base};
      @define-color window_bg_color ${p.base};
      @define-color window_fg_color ${p.text};
      @define-color view_bg_color ${p.surface};
      @define-color view_fg_color ${p.text};
      @define-color headerbar_bg_color ${p.surface};
      @define-color headerbar_fg_color ${p.text};
      @define-color popover_bg_color ${p.overlay};
      @define-color popover_fg_color ${p.text};
      @define-color card_bg_color ${p.surface};
      @define-color card_fg_color ${p.text};

      window, .background { border-radius: ${toString s.rounding}px; }
    '';

  # ── metadata ──────────────────────────────────────────────────────────────
  meta =
    theme:
    builtins.toJSON {
      inherit (theme) name polarity description;
      font = theme.style.fonts.mono;
      cursor = {
        inherit (theme.style.cursor) name size;
      };
    };
}
