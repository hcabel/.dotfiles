{ ... }:

{
  imports = [
    ./hardware.nix

    ../../modules/nixos/system.nix
    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/theme.nix
    ../../modules/nixos/bootloader.nix
    ../../modules/nixos/plymouth.nix
    ../../modules/nixos/login.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/secrets.nix
  ];

  system.stateVersion = "26.05";
}
