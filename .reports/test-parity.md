# Test parity — webfont-kit-generator-rb

| | |
|---|---|
| Upstream | `origin/master` @ `032df25285cab1c14ef5bfd1e242bcec2157d14f` |
| Port | `ruby` @ `6893c450641b22b129f7b5386dc08e4ed4a7b6e7` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |
| Test commands | `nix develop --command xvfb-run -a ruby test/drive_window.rb`, `test/drive_generator.rb`, `test/drive_google_fonts.rb`, and `nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run([...])'` |

Upstream has no test suite. Re-verified this round against a fresh
`origin/master` worktree: `test-census.sh` returns 0 rows, there is no
`webfontkitgenerator/test*.py`, no `pytest.ini`, no test target in
`meson.build` or `data/meson.build`, and no `tests/` directory anywhere in
`git ls-tree -r --name-only origin/master`. Parity is **0/0, met trivially**.
**The port therefore inherits no safety net from upstream** — every check
below was written for the port and pins nothing upstream ever considered
worth pinning.

## All four test entry points re-executed this round from the working tree

```
$ nix develop --command xvfb-run -a ruby test/drive_window.rb
63 of 63 checks passed
DRIVE OK

$ nix develop --command xvfb-run -a ruby test/drive_generator.rb
92 of 92 checks passed
DRIVE OK — 4 files in <tmpdir>/kit

$ nix develop --command xvfb-run -a ruby test/drive_google_fonts.rb
8 of 8 checks passed
(exit 0)

$ nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
51 examples, 0 failures
```

63 + 92 + 8 = **163**, matching this round's runtime gate ("163 checks
passed, 0 failed") exactly, by direct re-execution in this session rather
than by reading the number anywhere. The RSpec run is a distinct, additional
51 examples (`spec/font_spec.rb`, `spec/generator_spec.rb`,
`spec/unicode_ranges_spec.rb`) not counted in the drive scripts' 163 — the
gate's figure is the three `check()`-counting drive scripts only.

`test/drive_google_fonts.rb` makes a real network round trip (a live GET
against the Google Fonts API, a real font-file download, assertions on the
real bytes that came back) and is designed to skip itself cleanly when there
is no network; this round it ran to completion against a live connection and
all 8 checks passed, so the "a suite that has never been executed" trap this
round's brief warns about does not apply to it here — it was executed, not
assumed. Noted for completeness: the script prints several GTK
`Gtk-CRITICAL`/`Gtk-WARNING` allocation messages to stderr under the Xvfb
display used here (zero-width stack measurement during the second window
build); these are the same class of warning `drive_generator.rb` also prints
under the identical headless display, the process still exits 0, and all 8
checks pass — read as an Xvfb/offscreen-rendering artifact, not a functional
defect, but recorded rather than silently discarded.

## Extra

- `test/drive_window.rb` — 63 checks: app-menu structure, shortcuts dialog,
  about dialog, Google importer construction and URL/CSS-API validation,
  custom-subset live validation, options reporting, font loading
  (good/bad/garbage paths), directory selection (writable/unwritable),
  remove-font, page-navigation action enablement, and a selector-level CSS
  diff against upstream's `style.css`.
- `test/drive_generator.rb` — 92 checks: the full subset→WOFF/WOFF2→CSS
  generation pipeline run against a real font file under a real Xvfb
  display, with the window actually built and `Gio::Application#run` driven
  (not stubbed).
- `test/drive_google_fonts.rb` — 8 checks: a live network round trip against
  the real Google Fonts API — a real GET, a real per-file font download, and
  assertions on bytes that actually came back over the wire.
- `spec/font_spec.rb`, `spec/generator_spec.rb`, `spec/unicode_ranges_spec.rb`
  — 51 examples, covering the same units at a finer grain than the drive
  scripts reach (unit tests of `Font`, `UnicodeRanges`, `Generator`'s format
  helpers).

None of this is parity work by this skill's definition — it is extra,
staying extra, because upstream pinned nothing for the port to inherit. It
is real coverage, and all four entry points were re-run end to end this
round rather than cited from a previous report or commit message.

## Verdict

0/0 upstream tests, met trivially — no gap, no inherited safety net. The
port's own four-part suite (163 drive checks + 51 rspec examples, 214 total
assertions) passed in full under a fresh re-execution this round, across all
components the drive scripts reach: window, options, Google importer
(including a live network path), shortcuts dialog, about dialog, generator
pipeline, font loading, and style parity.
