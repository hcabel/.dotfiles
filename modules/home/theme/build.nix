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
      theme.wallpaper
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
        "hyprlock.conf" = generators.hyprlock theme;
        "ghostty.conf" = generators.ghostty theme;
        "dms.json" = generators.dms theme;
        "fish.fish" = generators.fish theme;
        "lazygit.json" = generators.lazygit theme;
        "yazi.toml" = generators.yazi theme;
        "wl-kbptr.conf" = generators.wl-kbptr theme;
        "nvim.lua" = generators.nvim theme;
        "bat.conf" = generators.bat theme;
        "delta.conf" = generators.delta theme;
        "gtk.css" = generators.gtk theme;
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
  all = pkgs.linkFarm "themes" (lib.mapAttrsToList (name: drv: { inherit name; path = drv; }) built);

  names = lib.attrNames built;
}
