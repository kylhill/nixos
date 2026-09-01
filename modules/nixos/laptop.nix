{ lib, ... }:
{
  hardware = {
    bluetooth.enable = true;
    enableRedistributableFirmware = true;
    graphics.enable = true;
  };

  services = {
    fwupd.enable = true;
    printing.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    logind.settings.Login = {
      HandleLidSwitch = "suspend-then-hibernate";
      HandleLidSwitchExternalPower = "suspend-then-hibernate";
      HandleLidSwitchDocked = "ignore";
    };

    # The System76 power daemon is enabled by the generic hardware module.
    power-profiles-daemon.enable = lib.mkForce false;
    system76-scheduler.enable = true;
  };

  powerManagement.powertop.enable = true;

  systemd.sleep.settings.Sleep = {
    AllowHibernation = "yes";
    AllowSuspendThenHibernate = "yes";
    HibernateDelaySec = "2h";
  };
}
