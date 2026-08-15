{
  description = "hcabel's NixOS configuration — Hyprland + DankMaterialShell, keyboard-first and pretty";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # The theme engine is plain data + functions, usable outside a NixOS eval
      # so `nix eval` / tests can poke at it directly.
      themeLib = import ./lib/theme.nix { inherit (nixpkgs) lib; };

      builtThemes = import ./modules/home/theme/build.nix { inherit pkgs themeLib; };

      mkHost =
        extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system;

          specialArgs = { inherit inputs themeLib; };

          modules = [
            ./hosts/cyborg
            home-manager.nixosModules.home-manager
            # sops-nix's module is imported by modules/nixos/secrets.nix, which
            # keeps that module self-contained.
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-bak";
                extraSpecialArgs = { inherit themeLib; };
                users.hcabel = import ./home;
              };
            }
          ]
          ++ extraModules;
        };
    in
    {
      nixosConfigurations.cyborg = mkHost [ ];

      # Exposed so you can inspect a generated theme without a rebuild:
      #   nix build .#themes         && ls result/        — every theme
      #   nix build .#themes.glass   && ls result/        — just one
      #
      # `builtThemes.all` is the linkFarm holding every theme, and the
      # individual themes are merged onto it as attributes. That keeps both
      # commands above working while the output itself stays a derivation,
      # which is what `nix flake check` requires of everything under packages.
      packages.${system} = {
        themes = builtThemes.all // builtThemes;
        default = self.packages.${system}.themes;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixd
          nixfmt
          sops
          age
          ssh-to-age
        ];
      };

      # `nix fmt` invokes this with no arguments, and bare nixfmt then sits
      # reading stdin and fails on the empty input. Defaulting to the whole tree
      # is what makes the documented `nix fmt` actually format the repo.
      formatter.${system} = pkgs.writeShellScriptBin "nixfmt-tree" ''
        if [ $# -eq 0 ]; then set -- .; fi
        exec ${pkgs.fd}/bin/fd -e nix -t f --hidden --exclude .git -0 . "$@" \
          | xargs -0 -r ${pkgs.nixfmt}/bin/nixfmt
      '';
    };
}
