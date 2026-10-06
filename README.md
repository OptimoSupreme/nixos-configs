# nixos-configs

One flake for every NixOS machine I run or manage. Each host is a directory,
shared behaviour is a module, and the hosts keep themselves current: every
registered machine pulls this repo's `main` from GitHub once a day and stages
the result for its next boot. Nothing in here is secret; passwords, WiFi
profiles and per-box data stay on the machines.

## Hosts

| Host | Group | What it is | Status |
| --- | --- | --- | --- |
| nazgul | workstation | My laptop, HP EliteBook. Secure Boot, TPM unlock, personal desktop | deployed |
| jeff-laptop | client | Jeff's HP laptop on the general-purpose desktop | deployed |
| gollum | appliance | Steam machine on Jovian-NixOS, boots straight into Gaming Mode | deployed |
| balrog | workstation | My desktop | not deployed yet |
| osse | appliance | Boat chartplotter: Android in Waydroid as a kiosk | not deployed yet |
| palantir | appliance | Retro TV launcher: Chromium kiosk on a 1980s console TV | not deployed yet |
| morgoth | server | Home server. Runs Debian today; the NixOS port is a stub | not started |

Hosts not yet deployed have no `hardware-configuration.nix` committed, so
they are commented out of `flake.nix` and nothing evaluates them until the
machine is installed. The two appliances have their own READMEs under
`hosts/appliances/`.

## Layout

```
flake.nix        registers hosts; mkHost for nixos-26.05, mkHostOn for another channel
hosts/           one directory per machine: default.nix + hardware-configuration.nix
  workstation_template.nix  the menu a new desktop host starts from
  workstations/  my desktops and laptops
  clients/       machines I manage for other people
  appliances/
  servers/
modules/         opt-in modules; desktop.nix is the shared GNOME block,
                 appliance.nix the shared headless block
assets/          dconf keyfiles, Firefox autoconfig, CAC certs, other static files
installer/       the live ISO, and the manual for installing a machine
```

## Using it

- **Install a machine**: build the ISO with `nix build .#installer-iso` and
  follow [installer/README.md](installer/README.md). It covers Calamares,
  handing the machine to the repo, Secure Boot, TPM unlock and updates.
- **Rebuild by hand**:
  `sudo nixos-rebuild switch --flake path:$HOME/nixos-configs#<host>`.
  The `path:` prefix avoids git ownership errors and includes untracked files.
- **Test a branch on a machine** before merging:
  `sudo nixos-rebuild test --flake github:OptimoSupreme/nixos-configs/<branch>#<host>`.
  The daily upgrade pulls `main` back over it within a day.
- **Updates**: `flake.lock` is bumped weekly by a GitHub Action that first
  checks every host still evaluates. Every push and pull request runs the
  same checks plus `nixfmt`.

## Contributing

Conventions for files, comments, modules and commits are in
[CLAUDE.md](CLAUDE.md). The short version: hosts hold only what is unique to
the machine, anything two hosts share becomes a module, and a merge to `main`
is a fleet rollout, so changes go through a pull request.
