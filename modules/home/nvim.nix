{
  config,
  lib,
  pkgs,
  ...
}:

# Your Neovim config lives in its own repo (github:hcabel/neovim-config) and
# stays there — Nix installs the editor and its toolchain, but does not try to
# own the Lua. The theme is exposed as a Lua table the config can require.

let
  themeDir = config.hcabel.theme.currentDir;
  nvimConfigDir = "${config.xdg.configHome}/nvim";
  nvimConfigRepo = "https://github.com/hcabel/neovim-config.git";
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Without this, home-manager still writes ~/.config/nvim/init.lua itself
    # (a couple of `vim.g.loaded_*_provider=0` lines from withNodeJs/withPython3
    # etc, even with no plugins configured) — which collides with your actual
    # init.lua and gets it backed up out from under you. sideloadInitLua feeds
    # that same content in as a `--cmd` wrapper flag instead of a file, so your
    # config directory is never touched.
    sideloadInitLua = true;

    # Language servers and tooling your config expects to find on PATH.
    extraPackages = with pkgs; [
      # nix
      nixd
      nixfmt
      # rust
      rust-analyzer
      # lua
      lua-language-server
      stylua
      # go
      gopls
      gotools
      # web
      typescript-language-server
      vscode-langservers-extracted
      # c/c++
      clang-tools
      gcc # nvim-treesitter needs a real C compiler to build parsers
      # general
      tree-sitter
      ripgrep
      fd
    ];
  };

  # Palette bridge: your nvim config can pick the desktop theme up with
  #   local theme = dofile(vim.fn.expand("~/.local/state/theme/current/nvim.lua"))
  # A convenience symlink keeps that path stable and short.
  xdg.configFile."nvim/theme.lua".source = config.lib.file.mkOutOfStoreSymlink "${themeDir}/nvim.lua";

  home.sessionVariables.EDITOR = "nvim";

  home.packages = with pkgs; [
    rustc
    cargo
    go
    nodejs
  ];

  # Bootstrap only — clones your config on a machine that doesn't have it yet.
  # Never touches it again once the directory exists, so local edits and your
  # own git remote (switch it to SSH yourself if you want push access) are
  # left alone on every subsequent rebuild. Must run *before* writeBoundary:
  # home-manager's own file linking (which creates theme.lua under this same
  # directory) runs right after writeBoundary and would `mkdir -p` the
  # directory into existence first, making the "does it exist yet" check
  # below always true.
  home.activation.cloneNvimConfig = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    if [ ! -e "${nvimConfigDir}" ] && [ ! -L "${nvimConfigDir}" ]; then
      run ${pkgs.git}/bin/git clone ${nvimConfigRepo} "${nvimConfigDir}"
    fi
  '';
}
