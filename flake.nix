{
  description = "My custom NixOS configurations.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      ...
    }:
    let
      mkHostOn =
        pkgs: path:
        pkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [ path ];
        };
      mkHost = mkHostOn nixpkgs;
    in
    {
      nixosConfigurations = {

        ## My Workstations
        # balrog = mkHost ./hosts/workstations/balrog; # waiting on the Framework Desktop board
        nazgul = mkHost ./hosts/workstations/nazgul;

        ## Clients
        jeff-laptop = mkHost ./hosts/clients/jeff-laptop;

        ## Appliances
        gollum = mkHostOn nixpkgs-unstable ./hosts/appliances/gollum;
        # osse = mkHost ./hosts/appliances/osse; # not deployed yet
        # palantir = mkHost ./hosts/appliances/palantir; # not deployed yet

        ## Servers
        # morgoth = mkHost ./hosts/servers/morgoth; # runs Debian today

        ## Installer
        installer = mkHost ./installer;
      };

      ## `nix build .#installer-iso` -> result/iso/nixos-gnome-*.iso
      packages.x86_64-linux.installer-iso =
        self.nixosConfigurations.installer.config.system.build.isoImage;

      ## `nix fmt`
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
    };
}
