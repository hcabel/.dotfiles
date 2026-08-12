{ ... }:

{
  imports = [
    ./hardware.nix

    ../../modules/nixos/system.nix
    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/secrets.nix
  ];

  system.stateVersion = "26.05";
}
