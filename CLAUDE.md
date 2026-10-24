# nixos-configs

A flake managing a small fleet of NixOS machines. Every registered host runs
`system.autoUpgrade` against `github:OptimoSupreme/nixos-configs` main once a
day, so **a merge to main is a fleet rollout.** The repo is public: nothing in
it may be secret, and no IPs, passwords, or tokens belong here.

## Layout

- `flake.nix` registers hosts with `mkHost ./hosts/<group>/<name>`. Jovian/Steam
  hosts use `mkHostOn nixpkgs-unstable`; everything else tracks `nixos-26.05`.
  The attribute name must equal `networking.hostName`. Board quirks come
  from the `nixos-hardware` input, imported first under `## Select Modules`
  (see `balrog`).
- `hosts/{workstations,clients,appliances,servers}/<name>/` holds `default.nix`
  plus the unmodified `nixos-generate-config` output as
  `hardware-configuration.nix`. `workstations/` are Justin's desktops and
  laptops; `clients/` are machines he manages for other people. Client hosts
  import `client_environment.nix` and are named `<owner>-<kind>`
  (`jeff-laptop`); Justin's hosts get names of their own.
  Hosts commented out of `flake.nix` are not currently deployed (some may
  have been before); they are debt, not dead. Keep them in mind when
  changing modules they import.
- `hosts/workstation_template.nix` is the menu a new desktop host starts from.
- `modules/` is a flat set of opt-in modules. `workstation_core.nix` is the
  shared workstation configuration; `client_environment.nix` (client machines)
  and `personal_environment.nix` (Justin's) each import it and add their own
  differences. A host imports exactly one of the two environments, never
  `workstation_core.nix` directly. `home_patch.nix` (home apps, the home
  server) and `work_patch.nix` (CAC, Chromium, Slack, Zoom) each layer on
  `personal_environment.nix`; a personal host imports one or both. The work
  dconf keyfile lays the app grid out as two pages, work then home, and GNOME
  shows a page only when something on it is installed, so the same keyfile
  serves work-only and work-plus-home hosts. Appliances and servers import
  neither environment: each is a one-off, so its host file holds everything
  but `maintenance.nix`.
- `home/justin/` is the home-manager configuration for Justin's user. Only
  `personal_environment.nix` wires it in (as a NixOS module, so a rebuild or
  the daily upgrade applies it). Client hosts never get home-manager: their
  user accounts belong to other people.
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
- A workstation host file holds only what is unique to that machine:
  hardware, hostname, user, GPU, quirks. Anything two workstations would both
  want lives in `modules/`. Appliances and servers are exempt: each is a
  one-off, so the same block in two of them is a coincidence, not a module.
  Leave it repeated.
- Shared modules set defaults with `lib.mkDefault` so a host can override with
  a plain assignment. Do not add custom options until three hosts need to vary
  the same thing.
- Templates and the hosts built from them stay in sync both ways. Editing
  `workstation_template.nix` means checking `nazgul` and `jeff-laptop` for the
  same change; editing a section in a workstation that the template also has
  means checking whether the template should change too.
- Every registered host must still evaluate after a change, not just the one
  being edited.
- home-manager is for Justin's dotfiles only (`home/justin/`): git, gh,
  Codium. Desktop settings stay system-level dconf keyfiles in
  `assets/dconf/`, shared with the client environment. Anything every
  workstation user should have (shell history tuning, fzf) goes in
  `workstation_core.nix`, not home-manager.
- Never hand-edit `hardware-configuration.nix`; regenerate it on the machine.

## Tools that are not on the machine

Nothing beyond coreutils is installed system-wide, and `python3` is not on
`PATH`. Do not fall back to `sed` or `awk` gymnastics when a Python script is
the right tool; get it from nixpkgs instead:

```
nix shell nixpkgs#python3 -c python3 -I script.py
nix shell nixpkgs#python3 -c python3 -I - <<'EOF'
...
EOF
```

The system registry pins `nixpkgs` to the running system's nixpkgs, so this
starts instantly and needs no network. Add packages the same way
(`nixpkgs#python3Packages.pyyaml`, `nixpkgs#jq`). The same goes for any other
tool that is missing.

## Verifying a change

Before reporting a change as done:

1. Parse every touched `.nix` file. `nix-instantiate --parse` catches syntax
   errors and duplicate attributes, which `nix flake check` does not.
2. Evaluate `config.system.build.toplevel.drvPath` for each affected host: the
   host edited, plus every registered host that imports a touched module.
   `nix flake check` alone is shallow (option names only) and is not enough.
3. State what was and was not evaluated in the report.

A change under `home/` is covered by step 2 for the hosts that import
`personal_environment.nix`; there is no separate home-manager check.

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

- Work on a new branch, never on main. Leave the changes uncommitted when the
  work is done and ask Justin whether to commit and whether to open a PR; do
  not commit or push until he says so. Merging is Justin's call because it
  deploys. Open PRs as drafts; CI (`.github/actions/check`, the checks above
  plus `nixfmt --check`) is skipped on drafts and runs once the PR is marked
  ready for review, on every push after that, and on pushes to main.
- Conventional Commits: `type(scope): imperative summary`, lowercase, under 72
  characters. Scope is the host or module touched. Types: `feat`, `fix`,
  `refactor`, `docs`, `chore`, `ci`, `revert`. Add a body only when the why is
  not obvious; one logical change per commit.
- Claude attribution lines (`Co-Authored-By`, the "Generated with" footer)
  are fine on commits and PRs in this repo. Anywhere else, including upstream
  contributions, add one only when that project's policy requires it.
- `hardware-configuration.nix` is committed as generated, because
  `nix flake check` evaluates every registered host.
- Upstream contributions: keep PR descriptions, commit bodies and review replies
  short and to the point. A few lines on the problem, the fix and how it was
  tested; no long generated write-ups. A nixpkgs maintainer asked for this because
  long text slows review.
