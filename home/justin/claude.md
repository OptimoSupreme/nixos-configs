# Justin's machines

User-level instructions for Claude Code on Justin's personal hosts. A repo's own
`CLAUDE.md` adds to this; where the two disagree, the repo wins, except for the
attribution rule, which has no exceptions.

## No attribution

Never add Claude attribution to anything: no `Co-Authored-By` trailer, no
"Generated with" footer, no mention of Claude in a commit, PR, issue, review
reply, document or comment. This holds in every repo, including ones whose own
instructions say attribution is fine. If a project's contributing policy
requires AI disclosure, say so and ask before adding one.

## Writing for other people

Anything someone other than Justin will read (a PR description, commit body,
issue, review reply, mailing list post, doc) is short and to the point. Keep
every fact the reader needs and cut the rest. Write like a person: plain
prose, casual but professional, no headers or bullet walls unless the content
really is a list. A few lines on the problem, the fix and how it was tested is
usually the whole PR description.

## Git

- Work on a new branch, never on main.
- Do not commit, push, open a PR or merge until Justin says so. Leave the work
  uncommitted and ask.
- Conventional Commits unless the repo says otherwise: `type(scope): imperative
  summary`, lowercase, under 72 characters, one logical change per commit, a
  body only when the why is not obvious from the summary.
- Before a merge, rewrite the branch to one commit per logical change and push
  with `--force-with-lease`. Review tweaks get squashed, not pushed as their
  own commits.
- Assume every repo is public: no IPs, passwords, tokens or keys in it.

The `Work` repo (`OptimoSupreme/Work`, usually at `~/git/Work`) is the one
exception. It is Justin's alone, so the branch and approval rules above do not
apply there: commit on main and push after every change, with no need to ask.

## Done means verified

Run the parse, build, check or test before reporting a change as done, and say
what was and was not checked. If something failed or was skipped, say so first.
Do not re-propose something Justin has declined.

## Code and comments

Comments say why, in a few words, only where the line does not explain itself.
No narrative comments and no restating what the code does. Match the style of
the file being edited.

## Tools

Every personal host is NixOS and nothing beyond coreutils is installed
system-wide. Get the right tool from nixpkgs instead of improvising with `sed`:

```
nix shell nixpkgs#python3 -c python3 -I script.py
nix shell nixpkgs#jq -c jq ...
```

The registry pins `nixpkgs` to the running system, so this starts instantly
and works offline. Never run `nix fmt` without file arguments: nixfmt waits on
stdin and the command never returns.
