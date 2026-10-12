# TODO

Open work on the fleet. Each item says what, why, and how to tell it is done.

## 1. Evaluate COSMIC and KDE as a GNOME replacement

Both `client_environment.nix` and `personal_environment.nix` build on the
GNOME block in `desktop.nix`. Find out whether COSMIC or KDE Plasma can be
configured to a point where it would replace GNOME in one or both
environments.

Plan:

1. Install stock NixOS in a VM and expose it over SSH so Claude can rebuild
   and inspect it directly.
2. Iterate on COSMIC (`services.desktopManager.cosmic`, `services.displayManager.cosmic-greeter`)
   until it is as good as it gets or it is clearly a dead end. Capture the
   finished config as a candidate `modules/cosmic_desktop.nix`.
3. Do the same for KDE Plasma 6 (`services.desktopManager.plasma6`, `services.displayManager.sddm`).
4. For each, note what the current GNOME setup provides that was lost or
   needs a workaround: the dconf keyfiles in `assets/dconf/`, GDM login
   screen settings, Plymouth handoff, fonts, the CAC pieces in `work_patch.nix`,
   whatever the clients rely on.
5. Decide per environment: keep GNOME, switch personal only, or switch both.

Done when: a decision is recorded here and either the GNOME block stays or a
replacement module is wired into one environment.

## 2. Early KMS module for every GPU vendor

Loading the GPU's kernel mode setting driver in the initrd gives native
resolution from the first frame: Plymouth, the LUKS prompt and the console
all render at the panel's resolution instead of the firmware's. The right
knob is different for each vendor, and today only palantir does it
(`boot.initrd.kernelModules = [ "i915" ]`).

Write a module, or a section of `workstation_template.nix`, that makes the
correct setting one line to pick:

- AMD: `hardware.amdgpu.initrd.enable = true`.
- Intel: `boot.initrd.kernelModules = [ "i915" ]`, or `[ "xe" ]` on Lunar Lake,
  Battlemage and newer.
- Nvidia: `hardware.nvidia.modesetting.enable = true`, the
  `nvidia nvidia_modeset nvidia_uvm nvidia_drm` modules in
  `boot.initrd.kernelModules`, and `nvidia-drm.fbdev=1` in `boot.kernelParams`.
  Check whether the open kernel module needs anything different.
- Hybrid laptops: usually the iGPU driver only, since that is what drives the
  panel.

Decide where it lives. The fleet rule is no custom options until three hosts
vary the same thing, so the first pass is probably a commented menu in
`workstation_template.nix` next to the existing GPU block, mirrored into
`nazgul` and `jeff-laptop`, with a `modules/` option only if the Nvidia case
turns out to be more than a few lines.

Done when: every registered desktop host has early KMS on and the template
shows the choice for all three vendors.

## 3. Customize the shell

Every host runs stock bash with the default prompt. The only shell setup in
the repo is the microfetch hook in `modules/desktop.nix`. Decide what the
interactive shell should look like across the fleet (prompt, aliases,
completion, history, whether to stay on bash or move to zsh or fish) and put
it in a module that both environments import.

Keep it system-level: no home-manager, so the config goes through
`programs.bash` (or the chosen shell's `programs.*` block) and
`environment.shellAliases`, not per-user dotfiles. Client machines should get
the same defaults as Justin's, so it belongs under `desktop.nix` or a module
both environments import, not in `personal_environment.nix` alone.

Done when: a shell module is imported by both environments and every
registered desktop host evaluates with it.

## 4. Wake from sleep automatic updates (option)
Add to template (potentially as an import), comment that it's an option best for desktops that are left powered on.

## 5. Sleep then shutdown (option)
Add to template (potentially as an import), comment that it's an option best for laptops to save battery.

## 6. Blur my shell feature exploration