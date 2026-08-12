# Everforest — the palette your kitty config has used for years, promoted to a
# full desktop theme. Warm, green, opaque; the "no distractions" option.
{
  name = "everforest";
  description = "Everforest — warm forest greens, comfortable and opaque";
  polarity = "dark";

  palette = {
    base = "#2d353b";
    surface = "#343f44";
    overlay = "#3d484d";
    muted = "#859289";
    subtle = "#9da9a0";
    text = "#d3c6aa";

    accent = "#a7c080"; # green
    accentAlt = "#dbbc7f"; # yellow

    border = "#a7c080";
    borderInactive = "#475258";

    red = "#e67e80";
    orange = "#e69875";
    yellow = "#dbbc7f";
    green = "#a7c080";
    cyan = "#83c092";
    blue = "#7fbbb3";
    magenta = "#d699b6";
  };

  style = {
    rounding = 6;
    borderSize = 2;

    gaps = {
      inner = 4;
      outer = 6;
    };

    opacity = {
      active = 1.0;
      inactive = 0.95;
      fullscreen = 1.0;
      terminal = 1.0;
      panel = 1.0;
    };

    blur.enable = false;
    shadow.enable = false;

    fonts = {
      mono = "CaskaydiaMono Nerd Font";
      sans = "Inter";
      size = 10;
      sizeSmall = 9;
    };

    # Snappiest of the set — nothing translucent to fade, so animations can
    # afford to be quick.
    animations.speed = 1.3;
  };

  apps = { };
}
