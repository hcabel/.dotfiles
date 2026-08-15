# Glass — the default. Deep translucent dark, heavy blur, cyan/amber accents,
# and the animated rainbow border carried over from RainbowBorders.sh.
{
  name = "glass";
  description = "Glassmorphism — translucent surfaces, heavy blur, rainbow borders";
  polarity = "dark";

  palette = {
    base = "#05070d";
    surface = "#0a1830";
    overlay = "#132445";
    muted = "#4d5b78";
    subtle = "#8b9ab8";
    text = "#e8eefc";

    accent = "#00e5ff"; # the cyan from your wl-kbptr labels
    accentAlt = "#ffe600"; # the amber from your wl-kbptr labels

    border = "#00e5ff";
    borderInactive = "#1b2a4a";

    red = "#ff5d62";
    orange = "#ff7a00";
    yellow = "#ffe600";
    green = "#7bd88f";
    cyan = "#00e5ff";
    blue = "#5aa2ff";
    magenta = "#c678dd";
  };

  style = {
    rounding = 14;
    borderSize = 2;

    gaps = {
      inner = 5;
      outer = 10;
    };

    opacity = {
      active = 0.92;
      inactive = 0.78;
      fullscreen = 1.0;
      terminal = 0.62;
      panel = 0.72;
    };

    blur = {
      enable = true;
      size = 14;
      passes = 4;
      noise = 0.02;
      contrast = 1.05;
      brightness = 0.9;
      vibrancy = 0.25;
      vibrancyDarkness = 0.15;
    };

    shadow = {
      enable = true;
      range = 24;
      power = 3;
      offset = "0 4";
    };

    fonts = {
      mono = "CaskaydiaMono Nerd Font";
      sans = "Inter";
      size = 10;
      sizeSmall = 9;
    };

    # Your RainbowBorders.sh, but declarative: a rotating multi-stop gradient.
    borderGradient = [
      "#00e5ff"
      "#5aa2ff"
      "#c678dd"
      "#ff7a00"
      "#ffe600"
    ];
    borderAngle = 45;
  };

  # ── per-app deviations ────────────────────────────────────────────────────
  apps = {
    # The terminal is the surface where glass reads best, so it goes further
    # than the shared value and sits on the true black base.
    ghostty = {
      palette.base = "#00030a";
      style.opacity.terminal = 0.55;
    };

    # The shell's own chrome wants to be more legible than a window: less
    # transparent, and lifted off the desktop background.
    dms = {
      palette.surface = "#0b1b36";
      style.opacity.panel = 0.80;
    };

    # Keyboard pointer labels must stay maximally readable over any content,
    # so they opt out of the palette's softer foreground entirely.
    wl-kbptr = {
      palette.text = "#ffe600";
      palette.accent = "#ff7a00";
    };
  };
}
