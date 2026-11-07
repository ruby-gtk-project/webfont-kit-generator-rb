# Accountability ensurance — webfont-kit-generator-rb

| | |
|---|---|
| Upstream | `origin/master` @ `032df25285cab1c14ef5bfd1e242bcec2157d14f` |
| Port | `ruby` @ `994afff9c734e0a7e3c144514eea3d0b6cc953e9` |

Manual grep for `TODO|FIXME|not implemented|for now|in a future|no ruby
bindings|not supported|unsupported|skipped|placeholder|deliberately|out of
scope|by design` over `lib/`, `exe/` and `.reports/`, plus reading every hit
in context (there is no `PORTING.md` on this branch to grep).

## No open excuse found in `lib/`/`exe/`

The pattern hits in `lib/` are all benign on inspection:
- `placeholder_text` (`lib/google_dialog.rb:180`, `lib/options.rb:290`) is
  the GTK entry API, not an excuse.
- `lib/log.rb:6`'s "skipped work" is prose describing what the log widget's
  italic style is *for* (upstream behaviour it reproduces), not a skipped
  port task.
- `lib/generator.rb:32`, "Two upstream behaviours are deliberately not
  reproduced" — read in full, both are documented *bug fixes* to upstream
  (a broken Python string-interpolation that always logged the literal text
  `<class 'range'>`, and a signal-handler leak from reconnecting `clicked`
  on every run), not missing functionality. This is the opposite of an
  excuse: a correction, with the upstream bug quoted and the fix explained.
  Verified directly against `webfontkitgenerator/generator.py`'s
  `text = range if range else name` — the bug is real, and the port's fix is
  real.

The one claim flagged by the pre-existing `.reports/accountability-ensurance.md`
from an earlier commit — that `lib/source_view.rb` falsely claimed "no Ruby
bindings for GtkSourceView 5" to excuse a hand-rolled `Gtk::TextView` — **no
longer applies**. Read at the current commit, `lib/source_view.rb` now
`require 'gtksourceview5'`s and subclasses `GtkSource::View` directly
(`lib/source_view.rb:4,15`), with the gem wired into the gemspec, `nix/Gemfile`
and `flake.nix`'s `gtkStack`. That gap, and the comment that excused it, are
both gone. Carrying the old finding forward as current would itself have
been a false reading of this round.

## Two real false-green risks, found by executing rather than reading

Neither is a sentence anywhere in this repo claiming something is done when
it was skipped — this branch has no `PORTING.md` to carry that kind of
sentence, and nothing in `lib/`/`exe/` asserts test or translation
completeness in prose. Both are the quieter version of the same failure
mode: a number or a banner line that reads as proof of coverage to someone
who does not re-run the thing behind it.

**1. The runtime gate's "155 checks … 0 failed" is real, but a second,
equally-advertised test entry point contributes nothing to it and looks
identical to a passing suite if you don't look closely.** Full detail in
`test-parity.md`. In short: `test/drive_window.rb` (63) and
`test/drive_generator.rb` (92) really do sum to 155 and really did pass this
round, re-executed start to finish. But the dev shell's own banner also
advertises `ruby -e '... RSpec::Core::Runner.run(...)'` as "run the specs,"
and that command, re-run this round, printed `0 examples, 0 failures` —
there is not one `*_spec.rb` file in the repository. `0 examples, 0
failures` and `155 of 155 passed` both read as "nothing failed." Only one of
them means something was checked.

**2. The translation catalogue's completeness is real, but was verified by
diffing committed files, not by running the maintenance command the project
documents for producing them — and that command, run for real this round,
turns out to lose 15 real msgids.** Full detail in `translation-parity.md`.
`rake gettext:pot:create`, the Rakefile's own documented way to regenerate
`po/webfontkitgenerator.pot` from `lib/**/*.rb`, silently drops "Webfont
Bundler", the eight subset-range names, and five shortcuts-dialog/menu
strings, because they reach `_()`/`p_()` through a variable
(`_(TITLE)`, `_(SUBSET_TITLES.fetch(name))`, a loop over `SHORTCUTS`) rather
than a literal. The committed `.pot` matches upstream only because it was
carried over wholesale, not because the tooling can reproduce it — verified
by actually running the task (output discarded, working tree restored with
`git checkout -- po/webfontkitgenerator.pot`, confirmed clean via `git
status --short`) and diffing the result.

Writing finding 2 the way this skill asks for:

> I did not notice that `_(TITLE)`, `_(APP_NAME)`, `_(SUBSET_TITLES.fetch(name))`
> and the `p_('shortcut window', title)` loop make 15 real, translated,
> user-visible strings invisible to `rake gettext:pot:create`, because I
> verified translation parity by diffing the committed `.pot` against
> upstream's instead of actually running the extraction command the project
> documents as the way to produce it.
> Upstream: every msgid upstream's `.pot` carries is reachable by its own
> `xgettext`/`blueprint-compiler` extraction, because its equivalents are
> either literal `_()` calls or `.blp` strings a different extractor reads.
> Port: 15 of those same msgids only exist in `po/` because they were copied
> over when the port was written; the Ruby extraction pipeline that is
> supposed to maintain them cannot see them.

## Verdict

Not clean. One previously-recorded false technical claim (the GtkSourceView
binding excuse) has been fixed since it was written and does not survive at
the current commit — correctly recording that required actually diffing
the fix against the old finding rather than assuming the old report still
applied. Two new, unexcused false-green risks were found this round by
executing the commands the project documents rather than trusting its
committed artifacts: an empty RSpec suite advertised as "the specs," and a
translation-extraction task that, run for real, loses 15 msgids the shipped
catalogue currently carries.
