{
  boot = {
    plymouth = {
      enable = true;
      theme = "bgrt";
    };

    consoleLogLevel = 3;
    initrd.verbose = false;

    kernelParams = [
      "quiet"
      "udev.log_priority=3"
      "systemd.show_status=auto"
      "rd.systemd.show_status=auto"
    ];
  };
}
