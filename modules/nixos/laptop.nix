_: {
  hardware = {
    bluetooth.enable = true;
    enableRedistributableFirmware = true;
    graphics.enable = true;
  };

  services = {
    fwupd.enable = true;

    logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "ignore";
    };
  };
}
