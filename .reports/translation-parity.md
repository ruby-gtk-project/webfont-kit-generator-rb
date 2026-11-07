# Translation parity — webfont-kit-generator-rb

| | |
|---|---|
| Upstream | `master` @ `032df25` |
| Port | `ruby` @ `ea115ca` |
| Domain | `webfontkitgenerator` |
| Upstream messages (census, this round) | 76 |
| Port messages (census, this round) | 76 |
| Gaps (census, this round) | **0** |
| Extra (untranslated) | 0 |
| Unresolved markers (both sides) | 0 |
| Languages | 24/24 `.po` files match, byte for byte filename set, `LINGUAS` matches on both sides |
| `.mo` catalogues | compiled and committed under `locale/**/*`, shipped via the gemspec |
| Verified on screen | `LANGUAGE=de LC_ALL=de_DE.UTF-8` under `xvfb-run`, re-run this round: `Options#formats_group.title` → `"Optionen"`, `Options#subsetting_row.title` → `"Untergruppen"`, matching `po/de.po` |

Census re-run this round with `.claude/skills/translation-parity/scripts/
msgid-census.sh` against a fresh `origin/master` worktree and this tree:

```
$ cut -f1,2 upstream-msgids.tsv | sort -u | wc -l
76
$ cut -f1,2 port-msgids.tsv | sort -u | wc -l
76
$ comm -23 up.keys port.keys   # upstream keys missing from the port
(empty)
```

**Zero gaps, zero unresolved, zero extra.** Every upstream msgid has a
byte-identical counterpart somewhere in the port.

## A real finding: the port's own ledger is stale, and says the opposite

The committed `TRANSLATION_PARITY.md` at the repo root — the port's own
authoritative ledger, written at commit `4a66667` — still reads:

```
| Upstream messages | 72 |
| Ported | 70 |
| Gaps | 2 |
```

and lists those two gaps as open: `Create @font-face kits easily` and
`font;font-face;`, both attributed to "the port ships no
`data/*.desktop.in` or `.metainfo.xml.in` at all." That was true when
`4a66667` was written. It has not been true since commit `3b83bef` added
`data/org.rubygtkproject.WebfontKitGenerator.desktop.in` and
`.metainfo.xml.in` (both marked, both listed in `po/POTFILES.in`), and this
round's fresh census confirms both msgids are now in the port's catalogue
at those exact files. **The ledger was never regenerated after the fix
landed**, so a reader of `TRANSLATION_PARITY.md` today is told the port is
at 70/72 when the tree it describes is at 76/76. This is the inverse of a
false green — a false red left uncorrected — but it is the same underlying
failure the `translation-parity` skill warns about: "Regenerate before
reading; a `parity: true` from an old run proves the state of an old tree."
Nobody regenerated before the last commit that touched `data/`. Flagged in
`accountability-ensurance.md`.

(The commit-count drift between the stale ledger's 72 and this round's 76
is the same two `data/` messages plus the two it already had, consistent
with the fix adding exactly those two files' strings and nothing else
changing.)

## The extraction-tooling gap from the prior round: closed, re-verified by running it

A prior round's `.reports/translation-parity.md` recorded that
`rake gettext:pot:create`, run for real, dropped 15 msgids reached through
non-literal `_()`/`p_()` call sites (`_(TITLE)`, `_(SUBSET_TITLES.fetch
(name))`, a loop over `SHORTCUTS`, etc.). This round re-ran the same
command from a clean worktree rather than trusting that commit's message:

```
$ cp po/webfontkitgenerator.pot /tmp/pot.orig
$ bundle exec rake gettext:pot:create
$ grep '^msgid' po/webfontkitgenerator.pot | sort > new.txt
$ grep '^msgid' /tmp/pot.orig | sort > old.txt
$ diff old.txt new.txt
(empty — 73 msgids both sides, identical)
$ git checkout -- po/webfontkitgenerator.pot   # working tree left clean
```

Confirmed: the extraction pipeline now reproduces the committed `.pot`
exactly, because `3b83bef` replaced every non-literal `_()`/`p_()` call
site with literal arguments and added `po/extractors.rb`'s
`DesktopParser`/`MetainfoParser` for the two non-Ruby sources. This is a
genuinely closed gap, verified by executing the command, not by reading
the commit message that claims it.

## Languages

```
$ diff <(ls up/po/*.po | xargs -n1 basename) <(ls po/*.po | xargs -n1 basename)
(empty)
$ diff <(sort up/po/LINGUAS) <(sort po/LINGUAS)
(empty)
```

24/24 `.po` files present on both sides, same filenames, `LINGUAS` matches
the file list on both sides. `.mo` files are committed under `locale/` and
were exercised live by the `de` on-screen check above.

## Unrun checks

- `msgfmt -c` strict validation of the 24 `.po` files was not run this
  round (the nix devshell's `gettext` tooling path was not separately
  checked for `msgfmt -c` specifically, only the `rake gettext:mo:update`
  compile, which the `locale/**/*.mo` files already committed are evidence
  of). Name this as unrun rather than folding it into "parity: true."

## Verdict

The *catalogue* has translation parity: 76/76 keys, 0 gaps, 0 unresolved,
24/24 languages, one language verified rendering on screen. The *port's own
ledger document* does not currently say this, and that mismatch is itself
the finding — see `accountability-ensurance.md`.
