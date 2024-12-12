## Add the pcscd.enable module, as well as the ccid, and opensc packages to your configuration.nix
``` 
{
 services = {
    pcscd.enable = true;
  };

  environment = {
    systemPackages = with pkgs; [
      ccid
      opensc
    ];
  };
}
```

## Download DoD PKI Certs
https://public.cyber.mil/pki-pke/pkipke-document-library/

Choose the following file: `PKI CA Certificate Bundles: PKCS#7 For DoD PKI Only - Version 5.13`

## Import the certs to Firefox
Settings>Privacy & Security>View Certificates...>Authorities>Import...>

Start with `certificates_pkcs7_v5_13_dod.sha256`

## Add your CaC reader as a security device
Settings>Privacy & Security>Security Devices...>Load

Name it whatever you want, the path is `/run/current-system/sw/lib/opensc-pkcs11.so`.