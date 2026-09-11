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
        hide_userland_threads = true;
        highlight_base_name = true;
        color_scheme = 6;
        sort_key = fields.TIME;
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
