# Staleness audit

A prompt to hand to an agent now and then. It asks for a report, not changes.
Run it with: "Read AUDIT.md and do what it says."

## Ground rules

- Output the whole report in the chat. Do not create or edit any file in the
  repo, and do not open a branch. Justin picks which findings to act on.
- Read `CLAUDE.md` first. It explains the layout, the fleet rules and the
  conventions you will be checking against.
- Every finding needs evidence. Quote the file and line, and link the
  upstream source (nixpkgs commit, NixOS release notes, GNOME release notes,
  Fedora or Ubuntu change proposal, project issue) that makes it stale or
  that shows what others do now. Use the web for this; do not rely on memory
  for what nixpkgs or GNOME currently do. Check the pinned revisions in
  `flake.lock` and the channels in `flake.nix` so you are comparing against
  the nixpkgs the fleet actually runs, not unstable or a future release.
- If something looks stale but you could not confirm it, say so and list it
  under "unverified" rather than dropping it or asserting it.
- Do not make anything up to fill a section. An empty section is a fine
  result.

## What to look for

Walk every `.nix` file under `flake.nix`, `hosts/`, `modules/` and
`installer/`, every file under `assets/`, and the GitHub workflows under
`.github/`. For each, ask the questions below.

### 1. Explicit settings that are now the default

Anything we set that nixpkgs, the module, or the upstream project now does on
its own. Examples of the shape: an option whose default flipped to our
value, a package nixpkgs now pulls in automatically, a kernel module the
hardware module from `nixos-hardware` already loads, a service a desktop
module now enables, a `lib.mkDefault` whose default is now the same as the
module's own. Also flag any option that is deprecated, renamed or
scheduled for removal in the pinned nixpkgs or the next stable release.

### 2. Workarounds and temporary fixes

Grep for comments like "workaround", "temporary", "until", "once",
"remove when", "fixed upstream", "hack", "TODO", "FIXME", and for links to
issues or pull requests. For each one, check whether the referenced issue is
closed, the fix is in the pinned nixpkgs, or the condition in the comment has
been met. Also look for workarounds with no comment at all: an odd
`systemd` override, a pinned package version, a package from
`nixpkgs-unstable` on a stable host, an overlay, a disabled test, an
`allowUnfree` or `permittedInsecurePackages` entry.

### 3. Stale dconf, Firefox and other asset files

For every keyfile under `assets/dconf/`, check that each schema and key
still exists in the GNOME version shipped by the pinned nixpkgs, that the
value is still valid, and that it is not simply the GNOME default now. Flag
keys for extensions or apps no longer installed by any module. Do the same
for the Firefox policies and autoconfig under `assets/firefox/`: removed
or renamed policies, preferences Mozilla has locked or dropped. Check any
other static file in `assets/` the same way.

### 4. Things upstream and other distros have adopted that we have not

Compare what the fleet does with what current GNOME, Fedora Workstation,
Ubuntu Desktop, and the NixOS release notes have moved to. Look at both
directions:

- Something they have adopted that we still do the old way, or do not do at
  all. Examples of the kind of thing to check: display manager and session
  choices, Wayland and X11 pieces, PipeWire and its session manager, audio
  and Bluetooth stacks, printing and scanning, fonts and font rendering,
  firmware updates, power management and thermal daemons, memory
  management (zram, swap, OOM handling), filesystem and snapshot tooling,
  Flatpak and portal setup, Secure Boot and TPM tooling, the boot chain
  (bootloader, Plymouth, initrd, early KMS), kernel choices, networking
  and DNS resolution, time sync, default applications, accessibility,
  input methods, and the GNOME extensions and settings that distros ship by
  default.
- Something we install or configure that they are moving away from or have
  already dropped. Be specific about who dropped it and when.

For each, say what it would mean for this repo: which module changes, which
hosts it would touch, and whether it is a one-liner or a project. Note when a
candidate is a matter of taste rather than staleness so it can be judged on
that basis.

### 5. Normalization across the repo

Check the repo against its own conventions in `CLAUDE.md` and against
itself:

- Section order, `####` banners, `##` block titles, comment style, nixfmt
  cleanliness.
- Hosts carrying things that two or more hosts share and that belong in
  `modules/`. Modules setting values with plain assignment where
  `lib.mkDefault` is the convention, or the reverse.
- `workstation_template.nix` versus `nazgul` and `jeff-laptop`: sections one
  has that the others lack, or that drifted apart.
- Hosts commented out of `flake.nix` that import modules which have since
  changed under them.
- The same thing done two different ways in two places: package lists,
  service enables, user definitions, kernel parameters, GPU blocks, the
  layout of `default.nix` across host groups.
- `README.md`, `TODO.md`, `installer/README.md` and `CLAUDE.md` describing
  something the code no longer does, or missing something it now does.
- Dead references: assets no module uses, modules no host imports, inputs in
  `flake.nix` nothing consumes.

## Report format

One report in chat with these sections, in this order. Number every finding
so Justin can refer to it by number when picking.

1. **Summary**: a few lines on the overall state and the handful of findings
   worth acting on first.
2. **Now the default**: findings from section 1.
3. **Workarounds**: findings from section 2, each with "still needed",
   "removable" or "unknown".
4. **Stale assets**: findings from section 3.
5. **Upstream has moved**: findings from section 4, split into "they
   adopted, we have not" and "we use, they dropped".
6. **Normalization**: findings from section 5.
7. **Unverified**: anything you suspect but could not confirm, with what
   would confirm it.

Each finding: a one-line title, the file and line, what is stale and why,
the evidence link, what changing it would involve, and which hosts it
touches. Keep each to a short paragraph. Where there is more than one
reasonable way to act on it, list the options with a recommendation. Do not
pad; a finding that is only a style nit can be one line.
