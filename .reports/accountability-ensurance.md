# Accountability ensurance — webfont-kit-generator-rb

| | |
|---|---|
| Upstream | `origin/master` @ `032df25285cab1c14ef5bfd1e242bcec2157d14f` |
| Port | `ruby` @ `ea115ca9ded6afbe879afecd5d6f7e84cc4c08a9` |

Scan: `find-excuses.sh` run over the whole tree, plus manual `grep -rn`
for `TODO|FIXME|not implemented|for now|in a future|no ruby bindings|not
supported|unsupported|skipped|placeholder|deliberately|out of scope|by
design` across `lib/`, `exe/`, `.reports/`, `TRANSLATION_PARITY.md` and
`COMPONENT_PARITY.md` (there is no `PORTING.md` on this branch). Every hit
read in context rather than counted.

## No open excuse in `lib/`/`exe/`

- `placeholder_text` (`lib/google_dialog.rb:180`, `lib/options.rb:290`) is
  the GTK entry API, not an excuse.
- `lib/log.rb:6`'s "skipped" is prose describing the log widget's italic
  style, not a skipped port task.
- `lib/generator.rb:32`'s "Two upstream behaviours are deliberately not
  reproduced" is, read in full, two documented *bug fixes* to upstream (a
  Python string-interpolation bug that always logged the literal text
  `<class 'range'>`, and a `clicked`-handler reconnect leak) — a correction
  with the upstream bug quoted and verified against
  `webfontkitgenerator/generator.py`, not a missing feature. This is the
  opposite of an excuse.
- No `TODO`, `FIXME`, "not implemented", "for now", "in a future", "no
  Ruby bindings [for X, unqualified]", or "not supported" survives a read
  anywhere in `lib/` or `exe/` this round.

## A previously-recorded excuse, checked, and confirmed gone

An earlier round's `.reports/accountability-ensurance.md` recorded that
`lib/source_view.rb` falsely claimed "no Ruby bindings for GtkSourceView 5"
to excuse a hand-rolled `Gtk::TextView`. Re-read at the current commit:
`lib/source_view.rb` now `require 'gtksourceview5'`s and subclasses
`GtkSource::View` directly, the gem is wired into the gemspec,
`nix/Gemfile` and `flake.nix`'s `gtkStack`, and `require 'gtksourceview5'`
was re-run in the dev shell this round and succeeds. That excuse and the
gap behind it are both gone — verified by running the require, not by
reading last round's note.

## The real finding this round: two committed ledgers no longer describe the tree they're about

Nothing in `lib/`/`exe/` claims false completeness in prose. The false
claims this round are in the *parity ledgers themselves* — numbers that
were true when written and have not been updated since the code moved past
them. Both were found by re-executing the underlying check, not by reading
the ledger's own words.

**1. `TRANSLATION_PARITY.md` (repo root) says `Gaps | 2`, and the tree now has zero.**
That file was written at commit `4a66667`. Commits `3b83bef` and `ea115ca`
— both later — added `data/org.rubygtkproject.WebfontKitGenerator
.desktop.in` and `.metainfo.xml.in`, closing exactly the two gaps the
ledger still lists as open (`Create @font-face kits easily`,
`font;font-face;`). This round's fresh census
(`.claude/skills/translation-parity/scripts/msgid-census.sh` against a
clean worktree) finds 76/76 keys matching and zero gaps. The ledger was
never regenerated after the fix landed, so it is currently lying in the
direction of *understating* the port's own completeness — which is less
dangerous than a false green, but it is the identical failure mode the
`translation-parity` skill names explicitly: "Regenerate before reading; a
`parity: true` from an old run proves the state of an old tree." The same
applies to a stale `Gaps: 2`.

**2. `.reports/component-inventory.md` (this branch's legacy inventory, not
one of the five reports this round writes) still lists item 18 — the
desktop/service/icon files — as absent ("`N/A` — not a `lib/*.rb` unit"),
and item 17 — `po/*.po` — as "not yet surveyed." Both are now stale for the
same reason as finding 1: the `data/` files exist, and translation parity
has since been surveyed and is clean. Left uncorrected, this file is a
second copy of the same false-red, available to be read by the next agent
as a currently-true statement.**

Writing finding 1 the way this skill asks for, since a stale ledger
treated as current is exactly the "note is now load-bearing" failure this
skill exists to catch, just running in the opposite direction (an
unclaimed fix instead of an unbuilt feature):

> I did not regenerate `TRANSLATION_PARITY.md` after `3b83bef` and `ea115ca`
> closed its two listed gaps, because I am an idiot who treated a ledger as
> something that updates itself.
> Upstream: upstream has no equivalent document to go stale — this is a
> port-only artifact.
> Port: `TRANSLATION_PARITY.md:10` reads `Gaps | 2` and lines ~187-203 name
> them as open; `po/webfontkitgenerator.pot`, `data/org.rubygtkproject
> .WebfontKitGenerator.desktop.in` and `.metainfo.xml.in` show both are
> closed. `.reports/component-inventory.md:31-32` makes the identical stale
> claim about the same two files.

## Verdict

Not clean. No excuse found in code. Two committed documents (one the
port's own authoritative ledger, one a prior audit artifact) assert a gap
count that executing the actual check this round disproves. The fix: the
port should regenerate `TRANSLATION_PARITY.md`'s header and gap table
against the current tree (0 gaps, 76 messages) and either refresh or
delete `.reports/component-inventory.md`'s stale rows. Neither is a product
defect — the app itself has no open gap found anywhere in this round's
five reports — but a committed document that disagrees with the tree it
describes is exactly the condition this skill exists to catch, regardless
of which direction the disagreement runs.
