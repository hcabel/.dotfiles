{ lib }:

# ─────────────────────────────────────────────────────────────────────────────
# The theme engine.
#
# A theme is curated data, never derived from a wallpaper. It carries:
#
#   palette  — the shared colours every app sees by default
#   style    — shared non-colour style tokens (rounding, blur, opacity, fonts…)
#   apps     — per-app overrides of *either* of the above, so an app can
#              deviate as much as it wants without forking the theme
#
# An app asks for its view of the theme with `forApp theme "ghostty"`, which
# is `palette // style` deep-merged with `theme.apps.ghostty`. An app that
# isn't mentioned in `apps` simply gets the shared values — that's the
# fallback for everything nobody has converted yet.
# ─────────────────────────────────────────────────────────────────────────────

let
  inherit (lib)
    recursiveUpdate
    mapAttrs
    attrNames
    filter
    isAttrs
    concatStringsSep
    ;

  # Style tokens every theme inherits unless it says otherwise. A theme only
  # has to state what makes it distinctive.
  defaultStyle = {
    rounding = 10;
    borderSize = 2;

    gaps = {
      inner = 4;
      outer = 8;
    };

    opacity = {
      active = 1.0;
      inactive = 0.9;
      fullscreen = 1.0;
      # Terminals and the shell usually want to be more transparent than
      # arbitrary application windows, so they get their own knob.
      terminal = 0.9;
      panel = 0.9;
    };

    # The shell's top bar. Geometry lives here rather than in the DMS
    # generator so a theme can restyle the bar the same way it restyles
    # anything else, and so the numbers sit next to the opacities they're
    # read alongside.
    bar = {
      # Thickness of the bar slab, in px. DMS has no height setting — it
      # derives thickness from its innerPadding — so the generator inverts
      # that formula to hit this number. See generators.nix.
      height = 48;

      # Gap between the slab and the screen edge. 0 makes the bar flush,
      # which is what goth corners need to read correctly.
      edgeGap = 4;

      # Horizontal padding inside a single widget's pill.
      widgetPadding = 8;

      # Radius of the concave corners where a bar-attached popup meets the
      # screen edge — DMS calls these "goth corners". Turning these on is
      # what makes a dropdown read as growing out of the bar rather than
      # floating underneath it.
      cornerRadius = 12;
      gothCorners = false;

      # Alpha of the bar slab, and of each widget's pill on top of it.
      # Distinct from opacity.panel, which is the dropdown below them.
      transparency = 1.0;
      widgetTransparency = 1.0;
    };

    # The bootloader's generation menu. Same reasoning as `bar`: the theme.txt
    # generator and the derivation that slices the row images both need these
    # numbers, so they live here instead of being restated in each.
    bootMenu = {
      itemHeight = 48;
      itemSpacing = 6;
      # Inset of an item's text from its card. GRUB adds this to the drawn box
      # rather than insetting within it, so it has to stay small or consecutive
      # cards overlap.
      itemPadding = 4;
      cornerRadius = 12;
      # Width of the accent bar down the left of the selected row; 0 drops it.
      markWidth = 3;
      # Thickness of the autoboot countdown rule.
      progressHeight = 4;
    };

    blur = {
      enable = false;
      size = 8;
      passes = 2;
      noise = 0.02;
      contrast = 1.0;
      brightness = 1.0;
      vibrancy = 0.17;
      vibrancyDarkness = 0.0;
    };

    shadow = {
      enable = false;
      range = 20;
      power = 3;
      offset = "0 0";
    };

    fonts = {
      mono = "CaskaydiaMono Nerd Font";
      sans = "Inter";
      size = 10;
      sizeSmall = 9;
    };

    cursor = {
      name = "Bibata-Modern-Ice";
      package = "bibata-cursors";
      size = 24;
    };

    animations = {
      enable = true;
      # Multiplier on every animation duration. Lower = snappier.
      speed = 1.0;
    };

    # Hyprland border gradient. A list of colours; a single entry is a flat
    # border, several make a gradient, and `borderAngle` animates it.
    borderGradient = null; # null → fall back to palette.border
    borderAngle = null; # non-null → animated rainbow border
  };

  # Every theme must define these. Enforced so a half-written theme fails at
  # eval time rather than rendering something unreadable at 2am.
  requiredPaletteKeys = [
    "base" # deepest background
    "surface" # raised background (panels, popups)
    "overlay" # further raised (menus, tooltips)
    "muted" # de-emphasised text / disabled
    "subtle" # secondary text
    "text" # primary foreground
    "accent" # primary accent
    "accentAlt" # secondary accent
    "border" # focused window border
    "borderInactive" # unfocused window border
    "red"
    "orange"
    "yellow"
    "green"
    "cyan"
    "blue"
    "magenta"
  ];

  # ── colour helpers ────────────────────────────────────────────────────────

  # "#RRGGBB" → "RRGGBB"
  stripHash = c: if lib.hasPrefix "#" c then lib.removePrefix "#" c else c;

  # "#RRGGBB" → "rgb(RRGGBB)"           (hyprland, opaque)
  toHyprRgb = c: "rgb(${stripHash c})";

  # "#RRGGBB" + 0.5 → "rgba(RRGGBBAA)"  (hyprland, with alpha)
  toHyprRgba =
    c: a:
    let
      v = builtins.floor (
        (
          if a > 1.0 then
            1.0
          else if a < 0.0 then
            0.0
          else
            a
        )
        * 255.0
        + 0.5
      );
      hexDigits = "0123456789abcdef";
      hi = builtins.substring (v / 16) 1 hexDigits;
      lo = builtins.substring (lib.mod v 16) 1 hexDigits;
    in
    "rgba(${stripHash c}${hi}${lo})";

  # "#RRGGBB" → { r = 122; g = 162; b = 247; }
  # For the handful of consumers that want channels rather than a hex string —
  # Plymouth's script language takes 0..1 floats, ImageMagick wants integers.
  hexToRgb =
    c:
    let
      h = lib.toLower (stripHash c);
      digits = {
        "0" = 0;
        "1" = 1;
        "2" = 2;
        "3" = 3;
        "4" = 4;
        "5" = 5;
        "6" = 6;
        "7" = 7;
        "8" = 8;
        "9" = 9;
        "a" = 10;
        "b" = 11;
        "c" = 12;
        "d" = 13;
        "e" = 14;
        "f" = 15;
      };
      pair =
        off:
        let
          hi = builtins.substring off 1 h;
          lo = builtins.substring (off + 1) 1 h;
        in
        if digits ? ${hi} && digits ? ${lo} then
          digits.${hi} * 16 + digits.${lo}
        else
          throw "hexToRgb: '${c}' is not a #RRGGBB colour";
    in
    if builtins.stringLength h != 6 then
      throw "hexToRgb: '${c}' is not a #RRGGBB colour"
    else
      {
        r = pair 0;
        g = pair 2;
        b = pair 4;
      };

  # 122 → "7a" — byte to 2-digit hex. Shared by rgbToHex.
  toHex2 =
    v:
    let
      hexDigits = "0123456789abcdef";
    in
    "${builtins.substring (v / 16) 1 hexDigits}${builtins.substring (lib.mod v 16) 1 hexDigits}";

  # { r = 255; g = 0; b = 0; } → "#ff0000"
  rgbToHex =
    {
      r,
      g,
      b,
    }:
    "#${toHex2 r}${toHex2 g}${toHex2 b}";

  # Linear-interpolate two hex colours: mix a b 0.0 = a, mix a b 1.0 = b.
  # For deriving muted/lightened variants of a palette colour (e.g. a diff
  # highlight) without hand-picking new hex values per theme.
  mix =
    a: b: t:
    let
      ca = hexToRgb a;
      cb = hexToRgb b;
      lerp = x: y: builtins.floor (x + (y - x) * t + 0.5);
    in
    rgbToHex {
      r = lerp ca.r cb.r;
      g = lerp ca.g cb.g;
      b = lerp ca.b cb.b;
    };

  # 0.75 → "bf" — for CSS/config formats that take 8-digit hex.
  alphaHex =
    a:
    let
      v = builtins.floor (
        (
          if a > 1.0 then
            1.0
          else if a < 0.0 then
            0.0
          else
            a
        )
        * 255.0
        + 0.5
      );
      hexDigits = "0123456789abcdef";
    in
    "${builtins.substring (v / 16) 1 hexDigits}${builtins.substring (lib.mod v 16) 1 hexDigits}";

