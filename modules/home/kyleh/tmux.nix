{ pkgs, ... }:
{
  home.sessionVariables.TMUX_NERD_FONT = "1";

  programs.tmux = {
    enable = true;
    baseIndex = 1;
    prefix = "C-a";
    terminal = "tmux-256color";
    sensibleOnTop = true;

    plugins = [
      pkgs.tmuxPlugins.vim-tmux-navigator
      {
        plugin = pkgs.tmuxPlugins.dracula;
        extraConfig = ''
          set -g @dracula-plugins "cpu-usage ram-usage"
          set -g @dracula-cpu-usage-colors "light_purple dark_gray"
          set -g @dracula-ram-usage-colors "green dark_gray"
          set -g @dracula-left-icon-padding 0
          set -g @dracula-border-contrast true

          if-shell 'test "$TMUX_NERD_FONT" = 1 && test -z "''${KASM_SSH+x}"' {
            set -g @dracula-show-powerline true
            set -g @dracula-show-left-icon "󱄅"
            set -g @dracula-cpu-usage-label ""
            set -g @dracula-ram-usage-label ""
          } {
            set -g @dracula-show-powerline false
            set -g @dracula-show-left-icon " "
            set -g @dracula-cpu-usage-label ""
            set -g @dracula-ram-usage-label ""
          }

          set -g @dracula-colors "white=#93a1a1
          gray=#586e75
          dark_gray=#002b36
          light_purple=#268bd2
          dark_purple=#073642
          cyan=#2aa198
          green=#859900
          orange=#cb4b16
          red=#dc322f
          pink=#d33682
          yellow=#cb4b16"
        '';
      }
    ];

    extraConfig = ''
      set -as terminal-features ',xterm-256color:RGB'
      set -ag update-environment WAYLAND_DISPLAY
      set -ag update-environment KASM_SSH
      set -ag update-environment TMUX_NERD_FONT

      set -g set-titles on
      set -g set-titles-string "#{user}@#h: #W"
      set -g renumber-windows on

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

      bind -r H resize-pane -L 10
      bind -r J resize-pane -D 10
      bind -r K resize-pane -U 10
      bind -r L resize-pane -R 10
    '';
  };
}
