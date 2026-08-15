{
  config,
  pkgs,
  themeLib,
  ...
}:

# The NixOS side of the theme engine.
#
# bootloader.nix, plymouth.nix and login.nix all need the same three values, and
# all three used to derive them independently — which meant reaching across the
# NixOS↔home-manager boundary three times and evaluating the whole theme build
# three times over. They are computed once here and handed out as module args.
#
# `hcabel.theme.default` is the single source of truth for which theme the
# pre-session screens commit to. They cannot follow the runtime `current`
# symlink: the splash is baked into the initrd and the greeter runs before any
# theme has been switched, so both fix a theme at build time and a rebuild is
# what re-themes them.

let
  themeName = config.home-manager.users.hcabel.hcabel.theme.default;
in
{
  _module.args = {
    inherit themeName;

    # Plain data — palette and style are readable without building anything.
    themeData = (themeLib.loadThemes ../home/theme/themes).${themeName};

    # The realised theme directory, for the consumers that need the wallpaper,
    # the monogram or a generated config file.
    builtTheme = (import ../home/theme/build.nix { inherit pkgs themeLib; }).${themeName};
  };
}
