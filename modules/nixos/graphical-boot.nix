{
  boot = {
    plymouth = {
      enable = true;
      theme = "spinner";
    };

    initrd.kernelModules = [
      "amdgpu"
    ];

    consoleLogLevel = 3;
    initrd.verbose = false;

    kernelParams = [
      "quiet"
      "udev.log_level=3"
      "rd.udev.log_level=3"
      "systemd.show_status=auto"
      "rd.systemd.show_status=auto"
    ];
  };
}
