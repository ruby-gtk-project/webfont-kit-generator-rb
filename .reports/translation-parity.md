# Translation parity — webfont-kit-generator-rb

| | |
|---|---|
| Upstream | `origin/master` @ `032df25285cab1c14ef5bfd1e242bcec2157d14f` |
| Port | `ruby` @ `6893c450641b22b129f7b5386dc08e4ed4a7b6e7` |
| Domain | `webfontkitgenerator` (`domain_source: po/meson.build`, confirmed by `catalogue.rb`) |
| Upstream messages | 72 |
| Ported | 72 |
| Gaps | **0** |
| Extra (untranslated) | 0 |
| Kind mismatch | 0 |
| Unresolved markers (both sides) | 0 |
| `uses_mismatch` | 5 (all port-uses ≥ upstream-uses; read below, none a gap) |
| Languages | 24/24 `.po` files, byte-for-byte filename set, `LINGUAS` matches both sides |
| `.mo` catalogues | compiled, committed under `locale/**/*`, shipped via the gemspec |
| `summary.parity` (fresh `catalogue.rb --compare`, this round) | **true** |

Regenerated fresh this round against clean worktrees of both branches
(`git worktree add --detach … origin/master`, `… origin/ruby`), per the
skill's "regenerate before reading" rule — nothing here is carried over from
a prior round's YAML or table.

```
$ ruby .claude/skills/translation-parity/scripts/catalogue.rb <upstream-worktree> --role upstream
totals: {messages: 72, occurrences: 80, reused: 7, plural: 0, with_context: 6, unresolved: 0}

$ ruby .claude/skills/translation-parity/scripts/catalogue.rb <port-worktree> --role port
totals: {messages: 72, occurrences: 87, reused: 11, plural: 0, with_context: 6, unresolved: 0}

$ ruby .claude/skills/translation-parity/scripts/catalogue.rb --compare upstream.yaml port.yaml
summary: {ported: 72, gaps: 0, extra: 0, kind_mismatch: 0, uses_mismatch: 5,
          domain_matches: true, parity: true}
```

**Zero gaps, zero unresolved, zero extra, zero kind mismatches.** Every
upstream `(ctxt, msgid)` key has a byte-identical counterpart in the port's
catalogue, under the same domain.

## Correcting this round: the right message count is 72, not 76

