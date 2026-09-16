{
  description = "My custom NixOS configurations.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, ... }:
    let
      mkHostOn = pkgs: path: pkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ path ];
      };
      mkHost = mkHostOn nixpkgs;
    in
    {
      nixosConfigurations = {

        # My Workstations
        # balrog = mkHost ./hosts/workstations/balrog;
        nazgul = mkHost ./hosts/workstations/nazgul;

        # Client Workstations
        jeff-laptop = mkHost ./hosts/workstations/jeff-laptop;

        # Appliances
        gollum = mkHostOn nixpkgs-unstable ./hosts/appliances/gollum;
        # osse = mkHost ./hosts/appliances/osse;
        # palantir = mkHost ./hosts/appliances/palantir;

        # Servers
        # morgoth = mkHost ./hosts/servers/morgoth;

        # Installer
        installer = mkHost ./installer;
      };

      # `nix build .#installer-iso` -> result/iso/nixos-configs-*.iso
      packages.x86_64-linux.installer-iso =
        self.nixosConfigurations.installer.config.system.build.isoImage;
    };
}
