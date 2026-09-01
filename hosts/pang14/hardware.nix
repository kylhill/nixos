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
}
