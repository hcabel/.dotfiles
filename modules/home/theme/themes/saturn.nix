# Saturn — the design-doc theme. Deep violet glass over the saturn-rings
# photograph, with a blue → purple → pink accent ramp. This is the one theme
# that ships its own image rather than a palette-generated gradient, because
# the whole look is built around that specific wallpaper: the bar is tinted
# toward the sky in it, and the boot and login screens use it too.
{
  name = "saturn";
  description = "Saturn — violet glass over the rings, blue-to-pink accents";
  polarity = "dark";

  wallpaper = ../wallpapers/saturn-rings.jpg;

  palette = {
    base = "#05070a"; # the backdrop the boot and login screens fade to
    surface = "#18162c"; # the glass tint — bar, popups, cards
    overlay = "#241f38";
    muted = "#565a7a";
    subtle = "#a9b4d6";
    text = "#ffffff";

    accent = "#7aa2f7"; # the blue that starts every gradient
    accentAlt = "#f28fad"; # the pink that ends it

    border = "#7aa2f7";
    borderInactive = "#1e1b33";

    red = "#f7768e";
    orange = "#ff9e64";
    yellow = "#e0af68";
    green = "#7bd88f";
    cyan = "#7dd3c0"; # the teal the login screen uses for live values
    blue = "#7aa2f7";
    magenta = "#a78bfa"; # the purple in the middle of the ramp
  };

  style = {
    rounding = 14;
    borderSize = 2;

    gaps = {
      inner = 5;
      outer = 10;
    };

    opacity = {
      active = 0.95;
      inactive = 0.82;
      fullscreen = 1.0;
      terminal = 0.62;
      # The bar's dropdowns. Denser than the bar itself so text over a busy
      # part of the wallpaper stays readable.
      panel = 0.62;
    };

    bar = {
      height = 44;
      # Flush to the top edge, so the fillets below have something to curve
      # away from.
      edgeGap = 0;
      widgetPadding = 12;

      # 18px fillets, and goth corners on — this is the effect the design is
      # built around, where a dropdown's shoulders curve back up into the bar
      # instead of leaving a hard step at the screen edge.
      cornerRadius = 18;
      gothCorners = true;

      transparency = 0.50;
      widgetTransparency = 0.12;
    };

    # The design's generation rows: 62px tall cards, 14px corners, with the
    # accent ramp running down the left edge of the selected one.
    bootMenu = {
      itemHeight = 62;
      itemSpacing = 8;
      itemPadding = 0;
      cornerRadius = 14;
      markWidth = 3;
      progressHeight = 4;
    };

    blur = {
      enable = true;
      size = 12;
      passes = 4;
      noise = 0.02;
      contrast = 1.05;
      brightness = 0.9;
      # High vibrancy is what lets the wallpaper's own colour bleed through
      # the glass rather than the bar reading as a grey slab laid on top.
      vibrancy = 0.30;
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

    # The accent ramp, rotating. Same three stops the design uses for every
    # gradient it draws.
    borderGradient = [
      "#7aa2f7"
      "#a78bfa"
      "#f28fad"
    ];
    borderAngle = 45;
  };

  # ── per-app deviations ──────────────────────────────────────────────────────
  apps = {
    # The terminal sits on near-black so the glass reads as depth rather than
    # as a grey wash over the wallpaper.
    ghostty = {
      palette.base = "#04050a";
      style.opacity.terminal = 0.58;
    };

    # Keyboard pointer labels must stay readable over arbitrary window
    # content, and the theme's own blue-on-violet is not enough contrast for
    # that. Readability wins over palette purity here.
    wl-kbptr = {
      palette.text = "#ffe600";
      palette.accent = "#ff7a00";
    };
  };
}
