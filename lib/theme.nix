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
      v = builtins.floor ((if a > 1.0 then 1.0 else if a < 0.0 then 0.0 else a) * 255.0 + 0.5);
      hexDigits = "0123456789abcdef";
      hi = builtins.substring (v / 16) 1 hexDigits;
      lo = builtins.substring (lib.mod v 16) 1 hexDigits;
    in
    "rgba(${stripHash c}${hi}${lo})";

  # 0.75 → "bf" — for CSS/config formats that take 8-digit hex.
  alphaHex =
    a:
    let
      v = builtins.floor ((if a > 1.0 then 1.0 else if a < 0.0 then 0.0 else a) * 255.0 + 0.5);
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
    ;

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