A prior round's `.reports/translation-parity.md` reported "76 upstream
messages / 76 port messages, 0 gaps" from `cut -f1,2 msgid-census.sh-output |
sort -u | wc -l` on the **raw** census, which deliberately includes `po:`
rows (every msgid the last `msgmerge` left in a `.po` file, deleted ones
included — see the skill's "What else lives in `po/`"). Re-running the same
raw census this round reproduces the same 76:

```
$ grep 'Webfont Kit Generator' upstream-msgids.tsv
-	_About Webfont Kit Generator	po	po/hi.po:68
-	_About Webfont Kit Generator	po	po/zh.po:65
-	Webfont Kit Generator	po	po/hi.po:27
-	Webfont Kit Generator	po	po/zh.po:28
-	Webfont Kit Generator also includes a tool to Download fonts…	po	po/hi.po:52
-	Webfont Kit Generator also includes a tool to Download fonts…	po	po/zh.po:51
-	Webfont Kit Generator is a simple utility…	po	po/hi.po:42
-	Webfont Kit Generator is a simple utility…	po	po/zh.po:43
```

These four extra keys are the app's **old pre-rename name**
("Webfont Kit Generator"), surviving only in `po/hi.po` and `po/zh.po`
because those two translations have not been re-merged since upstream's
`<li>App name changed to Webfont Bundler</li>` release note (commit visible
in `data/*.metainfo.xml.in`'s `<releases>`). The current source — Ruby or
Python — contains no literal `_()`/`N_()` call for "Webfont Kit Generator"
anywhere; grepping `lib/` and `webfontkitgenerator/` for the string finds
nothing outside `po/`. `catalogue.rb` correctly excludes `po:`-kind rows from
`totals.messages` for exactly this reason (its own doc: "a `.po` lists every
msgid the last `msgmerge` knew about, deleted ones included, so counting it
would report a tree as emitting strings its code no longer has"), which is
why it reports 72 and the raw cut of `msgid-census.sh`'s output reports 76.

Both counts agree between upstream and the port (76=76 raw, 72=72
curated), so **neither methodology changes the parity verdict** — there was
never a gap under either count. But 76 was the wrong number to put in a
ledger, and this round uses `catalogue.rb`'s curated 72, which is what the
skill's own worked examples and data format treat as ground truth.

## The previously-stale root ledger: now current, re-verified

An earlier round of this audit (both `.reports/translation-parity.md` and
`.reports/accountability-ensurance.md` at commit `ea115ca`) found that the
root `TRANSLATION_PARITY.md` still said `Gaps | 2` for two msgids
(`Create @font-face kits easily`, `font;font-face;`) that commits `3b83bef`
and `ea115ca` had already closed by shipping `data/org.rubygtkproject
.WebfontKitGenerator.desktop.in` and `.metainfo.xml.in`. Commit `6893c45`
("Close translation-ledger staleness…") regenerated the file. Re-checked
this round, from the current HEAD, not from that commit's message:

```
$ head -11 TRANSLATION_PARITY.md
| Upstream messages | 72 |
| Ported | 72 |
| Gaps | 0 |
```

This now matches the fresh `catalogue.rb` numbers above exactly (72/72/0).
The staleness this skill exists to catch is closed, confirmed by
regenerating independently rather than by reading the ledger's own claim.

## The extraction-tooling gap from two rounds ago: still closed

Re-run again this round rather than carried forward:

```
$ cp po/webfontkitgenerator.pot /tmp/pot.orig
$ bundle exec rake gettext:pot:create
$ diff <(grep '^msgid' /tmp/pot.orig | sort) <(grep '^msgid' po/webfontkitgenerator.pot | sort)
(empty)
$ git checkout -- po/webfontkitgenerator.pot
```

The extraction pipeline still reproduces the committed `.pot` exactly, which
is the bijection between every `_()`/`p_()`/`n_()`/`C_()` call site in `lib/`
and the catalogue the build ships.

## Languages

```
$ diff <(ls <upstream>/po/*.po | xargs -n1 basename) <(ls po/*.po | xargs -n1 basename)
(empty)
$ diff <(sort <upstream>/po/LINGUAS) <(sort po/LINGUAS)
(empty)
```

24/24 `.po` files present on both sides, identical filenames, `LINGUAS`
matches the file list on both sides. `.mo` files are committed under
`locale/` and are exercised live by the German on-screen check below.

## `uses_mismatch` rows, read rather than reported blind

`catalogue.rb --compare` flags 5 messages where the port's call-site count
differs from upstream's. Per the skill, this is never itself a translation
gap — it is a lead for `component-parity.md`. All five run in the direction
of *more* port call sites, never fewer, and all are explained by reading the
sites:

| msgid | Up → Port | Why |
|---|---|---|
| `Couldn't download the Google Fonts data.` | 1 → 2 | Port's `fail_with` is called from two rescue paths (`on_database_response`, `use_local_or_fail`) where upstream inlines the same literal twice in one function; same message, same two user-facing moments. |
| `Error: {error}.` | 1 → 3 | Reused across `generator.rb`, `loader.rb`, `window.rb` — three Ruby call sites for the one upstream site, documented in-line (`lib/window.rb:743`) as a deliberate reuse of one upstream msgid rather than minting three. |
| `Webfont Bundler` | 3 → 5 | Upstream's 3 sites are `.desktop.in`, `.metainfo.xml.in`, `main.py`; the port's `data/org.rubygtkproject.*` pair plus two Ruby call sites (`application.rb:64,118`) plus `window.rb:127` — one extra genuine call site (the window title, marked separately per the file's own comment at `lib/window.rb:122-126` on why it is a second literal rather than a shared constant) and the app-id rename doubling the data files is not a doubling of data files, just file renames 1:1. |
| `Webfont Bundler also includes a tool…` | 1 → 2 | Upstream's `.metainfo.xml.in` paragraph, reused once more in the About dialog's `comments` (`application.rb:133`) — the same msgid shown in two places, not reworded. |
| `Webfont Bundler is a simple utility…` | 1 → 2 | Same shape as above, `application.rb:129`. |

None of these is a dropped call site (which is the failure mode this metric
exists to catch); all are either one upstream string shown in one more place
in the port, or a straight one-to-one data-file rename. No `component-parity`
row opened from this.

## Verified on screen

```
$ LANGUAGE=de LC_ALL=de_DE.UTF-8 nix develop --command xvfb-run -a ruby \
    -e 'require_relative "lib/options"; require_relative "lib/settings";
        require_relative "lib/translatable"; Gtk.init
        o = Options.new(Settings.new(path: "/tmp/x.json")); o.build
        puts o.formats_group.title; puts o.subsetting_row.title'
Optionen
Untergruppen
```

Matches `po/de.po`'s `msgstr` for `"Options"` → `"Optionen"` and
`"Subsetting"` → `"Untergruppen"`.

## Unrun checks

- `msgfmt -c` strict validation of the 24 `.po` files was not run this round
  either — the dev shell's `gettext` tooling was exercised only through
  `rake gettext:mo:update` (whose output, `locale/**/*.mo`, is committed and
  loaded live by the German check above). Named here as unrun, not folded
  into `parity: true`.

## Verdict

The catalogue has translation parity: **72/72 messages, 0 gaps, 0 unresolved,
0 kind mismatches, 24/24 languages**, domain confirmed, one language verified
rendering on screen, re-derived fresh this round rather than read from either
this file's own prior version or the root ledger. The root `TRANSLATION_PARITY.md`
now agrees with this number; the only correction this round makes is to this
very report's own prior count (76 → 72, methodology explained above), which is
itself exactly the kind of self-check `accountability-ensurance.md` exists to
run on this file too, not only on the code.
