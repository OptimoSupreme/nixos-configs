# Staleness audit

A prompt to hand to an agent now and then. It asks for a report, not changes.
Run it with: "Read audits/AUDIT.md and do what it says."

## Ground rules

- Write two files to `audits/` on a new branch, and change nothing else in
  the repo. The report goes to `audits/<YYYY-MM-DD>-report.md` (today's
  date); it is the record of what the audit found and is edited later only
  to correct an inaccuracy, with a dated correction note on the finding.
- The working list goes to `audits/<YYYY-MM-DD>-actions.md`: the same
  findings, same numbers, no baseline or summary, each with a status line
  that starts as **Open**. Justin works from it. Items are never removed;
  as he decides or lands them the status changes in place to **Done** with
  the commit ids that made the change, **Kept** when the report said to
  leave something alone and he agreed, **Waiting** on a named upstream
  event, or **Declined**, with a few words on why when he gave one. An
  agent making a fix in response to an audit updates the list in the same
  change. Once an item is settled its text may be trimmed to the title and
  status, since the report holds the detail.
- The action list's first heading ends with `: open` while any item is
  Open, then `: settled <YYYY-MM-DD>`, so a reader knows at a glance
  whether anything is left. Whichever agent marks it settled also moves
  both files to `audits/archive/` in the same change, without asking. File
  links in both are relative to the file, so they start with `../` in
  `audits/` and are rewritten to `../../` on the move.
- Read every earlier action list, in `audits/` and `audits/archive/`,
  before starting. It shows what was done, with the commits, what is
  waiting, and what was declined. Report a declined finding again if it is
  still stale: the reason may not hold any more, and Justin wants the
  reminder. A Waiting item whose event has happened is a finding too. When
  a finding repeats an earlier one, say so with the old date and number,
  as in "declined in 2026-10-12 as 6.3".
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

Prove every "now the default" claim before reporting it: record
`config.system.build.toplevel.drvPath` for every registered host, remove the
line, and confirm the path is unchanged on every host. If it moves, diff the
two derivations (`nix-diff`) and say what changed. A setting that is the
default on most hosts but not on one (the installer ISO has X enabled, Jovian
sets its own zram) is not redundant; report it as such or drop it.

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

### 6. Audit the audit

This prompt goes stale too. While working through it, note where it no
longer fits the repo as it is on the day you run it:

- Paths, hosts, modules and assets it names that no longer exist, and new
  ones it does not mention (a new host group, a new asset type, a new
  workflow, a desktop other than GNOME).
- Questions that no longer apply, examples that point at things since
  removed, and checks the repo now needs that are missing here.
- Steps that turned out to be the wrong way to verify something, and better
  ones you used instead.
- A rule here that contradicts another, that an action list does not
  follow, or that uses a term it never defines.
- Whether the report format still serves how the reports are used.

Put concrete edits for this file in the report (section 8). Do not edit
this file yourself.

## Report format

One report at `audits/<YYYY-MM-DD>-report.md` with these sections, in
this order, and the same findings copied into
`audits/<YYYY-MM-DD>-actions.md` without the summary, each marked
**Open**. Number every finding so Justin can refer to it by number when
picking.

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
8. **Audit prompt updates**: findings from section 6, as concrete edits to
   this file.

Each finding: a one-line title, then three labelled parts: **What changed**
(the file and line, what is stale, the evidence link), **Recommendation**
(the one change to make, or the options with one recommended, and which
hosts it touches), and **Why**. Keep each to a short paragraph. Do not pad;
a finding that is only a style nit can be one line. Leave out anything you
confirmed is still correct; the report lists decisions to make, not checks
that passed.
