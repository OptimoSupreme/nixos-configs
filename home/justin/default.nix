#### Justin's Home ####

{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  flake = "path:${config.home.homeDirectory}/git/nixos-configs";
  host = osConfig.networking.hostName;
in
{
  ## Nix language server and formatter
  home.packages = with pkgs; [
    nixd
    nixfmt
  ];

  ## Git
  programs.git = {
    enable = true;
    settings = {
      user.name = "Justin Ward";
      user.email = lib.mkDefault "jward92@gmail.com"; # work hosts override it
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

  ## GitHub CLI
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
    };
  };

  ## VSCodium
  programs.vscodium = {
    enable = true;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
        timonwong.shellcheck
        foxundermoon.shell-format
        redhat.vscode-yaml
        tamasfe.even-better-toml
        teabyii.ayu
      ];
      userSettings = {
        ## Look
        "workbench.colorTheme" = "Ayu Dark";
        "workbench.sideBar.experimental.fontSize" = 14;
        "workbench.colorCustomizations"."[Ayu Dark]" = {
          "foreground" = "#e6e6e6"; # tree and Claude chat text
          "sideBarTitle.foreground" = "#e6e6e6";
          "sideBarSectionHeader.foreground" = "#e6e6e6";
          "list.activeSelectionForeground" = "#e6e6e6";
          "list.inactiveSelectionForeground" = "#e6e6e6";
          "list.focusForeground" = "#e6e6e6";
          "list.hoverForeground" = "#e6e6e6";
        };
        "workbench.startupEditor" = "none";
        "editor.fontFamily" = "'UbuntuSansMono Nerd Font Mono', monospace";
        "terminal.integrated.fontFamily" = "UbuntuSansMono Nerd Font Mono";
        "editor.minimap.enabled" = false;

        ## Editing
        "files.autoSave" = "onFocusChange";
        "editor.formatOnSave" = true;
        "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nixd";
        "nix.formatterPath" = "nixfmt";
        "nix.serverSettings".nixd = {
          formatting.command = [ "nixfmt" ];
          options = {
            nixos.expr = ''(builtins.getFlake "${flake}").nixosConfigurations.${host}.options'';
            home-manager.expr = ''(builtins.getFlake "${flake}").nixosConfigurations.${host}.options.home-manager.users.type.getSubOptions []'';
          };
        };

        ## Git
        "git.autofetch" = true;
        "git.enableSmartCommit" = true;

        ## Claude Code
        "claudeCode.hideOnboarding" = true;
        "claudeCode.preferredLocation" = "panel";
        "chat.fontFamily" = "Ubuntu Sans";
        "chat.editor.fontFamily" = "UbuntuSansMono Nerd Font Mono";

        ## Prompts and nags
        "explorer.confirmDragAndDrop" = false;
        "explorer.confirmDelete" = false;
        "terminal.integrated.initialHint" = false;
        "window.confirmSaveUntitledWorkspace" = false;
        "telemetry.telemetryLevel" = "off";
        "update.mode" = "none"; # Nix owns the binary
      };
    };
  };

  home.stateVersion = "26.05";
}
