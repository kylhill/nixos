{ pkgs, ... }:
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
        email = "kylhill@gmail.com";
        name = "Kyle Hill";
        signingkey = "E644A61F810BDC4D1294867A2E37EF3EA077FAD8";
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
