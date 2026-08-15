{ pkgs, themeLib }:

# Builds every curated theme into the store as a self-contained directory of
# generated config. Switching themes at runtime is then just repointing a
# symlink at one of these — no rebuild, and nothing hand-written anywhere.

let
  inherit (pkgs) lib;

  generators = import ./generators.nix { inherit lib themeLib; };

  themes = themeLib.loadThemes ./themes;

  # A theme without its own image gets a gradient generated from its palette,
  # so every theme always ships a matching wallpaper and the repo stays free
  # of binary blobs.
  mkWallpaper =
    theme:
    let
      p = theme.palette;
    in
    if theme.wallpaper != null then
      # A supplied image is normalised rather than copied, so every theme's
      # wallpaper.jpg has the same shape regardless of what the source was.
      #
      # -interlace none is the point. The saturn source is a progressive JPEG,
      # and progressive scans defeat libjpeg's DCT-scaled decoding — which is
      # exactly what QML's sourceSize relies on to decode a 4K image cheaply.
      # The greeter is where that decode sits on the critical path between the
      # splash going away and the login screen appearing, so it is worth
      # spending build time to make every read of this file fast.
      #
      # Resolution is left alone: the desktop wallpaper may well be shown on a
      # 4K panel, and downscaling here to help the greeter would be paying for
      # one consumer with every other one.
      pkgs.runCommand "wallpaper-${theme.name}.jpg"
        {
          nativeBuildInputs = [ pkgs.imagemagick ];
        }
        ''
          magick ${theme.wallpaper} -interlace none -quality 92 JPEG:"$out"
        ''
    else
      pkgs.runCommand "wallpaper-${theme.name}.jpg"
        {
          nativeBuildInputs = [ pkgs.imagemagick ];
        }
        ''
          magick -size 2560x1440 \
            radial-gradient:'${p.surface}'-'${p.base}' \
            -modulate 100,110 \
            \( -size 2560x1440 gradient:'${p.accent}'-'${p.base}' \) \
            -compose overlay -composite \
            -attenuate 0.25 +noise Gaussian \
            -quality 88 JPEG:"$out"
        '';

  mkTheme =
    theme:
    let
      files = {
        "hyprland.conf" = generators.hyprland theme;
        "ghostty.conf" = generators.ghostty theme;
        "dms.json" = generators.dms theme;
        "dms-settings.json" = generators.dmsSettings theme;
        "fish.fish" = generators.fish theme;
        "lazygit.json" = generators.lazygit theme;
        "yazi.toml" = generators.yazi theme;
        "wl-kbptr.conf" = generators.wl-kbptr theme;
        "nvim.lua" = generators.nvim theme;
        "delta.conf" = generators.delta theme;
        "grub-theme.txt" = generators.grub theme;
        "login-theme.json" = generators.loginTheme theme;
        "logo.svg" = generators.logo theme;
        "meta.json" = generators.meta theme;
      };

      writeAll = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          fname: content: ''cp ${pkgs.writeText "${theme.name}-${fname}" content} "$out/${fname}"''
        ) files
      );
    in
    pkgs.runCommand "theme-${theme.name}" { passthru = { inherit theme; }; } ''
      mkdir -p "$out"
      ${writeAll}
      cp ${mkWallpaper theme} "$out/wallpaper.jpg"
    '';

  built = lib.mapAttrs (_: mkTheme) themes;

in
built
// {
  # All themes under one root, so the switcher can see them as siblings:
  #   ~/.local/state/theme/all/<name>/
  all = pkgs.linkFarm "themes" (
    lib.mapAttrsToList (name: drv: {
      inherit name;
      path = drv;
    }) built
  );

  names = lib.attrNames built;
}
