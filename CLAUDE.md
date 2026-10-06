# nixos-configs

A flake managing a small fleet of NixOS machines. Every registered host runs
`system.autoUpgrade` against `github:OptimoSupreme/nixos-configs` main once a
day, so **a merge to main is a fleet rollout.** The repo is public: nothing in
it may be secret, and no IPs, passwords, or tokens belong here.

## Layout

- `flake.nix` registers hosts with `mkHost ./hosts/<group>/<name>`. Jovian/Steam
  hosts use `mkHostOn nixpkgs-unstable`; everything else tracks `nixos-26.05`.
  The attribute name must equal `networking.hostName`.
- `hosts/{workstations,clients,appliances,servers}/<name>/` holds `default.nix`
  plus the unmodified `nixos-generate-config` output as
  `hardware-configuration.nix`. `workstations/` are Justin's desktops and
  laptops; `clients/` are machines he manages for other people. Client hosts
  import `general_environment.nix` and are named `<owner>-<kind>`
  (`jeff-laptop`); Justin's hosts get names of their own.
  Hosts commented out of `flake.nix` are missing hardware configs; they are
  debt, not dead. Keep them in mind when changing modules they import.
- `hosts/workstation_template.nix` is the menu a new desktop host starts from.
- `modules/` is a flat set of opt-in modules. `desktop.nix` is the shared GNOME
  block; `general_environment.nix` (client machines) and
  `personal_environment.nix` (Justin's) each import it and add their own
  differences. A host imports exactly one of the two environments, never
  `desktop.nix` directly. Headless hosts import `appliance.nix` instead.
- `assets/` holds static files modules reference by relative path.
- `installer/` builds the live ISO. `installer/README.md` is the install,
  update, Secure Boot and TPM manual; link to it rather than repeating it.

## Writing Nix

**Section order.** Low level first, ending with the user-facing pieces:
imports, hardware (GPU, firmware, udev quirks), boot, kernel, swap,
networking, timezone and locale, users, environment and services, packages,
host-specific quirks, and `system.stateVersion` last. Within `imports`, `./hardware-configuration.nix`
comes first, then modules under a `## Select Modules` heading.

**Comments.** Each file opens with a `#### Title ####` banner. Each block gets
a short `##` title and nothing more. Add an inline comment only when the
reason a line exists is not obvious from the line itself, and keep it to a few
words. No narrative comments, no restating what the code does.

**Formatting.** nixfmt, via `nix fmt`. Run it on every `.nix` file you touch
except `hardware-configuration.nix`, which stays exactly as generated.

**Fleet rules.**
- A host file holds only what is unique to that machine: hardware, hostname,
  user, GPU, quirks. Anything two hosts would both want lives in `modules/`.
- Shared modules set defaults with `lib.mkDefault` so a host can override with
  a plain assignment. Do not add custom options until three hosts need to vary
  the same thing.
- Templates and the hosts built from them stay in sync both ways. Editing
  `workstation_template.nix` means checking `nazgul` and `jeff-laptop` for the
  same change; editing a section in a workstation that the template also has
  means checking whether the template should change too.
- Every registered host must still evaluate after a change, not just the one
  being edited.
- No home-manager. Per-user settings are system-level dconf keyfiles in
  `assets/dconf/`.
- Never hand-edit `hardware-configuration.nix`; regenerate it on the machine.

## Verifying a change

Before reporting a change as done:

1. Parse every touched `.nix` file. `nix-instantiate --parse` catches syntax
   errors and duplicate attributes, which `nix flake check` does not.
2. Evaluate `config.system.build.toplevel.drvPath` for each affected host: the
   host edited, plus every registered host that imports a touched module.
   `nix flake check` alone is shallow (option names only) and is not enough.
3. State what was and was not evaluated in the report.

If the machine has nix, run these directly. If it does not, use a
`docker.io/nixos/nix` container with the repo mounted and a persistent store
volume, e.g.

```
podman run --rm -v nixstore:/nix --security-opt label=disable \
  -v "$PWD":/work:ro docker.io/nixos/nix \
  nix --extra-experimental-features "nix-command flakes" \
  flake check --no-write-lock-file path:/work
```

Use `path:` rather than `git+file:` so untracked files count.

## Testing on a real host

```
sudo nixos-rebuild test   --flake path:$HOME/nixos-configs#<host>   # until reboot
sudo nixos-rebuild switch --flake github:OptimoSupreme/nixos-configs/<branch>#<host>
```

The daily upgrade pulls main back over a branch deploy, so an unmerged test
reverts itself within a day.

## Git workflow

- Work on a branch and open a PR. Do not push to main; merging is Justin's
  call because it deploys. CI runs the checks above plus `nixfmt --check` on
  every push and pull request (`.github/actions/check`).
- Conventional Commits: `type(scope): imperative summary`, lowercase, under 72
  characters. Scope is the host or module touched. Types: `feat`, `fix`,
  `refactor`, `docs`, `chore`, `ci`, `revert`. Add a body only when the why is
  not obvious; one logical change per commit.
- `hardware-configuration.nix` is committed as generated, because
  `nix flake check` evaluates every registered host.
