{ pkgs, ... }:
let
  # Solarized dark color palette
  colors = {
    base03 = "#002b36";
    base02 = "#073642";
    base01 = "#586e75";
    base00 = "#657b83";
    base0 = "#839496";
    base1 = "#93a1a1";
    base2 = "#eee8d5";
    base3 = "#fdf6e3";
    yellow = "#b58900";
    orange = "#cb4b16";
    red = "#dc322f";
    magenta = "#d33682";
    violet = "#6c71c4";
    blue = "#268bd2";
    cyan = "#2aa198";
    green = "#859900";
  };
in
{
  # tmux-cpu uses iostat for sampled CPU usage and free for RAM usage.
  home.packages = with pkgs; [
    coreutils
    gawk
    gnused
    procps
    sysstat
  ];

  programs.tmux = {
    enable = true;
    baseIndex = 1;
    escapeTime = 0;
    focusEvents = true;
    historyLimit = 50000;
    keyMode = "vi";
    customPaneNavigationAndResize = true;
    resizeAmount = 10;
    prefix = "C-a";
    terminal = "tmux-256color";

    plugins = [
      pkgs.tmuxPlugins.vim-tmux-navigator
      {
        plugin = pkgs.tmuxPlugins.cpu;
        extraConfig = ''
          set -g @cpu_percentage_format "%3.1f%%"
          set -g @ram_percentage_format "%3.1f%%"

          set -g status-interval 5
          set -g status-left-length 100
          set -g status-right-length 100
          set -g status-style "bg=${colors.base01},fg=${colors.base1}"
          set -g pane-border-style "fg=${colors.base01}"
          set -g pane-active-border-style "fg=${colors.blue}"
          set -g message-style "bg=${colors.base01},fg=${colors.base1}"

          set -g status-left "#[bg=${colors.green},fg=${colors.base03}]#{?client_prefix,#[bg=${colors.yellow}],} 󱄅 #[fg=${colors.green},bg=${colors.base01}]#{?client_prefix,#[fg=${colors.yellow}],}"
          set -g status-right " #[fg=${colors.blue},bg=${colors.base01},nobold,nounderscore,noitalics]#[fg=${colors.base03},bg=${colors.blue}]  #{cpu_percentage}  #[fg=${colors.green},bg=${colors.blue},nobold,nounderscore,noitalics]#[fg=${colors.base03},bg=${colors.green}]  #{ram_percentage} "

          setw -g window-status-style "fg=${colors.base1},bg=${colors.base01}"
          setw -g window-status-current-style "fg=${colors.base1},bg=${colors.base02}"
          setw -g window-status-format "#[fg=${colors.base1},bg=${colors.base01}] #I #W"
          setw -g window-status-current-format "#[fg=${colors.base01},bg=${colors.base02}]#[fg=${colors.base1},bg=${colors.base02}] #I #W #[fg=${colors.base02},bg=${colors.base01}]"
          setw -g window-status-activity-style "bold"
          setw -g window-status-bell-style "bold"
        '';
      }
    ];

    extraConfig = ''
      set -as terminal-features ',xterm-256color:RGB'
      set -ag update-environment WAYLAND_DISPLAY

      set -s extended-keys on
      set -g set-clipboard on
      set -g set-titles on
      set -g set-titles-string "#{user}@#h: #W"
      set -g renumber-windows on

      setw -g monitor-activity on
      set -g visual-activity off

      bind Tab select-pane -t :.+
      bind BTab select-pane -t :.-
      bind C-a last-window

      bind c new-window -c "#{pane_current_path}"
      bind C-c new-window -c "#{pane_current_path}"
      bind | split-window -h -c "#{pane_current_path}"
      bind \\ split-window -fh -c "#{pane_current_path}"
      bind _ split-window -fv -c "#{pane_current_path}"
      bind % split-window -v -c "#{pane_current_path}"

      bind -r < swap-window -t -1 \; select-window -t -1
      bind -r > swap-window -t +1 \; select-window -t +1
    '';
  };
}
