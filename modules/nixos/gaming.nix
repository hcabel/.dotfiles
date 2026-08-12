{ pkgs, ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    localNetworkGameTransfers.openFirewall = true;

    # gamescope as Steam's compositor fixes most Wayland fullscreen and
    # scaling problems, and lets you render below native and upscale — which
    # matters on a 4060 Laptop driving a 1440p external.
    gamescopeSession.enable = true;

    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true; # allows realtime priority
  };

  # MangoHUD overlay: enable per game with `mangohud %command%` in Steam's
  # launch options, or MANGOHUD=1 in the environment.
  environment.systemPackages = with pkgs; [
    mangohud
    protonup-qt # manage Proton-GE versions outside Nix if you want to
  ];

  # OBS on Wayland needs the pipewire capture path.
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-pipewire-audio-capture
      obs-vaapi
    ];
  };

  # Stream games from this machine to a Moonlight client.
  services.sunshine = {
    enable = true;
    openFirewall = true;
    capSysAdmin = true; # required for Wayland capture
  };

  # Steam's 32-bit stack and Proton both want a generous file descriptor
  # limit; the default trips some titles.
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "hard";
      item = "nofile";
      value = "524288";
    }
  ];

  # Shader compilation and Proton prefixes chew through /tmp.
  boot.tmp.cleanOnBoot = true;
}
