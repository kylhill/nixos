{ config, ... }:
{
  programs.htop = {
    enable = true;
    settings =
      with config.lib.htop;
      {
        fields = with fields; [
          PID
          USER
          PRIORITY
          NICE
          M_VIRT
          M_RESIDENT
          M_PRIV
          STATE
          PERCENT_CPU
          PERCENT_MEM
          TIME
          COMM
        ];
        hide_kernel_threads = true;
        hide_userland_threads = true;
        highlight_base_name = true;
        highlight_deleted_exe = true;
        highlight_megabytes = true;
        highlight_threads = true;
        find_comm_in_cmdline = true;
        strip_exe_from_cmdline = true;
        color_scheme = 6;
        delay = 15;
        header_layout = "two_50_50";
        sort_key = fields.TIME;
        sort_direction = -1;
      }
      // leftMeters [
        (bar "LeftCPUs2")
        (bar "Memory")
        (bar "Swap")
      ]
      // rightMeters [
        (bar "RightCPUs2")
        (text "Tasks")
        (text "LoadAverage")
        (text "Uptime")
      ];
  };
}
