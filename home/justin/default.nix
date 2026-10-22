#### Justin's Home ####

{ ... }:

{
  ## Git
  programs.git = {
    enable = true;
    settings = {
      user.name = "Justin Ward";
      user.email = "jward92@gmail.com";
      init.defaultBranch = "main";
      fetch.prune = true;
      pull.ff = "only";
      push.autoSetupRemote = true;
      rebase.autoStash = true;
      diff.algorithm = "histogram";
      merge.conflictStyle = "zdiff3";
      rerere.enabled = true;
      commit.verbose = true;
      branch.sort = "-committerdate";
      tag.sort = "version:refname";
      column.ui = "auto";
    };
  };

  ## GitHub CLI (also registers its git credential helper)
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      aliases.co = "pr checkout";
    };
  };

  home.stateVersion = "26.05";
}
