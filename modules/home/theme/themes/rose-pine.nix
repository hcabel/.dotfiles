# Rose Pine — the palette your fish prompt has quietly been using all along.
# Soft, low-contrast, minimal blur; the calm counterpart to glass.
{
  name = "rose-pine";
  description = "Rose Pine — soft muted pastels, gentle contrast";
  polarity = "dark";

  palette = {
    base = "#191724";
    surface = "#1f1d2e";
    overlay = "#26233a";
    muted = "#6e6a86";
    subtle = "#908caa";
    text = "#e0def4";

    accent = "#c4a7e7"; # iris
    accentAlt = "#ebbcba"; # rose

    border = "#c4a7e7";
    borderInactive = "#26233a";

    red = "#eb6f92"; # love
    orange = "#f6c177"; # gold
    yellow = "#f6c177";
    green = "#31748f"; # pine
    cyan = "#9ccfd8"; # foam
    blue = "#9ccfd8";
    magenta = "#c4a7e7";
  };

  style = {
    rounding = 8;
    borderSize = 2;

    gaps = {
      inner = 4;
      outer = 8;
    };

    opacity = {
      active = 1.0;
      inactive = 0.92;
      fullscreen = 1.0;
      terminal = 0.94;
      panel = 0.96;
    };

    blur = {
      enable = true;
      size = 6;
      passes = 2;
      noise = 0.01;
      contrast = 1.0;
      brightness = 1.0;
      vibrancy = 0.1;
    };

    shadow.enable = false;

    fonts = {
      mono = "CaskaydiaMono Nerd Font";
      sans = "Inter";
      size = 10;
      sizeSmall = 9;
    };

    animations.speed = 1.1;
  };

  apps = {
    # A flat two-stop gradient rather than glass's rotating rainbow.
    hyprland.style.borderGradient = [
      "#c4a7e7"
      "#ebbcba"
    ];
  };
}
