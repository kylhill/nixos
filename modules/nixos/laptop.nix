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

  networking.networkmanager.connectionConfig = {
    "ethernet.wake-on-lan" = 0;
    "wifi.wake-on-wlan" = 0;
  };

  powerManagement.powertop.enable = true;
}
