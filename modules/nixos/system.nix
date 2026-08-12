{
  config,
  lib,
  pkgs,
  ...
}:

{
  # ── boot ───────────────────────────────────────────────────────────────────
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        # Keep the boot menu readable — one entry per generation adds up fast
        # once you're rebuilding several times a day.
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };

    # Raptor Lake and the 4060 both want a recent kernel.
    kernelPackages = pkgs.linuxPackages_latest;

    kernelParams = [
      "quiet"
      "splash"
      # Keeps the dGPU's video memory across suspend, which is what stops the
      # "black screen after resume" failure on NVIDIA laptops.
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    ];

    plymouth.enable = true;
  };

  # 16 GB with no swap is tight once a game and a browser are both open.
  # zram is compressed RAM rather than disk, so it costs no SSD writes and is
  # far faster than a swapfile. Hibernation is given up in exchange.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # ── networking ─────────────────────────────────────────────────────────────
  networking = {
    hostName = "cyborg";
    networkmanager = {
      enable = true;
      wifi.backend = "iwd"; # you were already using iwd on Fedora
    };
    firewall.enable = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true; # battery reporting for headsets
  };

  # ── audio ──────────────────────────────────────────────────────────────────
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = false;
  };

  # ── power ──────────────────────────────────────────────────────────────────
  services.power-profiles-daemon.enable = true; # DMS's power widget drives this
  services.thermald.enable = true; # Intel thermal management
  services.upower.enable = true;

  # Lid handling: hyprland/hypridle owns the response while a session is
  # active, so logind must not also act on it.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandlePowerKey = "ignore";
  };

  # ── locale ─────────────────────────────────────────────────────────────────
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_FR.UTF-8";
    LC_IDENTIFICATION = "fr_FR.UTF-8";
    LC_MEASUREMENT = "fr_FR.UTF-8";
    LC_MONETARY = "fr_FR.UTF-8";
    LC_NAME = "fr_FR.UTF-8";
    LC_NUMERIC = "fr_FR.UTF-8";
    LC_PAPER = "fr_FR.UTF-8";
    LC_TELEPHONE = "fr_FR.UTF-8";
    LC_TIME = "fr_FR.UTF-8";
  };
  console.keyMap = "us";

  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true; # network printer discovery
  };

  # ── fonts ──────────────────────────────────────────────────────────────────
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      # Your terminal font, now from nixpkgs instead of 40 committed .ttf files.
      nerd-fonts.caskaydia-mono
      nerd-fonts.symbols-only
      inter
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      material-symbols
    ];

    fontconfig.defaultFonts = {
      monospace = [ "CaskaydiaMono Nerd Font" ];
      sansSerif = [ "Inter" ];
      serif = [ "Noto Serif" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  # ── nix ────────────────────────────────────────────────────────────────────
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "hcabel"
      ];
      auto-optimise-store = true;

      substituters = [
        "https://cache.nixos.org"
        "https://hyprland.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
    };

    # Garbage collection is handled by programs.nh.clean below, which is
    # generation-aware — enabling nix.gc.automatic as well would have the two
    # fighting over the same store paths.
  };

  nixpkgs.config.allowUnfree = true;

  # ── users ──────────────────────────────────────────────────────────────────
  programs.fish.enable = true;

  users.users.hcabel = {
    isNormalUser = true;
    description = "Hugo Cabel";
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "i2c" # external monitor brightness over DDC
    ];
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    pciutils # lspci — absent on the stock install, and you'll want it
    usbutils
    file
    unzip
    claude-code
  ];

  # `nh os switch` is a nicer front end than nixos-rebuild: it shows a diff of
  # what changed and cleans up after itself.
  programs.nh = {
    enable = true;
    flake = "/home/hcabel/.dotfiles";
    clean = {
      enable = true;
      extraArgs = "--keep-since 21d --keep 5";
    };
  };
}
