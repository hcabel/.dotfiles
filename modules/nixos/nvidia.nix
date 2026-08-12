{
  config,
  lib,
  pkgs,
  ...
}:

# MSI Cyborg 15 A13VFK — Intel Raptor Lake iGPU + RTX 4060 Laptop (AD107M).
#
# Verified on this machine: HDMI-A-1 and eDP-1 hang off the Intel GPU, only
# DP-1 is wired to the NVIDIA card. So in offload mode the laptop panel and
# an external HDMI monitor both work with the dGPU fully asleep — which makes
# offload the right default rather than a compromise.
#
# Two modes ship in the boot menu:
#   default          — PRIME offload. Intel drives everything, dGPU powered
#                      down until a program is explicitly offloaded onto it.
#   nvidia-sync      — PRIME sync. The 4060 renders everything. Worse battery
#                      and louder, but maximum performance and it lights up
#                      DP-1.

let
  # PCI addresses. `lspci` reports these as 00:02.0 and 01:00.0 on this
  # chassis; NixOS wants them in this decimal-ish form.
  intelBusId = "PCI:0:2:0";
  nvidiaBusId = "PCI:1:0:0";

  # Run a single program on the dGPU while the desktop stays on Intel:
  #   nvidia-offload glxinfo | grep vendor
  #   nvidia-offload steam
  nvidia-offload = pkgs.writeShellScriptBin "nvidia-offload" ''
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    export VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json
    exec "$@"
  '';
in
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true; # required for Steam / Proton
    extraPackages = with pkgs; [
      intel-media-driver # VA-API on Raptor Lake
      vpl-gpu-rt # QuickSync
      nvidia-vaapi-driver
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [ intel-media-driver ];
  };

  hardware.nvidia = {
    # Ada is Turing+, so the open kernel modules are the supported path and
    # get the better Wayland fixes.
    open = true;

    # Explicit sync landed in 555 and is what makes Wayland on NVIDIA stop
    # flickering and stuttering. Stay on a recent driver.
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    modesetting.enable = true; # mandatory for Wayland
    nvidiaSettings = true;

    # Lets the dGPU actually power down when nothing is offloaded onto it.
    # This is where the battery saving comes from.
    powerManagement.enable = true;
    powerManagement.finegrained = true;

    prime = {
      inherit intelBusId nvidiaBusId;
      offload = {
        enable = true;
        enableOffloadCmd = true; # provides `nvidia-offload` too
      };
    };
  };

  environment.systemPackages = [
    nvidia-offload
    pkgs.nvtopPackages.full
  ];

  # ── gaming boot entry ──────────────────────────────────────────────────────
  # Same closure, different GPU wiring. Pick it from the boot menu when you
  # want maximum performance or need DP-1.
  specialisation.nvidia-sync.configuration = {
    system.nixos.tags = [ "nvidia-sync" ];

    hardware.nvidia = {
      prime = {
        offload.enable = lib.mkForce false;
        offload.enableOffloadCmd = lib.mkForce false;
        sync.enable = lib.mkForce true;
      };
      # Fine-grained power management is meaningless when the dGPU must stay
      # awake to drive the display.
      powerManagement.finegrained = lib.mkForce false;
    };
  };
}
