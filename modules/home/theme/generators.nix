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
    grubGeometry
    mix
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
          with p;
          [
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
      # DMS falls back to surfaceContainerHigh for these, which collapses the
      # accent ramp into one flat colour. Naming them keeps the pink and
      # purple distinguishable on chips and tiles.
      secondaryContainer = p.overlay;
      tertiary = p.magenta;
      tertiaryContainer = p.overlay;
      surfaceTint = p.accent;

      surface = p.surface;
      surfaceText = p.text;
      surfaceVariant = p.overlay;
      surfaceVariantText = p.subtle;
      surfaceContainer = p.surface;
      surfaceContainerHigh = p.overlay;
      surfaceContainerHighest = p.overlay;
      # Only read by the matugen hand-off that themes GTK/Qt. Left unset they
      # default to surface/background, which flattens the elevation ramp for
      # every app that isn't converted yet.
      surfaceContainerLow = p.base;
      surfaceContainerLowest = p.base;
      surfaceBright = p.overlay;
      surfaceDim = p.base;

      background = p.base;
      backgroundText = p.text;

      outline = p.muted;
      outlineVariant = p.borderInactive;

      error = p.red;
      warning = p.orange;
      info = p.blue;
      success = p.green;
    };

  # ── DankMaterialShell: settings.json fragment ─────────────────────────────
  # The part of DMS's settings the theme owns: the bar's layout and geometry,
  # and the handful of appearance keys that are colour- or shape-adjacent.
  #
  # Everything here is *merged over* whatever DMS has written rather than
  # replacing the file, so the settings UI keeps working for the many keys the
  # theme has no opinion about. See `theme-apply` in modules/home/theme.
  dmsSettings =
    theme:
    let
      t = forApp theme "dms";
      s = t.style;
      b = s.bar;

      # DMS has no bar-height setting. It derives thickness from innerPadding:
      #
      #   widgetThickness = max(20, 26 + p * 0.6)
      #   thickness       = max(widgetThickness + p + 4, 48 - 4 - (8 - p))
      #                   = max(30 + 1.6p, 36 + p)          [for p >= 0]
      #
      # so the second term wins below p = 10 and the first above it. Inverting
      # each branch lets a theme state the height it wants in px and get it.
      #   — DankBarWindow.qml, effectiveBarThickness
      innerPaddingFor =
        h:
        let
          p = if h <= 46 then h - 36 else builtins.floor ((h - 30) / 1.6 + 0.5);
        in
        if p < 0 then 0 else p;
    in
    builtins.toJSON {
      barConfigs = [
        {
          id = "default";
          name = "Main Bar";
          enabled = true;
          position = 0; # top

          # The design's three groups: identity on the left, workspaces
          # centred, status on the right.
          leftWidgets = [
            "launcherButton"
            "focusedWindow"
          ];
          centerWidgets = [ "workspaceSwitcher" ];
          rightWidgets = [
            "systemTray"
            "cpuUsage"
            "memUsage"
            # Carries the network / volume / bluetooth glyph cluster that the
            # design draws as one pill.
            "controlCenterButton"
            "battery"
            "clock"
            "notificationButton"
            "powerMenuButton"
          ];

          innerPadding = innerPaddingFor b.height;
          spacing = b.edgeGap;
          widgetPadding = b.widgetPadding;

          transparency = b.transparency;
          widgetTransparency = b.widgetTransparency;

          gothCornersEnabled = b.gothCorners;
          gothCornerRadiusOverride = true;
          gothCornerRadiusValue = b.cornerRadius;

          # No gap between the bar and its dropdowns — they have to touch for
          # the fillets to join them into one shape.
          popupGapsAuto = false;
          popupGapsManual = 0;
        }
      ];

      popupTransparency = s.opacity.panel;
      dockTransparency = s.opacity.panel;
      cornerRadius = s.rounding;

      fontFamily = s.fonts.sans;
      monoFontFamily = s.fonts.mono;

      # DMS regenerates GTK/Qt through matugen from the colours above once the
      # session is up, which is the hand-off home/default.nix is written
      # around. It owns ~/.config/gtk-*/gtk.css outright, so there is no second
      # Nix-generated stylesheet to compete with it.
      gtkThemingEnabled = true;
      qtThemingEnabled = true;

      # ── not theme-derived ─────────────────────────────────────────────────
      # These two aren't about the theme at all; they're here because this file
      # is the one channel Nix has into DMS's settings. Both exist to stop DMS
      # putting up its own lock screen, now that the lock is ours
      # (modules/nixos/login.nix).
      #
      # DMS otherwise reacts to logind's Lock signal and locks in-process, which
      # would race our lock client for the same ext-session-lock protocol.
      # hypridle already listens for that signal and runs `saturn-lock`.
      loginctlLockIntegration = false;
      # And its power menu's lock button calls its lock directly rather than
      # going through logind, so it would be the one path showing a different
      # screen from every other. Dropped; `$mod+L` locks instead.
      powerMenuActions = [
        "reboot"
        "logout"
        "poweroff"
        "suspend"
        "restart"
      ];
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
      entries = lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "    ${k} = \"${v}\",") p);
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

  # ── delta (git pager) ─────────────────────────────────────────────────────
  delta =
    theme:
    let
      t = forApp theme "delta";
      p = t.palette;
      # Whole-line background: mostly base, just tinted — dark and muted so
      # syntax-highlighted text stays readable on top of it.
      lineBg = c: mix c p.base 0.72;
      # Changed-word background: mostly the colour, lifted toward text —
      # lighter than the line so the exact edit stands out from it.
      wordBg = c: mix c p.text 0.30;
    in
    ''
      # Generated from theme "${theme.name}" — do not edit.
      [delta]
          syntax-theme = ansi
          minus-style = syntax "${lineBg p.red}"
          minus-emph-style = "${p.base}" "${wordBg p.red}"
          plus-style = syntax "${lineBg p.green}"
          plus-emph-style = "${p.base}" "${wordBg p.green}"
          line-numbers-zero-style = "${p.muted}"
          line-numbers-left-style = "${p.muted}"
          line-numbers-right-style = "${p.muted}"
          file-style = "${p.accent}" bold
          file-decoration-style = "${p.muted}" ul
          hunk-header-style = "${p.subtle}"
          hunk-header-decoration-style = "${p.muted}" box
    '';

  # ── login surface ─────────────────────────────────────────────────────────
  # Read by modules/home/shell/login. That surface is QML rather than a config
  # file, so it gets the theme as data and does its own layout — which is what
  # lets one component be both the greeter and the lock screen.
  #
  # The wallpaper is deliberately *not* named here: this file is generated
  # before the theme derivation exists, so it can't know its own store path.
  # The QML resolves `wallpaper.jpg` as a sibling of this file instead, which
  # also means the lock screen follows `theme set` through the `current`
  # symlink for free.
  loginTheme =
    theme:
    let
      t = forApp theme "login";
      p = t.palette;
      s = t.style;
    in
    builtins.toJSON {
      inherit (t) name polarity;

      colors = {
        inherit (p)
          base
          surface
          overlay
          muted
          subtle
          text
          accent
          accentAlt
          red
          green
          cyan
          magenta
          ;
      };

      fonts = {
        inherit (s.fonts) mono sans;
        size = s.fonts.size;
      };

      rounding = s.rounding;
      panelOpacity = s.opacity.panel;
    };

  # ── GRUB ──────────────────────────────────────────────────────────────────
  # A gfxmenu theme for the generation menu. The images it references are cut
  # by modules/nixos/bootloader.nix from this same theme's palette.
  #
  # Two structural notes, both learned the hard way from GRUB's own themes:
  #
  #  * boot_menu must stay a top-level component. Nesting it in a vbox breaks
  #    item highlighting — kdePackages.breeze-grub carries the same warning.
  #  * Coordinates only parse integer percentages (`7%`, `50%-200`), so the
  #    design's pixel offsets are rounded to whole percent of a 1920x1080
  #    screen, which is the mode bootloader.nix pins.
  grub =
    theme:
    let
      t = forApp theme "grub";
      p = t.palette;
      s = t.style;
      m = s.bootMenu;

      # theme.txt's numbers are not the design's numbers — see grubGeometry.
      inherit (grubGeometry m)
        corner
        itemHeight
        itemSpacing
        progressSlot
        terminal
        ;
    in
    assert lib.assertMsg (itemHeight > 0) ''
      Theme "${theme.name}": bootMenu.itemHeight (${toString m.itemHeight}) must
      exceed twice the corner slice (${toString (2 * corner)}), or GRUB has no
      room left for the row's text.
    '';
    ''
      # Generated from theme "${theme.name}" — do not edit.
      # Source: modules/home/theme/themes/${theme.name}.nix

      title-text: ""
      desktop-image: "background.png"
      desktop-image-scale-method: "crop"
      desktop-color: "${p.base}"
      message-color: "${p.subtle}"
      message-bg-color: "${p.surface}"
      terminal-font: "${s.fonts.mono} Regular 14"

      # gfxterm's window, stated rather than defaulted, because bootloader.nix
      # crops the background to exactly this rect so the window is invisible
      # while the kernel loads. Changing it here without changing the crop puts
      # a misaligned copy of the wallpaper on screen.
      terminal-left: "${toString terminal.x}"
      terminal-top: "${toString terminal.y}"
      terminal-width: "${toString terminal.width}"
      terminal-height: "${toString terminal.height}"
      terminal-border: "0"

      # The monogram and hostname, on the same left column as the splash and
      # the greeter so the three screens don't shift under each other.
      + image {
        left = 7%
        top = 26%
        width = 86
        height = 72
        file = "logo.png"
      }

      + label {
        left = 12%
        top = 29%
        width = 20%
        text = "${lib.toUpper theme.name}"
        color = "${p.subtle}"
        font = "${s.fonts.sans} Regular 12"
      }

      + label {
        left = 7%
        top = 34%
        width = 40%
        text = "SELECT GENERATION"
        color = "${p.muted}"
        font = "${s.fonts.sans} Regular 12"
      }

      + boot_menu {
        left = 7%
        top = 38%
        width = 35%
        height = 34%

        # gfxmenu reserves space for an icon per entry even when none is set,
        # so both dimensions go to zero to reclaim it.
        icon_width = 0
        icon_height = 0
        # With no icon, this is simply how far the label sits from the card's
        # inner edge. The card's own left pad is the corner slice, so the text
        # ends up ${toString (corner + 4)}px from the card edge.
        item_icon_space = 4

        item_height = ${toString itemHeight}
        item_spacing = ${toString itemSpacing}
        item_padding = ${toString m.itemPadding}

        item_font = "${s.fonts.sans} Regular 16"
        selected_item_font = "${s.fonts.sans} Regular 16"
        item_color = "${p.subtle}"
        selected_item_color = "${p.text}"

        item_pixmap_style = "item_*.png"
        selected_item_pixmap_style = "select_*.png"

        scrollbar = false
      }

      # ASCII only, deliberately. The design writes this line with ↑↓ and ↵,
      # and Inter has all three, but grub-mkfont's output renders them as
      # missing-glyph boxes — verified by booting the theme, not by inspecting
      # the font. Words beat tofu on a screen shown for three seconds.
      + label {
        left = 7%
        top = 74%
        width = 40%
        text = "arrows move  -  enter boots  -  e edits cmdline  -  c console"
        color = "${p.muted}"
        font = "${s.fonts.sans} Regular 11"
      }

      # The autoboot countdown, as the design's thin accent rule. The component
      # is ${toString progressSlot}px tall because it cannot be less; the rule itself is
      # ${toString m.progressHeight}px, drawn inside transparent pixmaps. highlight_overlay makes the
      # fill share the track's origin instead of being inset inside it, so the
      # two bands line up exactly.
      + progress_bar {
        id = "__timeout__"
        left = 7%
        top = 78%
        width = 22%
        height = ${toString progressSlot}
        show_text = false
        bar_style = "progress_track_*.png"
        highlight_style = "progress_fill_*.png"
        highlight_overlay = true

        # Only reached if the pixmaps fail to load, in which case GRUB falls
        # back to filling the whole component as a flat rect.
        fg_color = "${p.accent}"
        bg_color = "${p.borderInactive}"
        border_color = "${p.borderInactive}"
      }
    '';

  # ── logo ──────────────────────────────────────────────────────────────────
  # The "hc" monogram, in the theme's own accent ramp: an H drawn as a filled
  # path, and a C as a stroked arc. Every theme ships one so anything that
  # wants to brand a screen — the boot splash today — can rasterise it at
  # whatever size it needs instead of carrying a fixed-size bitmap.
  logo =
    theme:
    let
      t = forApp theme "logo";
      p = t.palette;
    in
    ''
      <?xml version="1.0" encoding="UTF-8"?>
      <!-- Generated from theme "${theme.name}" — do not edit. -->
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 100" width="120" height="100">
        <defs>
          <linearGradient id="mark" x1="0" y1="1" x2="1" y2="0">
            <stop offset="0%" stop-color="${p.accent}"/>
            <stop offset="100%" stop-color="${p.accentAlt}"/>
          </linearGradient>
        </defs>
        <path fill="url(#mark)"
              d="M20 18 L32 18 L32 44 L54 44 L54 18 L66 18 L66 82 L54 82 L54 56 L32 56 L32 82 L20 82 Z"/>
        <path fill="none" stroke="${p.text}" stroke-width="12"
              d="M100 34a24 24 0 1 0 0 32"/>
      </svg>
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
