{ pkgs, contrailPkgs }: { config, lib, ... }:

{

  imports = [
    (pkgs.path + /nixos/modules/installer/cd-dvd/channel.nix)
    (pkgs.path + /nixos/modules/profiles/qemu-guest.nix)
    ./modules/all-in-one.nix
  ];

  config = {
    # include pkgs to have access to tools overlay
    _module.args = { inherit pkgs contrailPkgs; };

    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      autoResize = true;
    };

    boot.growPartition = true;
    boot.kernelParams = [ "console=ttyS0" ];
    boot.loader.grub.device = "/dev/vda";
    boot.loader.timeout = 0;

    system.build.qcow = import (pkgs.path + /nixos/lib/make-disk-image.nix) {
      inherit lib config pkgs;
      diskSize = 4096;
      format = "qcow2";
    };

    environment.systemPackages = with pkgs; [
      # Used by the test suite
      jq
      contrailApiCliWithExtra
      contrailPkgs.configUtils
    ];

    contrail.allInOne = {
      enable = true;
      vhostInterface = "eth0";
    };
  };
}
