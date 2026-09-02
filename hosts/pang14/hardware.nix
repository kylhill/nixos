{ config, lib, ... }:
{
  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "sd_mod"
      "usb_storage"
      "xhci_pci"
    ];
    kernelModules = [ "kvm-amd" ];
  };

  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  services = {
    # nixos-hardware's System76 module enables system76-power. Do not run the
    # overlapping GNOME power-profiles daemon alongside it.
    power-profiles-daemon.enable = lib.mkForce false;
    system76-scheduler.enable = true;
  };
}
