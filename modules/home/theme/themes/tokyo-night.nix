# Tokyo Night — high-contrast neon on deep navy. The "late night coding" option.
{
  name = "tokyo-night";
  description = "Tokyo Night — deep navy with neon blue and purple";
  polarity = "dark";

  palette = {
    base = "#1a1b26";
    surface = "#24283b";
    overlay = "#2f334d";
    muted = "#565f89";
    subtle = "#a9b1d6";
    text = "#c0caf5";

    accent = "#7aa2f7";
    accentAlt = "#bb9af7";

    border = "#7aa2f7";
    borderInactive = "#292e42";

    red = "#f7768e";
    orange = "#ff9e64";
    yellow = "#e0af68";
    green = "#9ece6a";
    cyan = "#7dcfff";
    blue = "#7aa2f7";
    magenta = "#bb9af7";
  };

  style = {
    rounding = 10;
    borderSize = 2;

    gaps = {
      inner = 4;
      outer = 8;
    };

    opacity = {
      active = 1.0;
      inactive = 0.88;
      fullscreen = 1.0;
      terminal = 0.85;
      panel = 0.9;
    };

    blur = {
      enable = true;
      size = 8;
      passes = 3;
      noise = 0.015;
      vibrancy = 0.17;
    };

    shadow = {
      enable = true;
      range = 16;
      power = 2;
      offset = "0 2";
    };

    fonts = {
      mono = "CaskaydiaMono Nerd Font";
      sans = "Inter";
      size = 10;
      sizeSmall = 9;
    };

    borderGradient = [
      "#7aa2f7"
      "#bb9af7"
    ];
  };

  apps = {
    ghostty.style.opacity.terminal = 0.8;
  };
}
