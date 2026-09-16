#### Fastfetch ####

{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.fastfetch ];
  environment.etc."xdg/fastfetch/config.jsonc".source = ../assets/fastfetch/config.jsonc;
  programs.bash.interactiveShellInit = ''
    command -v fastfetch >/dev/null && fastfetch
  '';
}
