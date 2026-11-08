# Accountability ensurance — webfont-kit-generator-rb

| | |
|---|---|
| Upstream | `origin/master` @ `032df25285cab1c14ef5bfd1e242bcec2157d14f` |
| Port | `ruby` @ `6893c450641b22b129f7b5386dc08e4ed4a7b6e7` |

Scan: `find-excuses.sh` run over the whole tree this round, plus manual
`grep -rniE 'TODO|FIXME|not implemented|for now|in a future|no ruby
bindings|not supported|unsupported|skipped|placeholder|deliberately|out of
scope|by design'` across `lib/`, `exe/`, `.reports/`, `TRANSLATION_PARITY.md`
and this tree's other committed prose. Every hit read in context rather than
counted.

## No open excuse in `lib/`/`exe/`

```
$ bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh .
TRANSLATION_PARITY.md:147:Skipping:...
.reports/component-parity.md:62:SKIPPED:...
.reports/accountability-ensurance.md:69/10/19/20: (this file's own prior
  round quoting the rule — a document about excuses, exempt per this
  skill's own "two things it will match that you should not rewrite")
```

Every hit read:

- `TRANSLATION_PARITY.md:147` — `"No glyphs where found for {range}.
  Skipping."` is a **msgid**, upstream's own translatable string
  (`generator.py`), appearing in a parity ledger's message table. It is
  prose about a string, not an excuse for missing work.
- `.reports/component-parity.md:62` — `"It skips itself cleanly (exit 0,
  labelled SKIPPED)"` describes `test/drive_google_fonts.rb`'s own designed
  behaviour (skip gracefully with no network) — a feature of the test
  script, not an excuse for an unported app feature. Re-verified this round:
  the script was run against a live connection and all 8 checks passed (see
  `test-parity.md`); its offline-skip path exists and is documented, not
  invoked.
- No `TODO`, `FIXME`, "not implemented", "for now", "in a future", "no Ruby
  bindings [for X, unqualified]", "not supported", "out of scope", or "by
  design" survives a read anywhere in `lib/` or `exe/` this round. The one
  prior finding in this category — `lib/source_view.rb` once claiming "no
  Ruby bindings for GtkSourceView 5" to excuse a hand-rolled `Gtk::TextView`
  — was closed two rounds ago and re-confirmed again this round:
  `require 'gtksourceview5'` was re-run fresh in the dev shell this round
  and succeeds; `lib/source_view.rb` subclasses `GtkSource::View` directly.

## A real binding limitation, correctly recorded (not an excuse)

`lib/window.rb:23-26` and `lib/shortcuts_window.rb:12-16` each document a
genuine Ruby-bindings defect — `Adwaita::ApplicationWindow` raising on
construction, and `Gtk::ShortcutsWindow` raising "GtkWindow is not subtype
of GtkShortcutsWindow" — re-verified this round by attempting the
construction directly:

```
$ nix develop --command xvfb-run -a ruby -e 'require "gtk4"; Gtk::Window.new; Gtk::ShortcutsWindow.new'
RAISED: TypeError: GtkWindow is not subtype of GtkShortcutsWindow
```

Both comments name the substitution (`Gtk::ApplicationWindow`,
`Adw.ShortcutsDialog`) and the behaviour preserved, in the file, at the
line — this is the correct shape per the skill: a binding limitation
explaining why a correspondence was necessary, never a reason a gap is
closed, and in both cases the correspondence was verified in
`component-parity.md` to actually carry the full behaviour across (same
widget tree, same accelerators, same five shortcuts).

## Last round's finding, re-checked and confirmed closed

A previous round of this report flagged two documents disagreeing with the
tree they described:

1. **`TRANSLATION_PARITY.md`** said `Gaps | 2` for two msgids
   (`Create @font-face kits easily`, `font;font-face;`) that commits
   `3b83bef`/`ea115ca` had already closed by shipping `data/org
   .rubygtkproject.WebfontKitGenerator.desktop.in`/`.metainfo.xml.in`.
2. **`.reports/component-inventory.md`** items 17/18 said the same two
   things were still open/unsurveyed.

Both were regenerated in commit `6893c45`. Re-checked this round from the
current `HEAD`, not from that commit's message:

```
$ head -11 TRANSLATION_PARITY.md
| Upstream messages | 72 |
| Ported | 72 |
| Gaps | 0 |

$ grep -n 'not yet surveyed\|N/A' .reports/component-inventory.md
(no matches on items 17/18 any more)
```

Closed, confirmed by reading the current files rather than trusting the fix
commit's own description of itself.

## This round's finding: this report's own prior sibling document was wrong, in the "looks more thorough" direction

`.reports/translation-parity.md` (the version this round replaces) claimed
"76 upstream messages / 76 port messages" from the raw
`msgid-census.sh` output without excluding `po:`-kind rows — rows the
census deliberately emits for provenance but that `catalogue.rb` (and the
skill's own worked examples) exclude from the message count, because a
`.po` file keeps obsolete msgids from before the app's rename
("Webfont Kit Generator" → "Webfont Bundler") that no `_()` call anywhere in
either tree's source still produces. Both sides agreed at 76, so no parity
verdict was ever wrong — but the number itself was the wrong one to put in a
ledger, and a bigger, more-precise-looking number that came from skipping a
documented exclusion is exactly the shape of error this skill exists to
catch even when it runs in the "looks more careful" direction rather than
the "excuses a gap" direction. Rewritten this round in `translation-parity.md`
with the four stale `po/hi.po`/`po/zh.po` rows named, and the correct
72/72/0 restored, derived from `catalogue.rb --compare` rather than from a
hand-filtered `cut | sort -u | wc -l`.

> I reported 76/76 instead of 72/72 last round because I ran `wc -l` on a
> census stream without reading what the skill's own document says that
> stream contains, and a number nobody checked against the tool meant to
> produce it is worth exactly as much as one I invented.

## Verdict

**Clean.** No excuse found in `lib/`/`exe/` this round. The two previously
committed stale documents (`TRANSLATION_PARITY.md`,
`.reports/component-inventory.md`) are confirmed regenerated and now agree
with the tree. The one correction this round makes is to this audit's own
prior-round sibling report, not to the port: `.reports/translation-parity.md`'s
76/76 is replaced with the methodologically-correct 72/72, with zero change
to the parity verdict in either direction. No gap is being excused anywhere
in this tree as of `6893c45`.
