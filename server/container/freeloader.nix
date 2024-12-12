{ config, pkgs, ... }:
{
  containers.dockerAndSSH = {
    autoStart = true;

    # Configuration for the container
    config = {
      # Set hostname
      networking.hostName = "freeloader";

      # Create user 'purplg' and make them a sudoer
      users.users.purplg = {
        isNormalUser = true;
        home = "/home/purplg";
        extraGroups = [ "wheel" ]; # Grants sudo privileges
        shell = pkgs.bash;
      };

      # Enable Docker service
      virtualisation.docker.enable = true;

      # Enable OpenSSH server
      services.openssh = {
        enable = false;
        permitRootLogin = "no"; # Only enable this if you're confident in your security setup
        passwordAuthentication = false; # Adjust as per your security requirements
        listenAddresses = [ "0.0.0.0:2222" ];
      };

      # Networking configuration to enable the container to appear as a device in the LAN
      networking = {
        useDHCP = true; # Container will receive an IP address from the LAN DHCP server
        interfaces.eth0.useDHCP = true;
        defaultGateway = ""; # Let DHCP manage the gateway
      };

      # Set memory limits for the container
      systemd.services.container-dockerAndSSH.serviceConfig = {
        MemoryLimit = "16G";
      };
    };

    # Add the container to a bridged network
    privateNetwork = false; # Disables private networking
    hostAddress = null; # Required for bridged networking
  };

  # Set persistent storage directory
  bindMounts = {
    "/srv" = {
      hostPath = "/srv/freeloader";
      isReadOnly = false;
    };
  };
}
