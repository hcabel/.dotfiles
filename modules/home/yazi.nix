{ config, pkgs, ... }:

let
  themeDir = "${config.xdg.stateHome}/theme/current";
in
{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;

    keymap = {
      mgr.prepend_keymap = [
        {
          on = [ "T" ];
          run = ''shell --confirm "ghostty --working-directory=$PWD"'';
          desc = "Open a new terminal here";
        }
      ];
    };

    settings = {
      mgr = {
        show_hidden = false;
        sort_by = "natural";
        sort_dir_first = true;
      };
      preview = {
        max_width = 1000;
        max_height = 1000;
      };
    };
  };

  # Theme file follows the active theme rather than being baked in.
  xdg.configFile."yazi/theme.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${themeDir}/yazi.toml";

  home.packages = with pkgs; [
    ffmpegthumbnailer # video thumbnails
    poppler-utils # pdf previews
    imagemagick # image previews
    p7zip # archive previews
  ];
}
