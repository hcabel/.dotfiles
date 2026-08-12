{
  config,
  inputs,
  pkgs,
  ...
}:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    validateSopsFiles = false; # the file need not exist until you create one

    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };

    secrets."ssh_private_key" = {
      owner = "hcabel";
      path = "/home/hcabel/.ssh/id_ed25519";
      mode = "0600";
    };

    secrets."gpg_private_key" = {
      owner = "hcabel";
      mode = "0400";
    };
  };

  systemd.user.services.import-gpg-key = {
    description = "Import the sops-managed GPG private key";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.gnupg}/bin/gpg --batch --import ${config.sops.secrets."gpg_private_key".path}";
    };
  };

  environment.systemPackages = [ pkgs.gnupg ];

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
