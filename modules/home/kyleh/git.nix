{
  inventory,
  pkgs,
  ...
}:
{
  programs.git = {
    enable = true;
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
        email = inventory.user.email;
        name = inventory.user.fullName;
        signingkey = inventory.user.gitSigningKey;
      };
      credential = {
        "https://github.com".helper = [
          ""
          "!${pkgs.gh}/bin/gh auth git-credential"
        ];
        "https://gist.github.com".helper = [
          ""
          "!${pkgs.gh}/bin/gh auth git-credential"
        ];
      };
    };
  };
}
