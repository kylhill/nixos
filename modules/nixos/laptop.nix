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

  # system76-power already manages the laptop's power policy. Keep Powertop's
  # blanket auto-tuning disabled unless later testing shows a clear benefit
  # without introducing device or suspend regressions.
  powerManagement.powertop.enable = false;
}
