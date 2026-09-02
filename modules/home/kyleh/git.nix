{
  config,
  ...
}:
{
  programs.git = {
    enable = true;
    package = null;
    settings = {
      alias.vlog = "log --show-signature";
      core = {
        autocrlf = "input";
        whitespace = "trailing-space,space-before-tab,cr-at-eol";
      };
      diff = {
        algorithm = "histogram";
        colorMoved = "default";
        colorMovedWS = "allow-indentation-change";
        mnemonicprefix = true;
        wsErrorHighlight = "all";
      };
      fetch.prune = true;
      help.autocorrect = "prompt";
      init.defaultBranch = "main";
      log.date = "short";
      merge.conflictstyle = "zdiff3";
      pull.rebase = true;
      push.autoSetupRemote = true;
      rebase.autoSquash = true;
      rerere.enabled = true;
      safe.bareRepository = "explicit";
      user = {
        email = config.infrastructure.user.email;
        name = config.infrastructure.user.fullName;
      };
    };
  };
}
