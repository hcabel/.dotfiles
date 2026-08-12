{
  description = "hcabel's NixOS configuration — Hyprland + DankMaterialShell, keyboard-first and pretty";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

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
      nixos-hardware,
      sops-nix,
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
    in
    {
      nixosConfigurations.cyborg = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = { inherit inputs themeLib; };

        modules = [
          ./hosts/cyborg
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-bak";
              extraSpecialArgs = { inherit inputs themeLib; };
              users.hcabel = import ./home;
            };
          }
        ];
      };

      # Exposed so you can inspect a generated theme without a rebuild:
      #   nix build .#themes.glass && ls result/
      packages.${system} = {
        themes = import ./modules/home/theme/build.nix { inherit pkgs themeLib; };
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

      formatter.${system} = pkgs.nixfmt;
    };
}
