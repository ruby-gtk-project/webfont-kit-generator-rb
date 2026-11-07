# Translation parity — webfont-kit-generator

| | |
|---|---|
| Upstream | `origin/master` @ `032df25285cab1c14ef5bfd1e242bcec2157d14f` |
| Port | `ruby` @ `58977cad7eea5ffff0c174d764fd3946bb9ad598` |
| Upstream msgids (incl. the `msgid ""` header) | 73 (72 real messages) |
| Ported msgids | **0** |
| Gaps | **72 / 72** |
| Languages upstream ships (`po/LINGUAS`) | 24 |
| Languages the port builds | **0** |

## The key sets are not equal — they do not overlap at all

```
$ git show origin/master:po/webfontkitgenerator.pot | grep -c '^msgid "'
73
$ grep -rc "gettext\|_(\"" lib/*.rb exe/*
<every file: 0>
```

Censused with `translation-parity/scripts/msgid-census.sh` against a clean
`git archive origin/master` extraction and against a clean `git archive
HEAD` (the `ruby` branch) extraction of this same repo:

```
upstream tree: 1,880 rows (73 distinct msgids × ~24 .po files + the .pot + the .blp sources)
port tree:     0 rows
```

**Every one of the 72 real upstream messages is a gap.** There is no
partial credit to report: no string in `lib/` or `exe/` goes through a
translation marker of any kind — no `_()`, no `n_()`, no `C_()`, no
`gettext`/`fast_gettext`/`ruby-gettext` require anywhere in the port.
`grep -rn "gettext" lib/ exe/` returns nothing. Every user-visible string
is a bare Ruby literal:

```ruby
# lib/google_dialog.rb:154-155
page.title = 'Import from Google Fonts'
page.description = 'Download fonts from Google Fonts for self-hosting'

# lib/shortcuts_window.rb:36
dlg.title = 'Keyboard Shortcuts'

# lib/options.rb, lib/window.rb, lib/log.rb, lib/font_row.rb — same pattern throughout
```

Representative upstream msgids with no port counterpart at all (a sample of
the 72, not the full list — the full list is every string in every `.py`
and `.blp` file upstream ships):

| msgid | Where upstream marks it |
|---|---|
| `_About Webfont Bundler` | `webfontkitgenerator/window.blp:23` |
| `Add some fonts` | window empty state |
| `Import from Google Fonts` | `google.blp` |
| `Download fonts from Google Fonts for self-hosting` | `google.blp` |
| `Please set a valid url` | `google.py` |
| `Couldn't find any fonts for the given url.` | `google.py` |
| `Generate` (shortcut-window `C_("shortcut window", "Generate")`) | `help-overlay.blp` |

## The languages do not come with it

Upstream's `po/` holds 24 translated catalogues plus the template:

```
ar ca cs de es et fa fi fr gl hi hr ka kk nl oc pt pt_BR ru sk sv tr uk zh
```

The port has:

```
$ find . -iname '*.po' -o -iname 'LINGUAS' -not -path './.git/*'
<nothing>
```

No `po/` directory, no `LINGUAS`, no build step that would install a
`.mo`. Every one of those 24 languages' existing translations of this app
is unreachable from the port — not because any msgid changed and broke the
lookup, but because there is no lookup at all. A user running the port in
any of the 24 languages upstream supports sees the same English the port
shows everyone.

## This is a total failure, not a partial one

`translation-parity`'s own worked example (planify-rb, 0 translated against
upstream's extensive catalogue) is the closest comparison, and this port is
in the same state: **0 of 72 msgids survived, 0 of 24 languages ship.**
There is no byte-identity question to adjudicate (no msgid differs — none
exists), and no moved-string question either (no string was relocated to
another file under a translation marker; none carries a marker anywhere).

## What this means for the other ledgers

`.reports/component-parity.md`'s per-unit "Text" axis is marked as folded
into this total failure rather than scored per-widget, because per-widget
scoring would imply some widgets pass and others do not. None do. Every
widget in every unit shows an untranslated, unmarked string.

## Rules check

- No msgid was reworded to make a false match; none exist on the port side
  to compare.
- This report does not cite `.reports/component-inventory.md`'s line
  ("translation parity is a separate skill's job, not this inventory's")
  as authority for the gap — that line correctly scoped what the prior
  inventory covered, and this report is exactly the skill it deferred to,
  landing a total gap, not an excuse for one.