in
rec {
  inherit
    defaultStyle
    requiredPaletteKeys
    stripHash
    toHyprRgb
    toHyprRgba
    alphaHex
    hexToRgb
    rgbToHex
    mix
    ;

  # ── GRUB menu geometry ────────────────────────────────────────────────────
  #
  # A theme states what the menu should *look* like (a 62px card with an 8px
  # gap and a 4px countdown rule). GRUB's gfxmenu does not take those numbers
  # directly, so they're translated here — once, because the theme.txt
  # generator and the derivation that cuts the pixmaps both need the result and
  # must agree on it exactly.
  #
  # Facts this encodes, all read out of grub-core/gfxmenu:
  #
  #  * gui_list.c draws a row as a styled box whose *content* height is
  #    `item_height`, then adds the box's pads — which for a 9-slice are the
  #    corner slices. It advances between rows by item_height + item_spacing.
  #    So neither theme.txt number is the card height or the visible gap.
  #  * The corner slice must be at least the corner radius, or the rounding is
  #    cut through and stretched.
  #  * gui_progress_bar.c's progress_bar_get_minimal_size hardcodes a 28px
  #    floor, and gui_canvas.c clamps every component up to its minimal size.
  #    So a thin rule cannot be the bar's height; it has to be drawn inside a
  #    28px slot whose remainder is transparent.
  grubGeometry =
    bootMenu:
    let
      corner = bootMenu.cornerRadius + 2;
      progressSlot = 28;
      progressPad = (progressSlot - bootMenu.progressHeight) / 2;
    in
    rec {
      inherit corner progressSlot progressPad;

      # The mode the bootloader pins, and which theme.txt's percentages and the
      # pixmaps' fixed pixel sizes are both authored against.
      screen = {
        width = 1920;
        height = 1080;
      };

      # gfxterm's window: where GRUB draws once a menu entry is chosen and the
      # kernel is loading. It cannot be hidden — view.c's get_min_terminal floors
      # it at 80x24 of the terminal font and re-centres anything smaller — so it
      # is placed instead, and the bootloader fills it with the slice of the
      # background lying underneath so that it reads as nothing at all.
      #
      # GRUB's default is 70% of the screen, centred, which straddles the
      # design's left-hand column and clips the generation cards in half the
      # moment an entry is chosen. This is the whole right-hand side instead:
      # clear of the column, tall enough and wide enough to stay above the
      # minimum, and the side of the wallpaper with nothing drawn on it.
      terminal = {
        x = screen.width * 45 / 100;
        y = 0;
        width = screen.width - screen.width * 45 / 100;
        height = screen.height;
      };

      # Width the row pixmaps are authored at. Only the middle slice stretches,
      # so this just has to exceed 2 * corner.
      cardWidth = 320;

      # card = itemHeight + 2 * corner  →  the theme's stated card height
      # gap  = itemSpacing - 2 * corner →  the theme's stated spacing
      itemHeight = bootMenu.itemHeight - 2 * corner;
      itemSpacing = bootMenu.itemSpacing + 2 * corner;

      # Integer division above can lose a pixel, so the rule's real thickness
      # is what's left rather than what was asked for.
      progressBand = progressSlot - 2 * progressPad;
    };

  # Build a theme from its definition, filling in defaults and validating.
  mkTheme =
    def:
    let
      missing = filter (k: !(def.palette ? ${k})) requiredPaletteKeys;

      theme = {
        name = def.name;
        # "dark" or "light" — drives GTK/Qt prefer-dark and DMS's mode.
        polarity = def.polarity or "dark";
        description = def.description or def.name;
        wallpaper = def.wallpaper or null;
        palette = def.palette;
        style = recursiveUpdate defaultStyle (def.style or { });
        apps = def.apps or { };
      };
    in
    if missing != [ ] then
      throw ''
        Theme "${def.name}" is missing required palette keys: ${concatStringsSep ", " missing}
        Every theme must define all of: ${concatStringsSep ", " requiredPaletteKeys}
      ''
    else
      theme;

  # An app's view of the theme: shared values, deep-merged with that app's
  # overrides. Apps absent from `theme.apps` get the shared values untouched.
  forApp =
    theme: app:
    recursiveUpdate {
      inherit (theme)
        name
        polarity
        palette
        style
        wallpaper
        ;
    } (theme.apps.${app} or { });

  # Load every *.nix in a directory as a theme.
  loadThemes =
    dir:
    let
      entries = builtins.readDir dir;
      themeFiles = filter (n: lib.hasSuffix ".nix" n && entries.${n} == "regular") (attrNames entries);
      mk = f: {
        name = lib.removeSuffix ".nix" f;
        value = mkTheme (import (dir + "/${f}"));
      };
    in
    builtins.listToAttrs (map mk themeFiles);
}
