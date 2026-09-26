{
  programs = {
    bat.enable = true;
    fzf.enable = true;

    direnv = {
      enable = true;
      config.global.hide_env_diff = true;
      nix-direnv.enable = true;
      silent = true;
    };
  };
}
