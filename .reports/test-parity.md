# Test parity — webfont-kit-generator-rb

| | |
|---|---|
| Upstream | `master` @ `032df25` |
| Port | `ruby` @ `ea115ca` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |
| Test commands | `nix develop --command xvfb-run -a ruby test/drive_window.rb`, `nix develop --command xvfb-run -a ruby test/drive_generator.rb`, `nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run([...])'` |

Upstream has no test suite (verified this round: `find /tmp/wkg-audit/upstream
\( -iname '*test*' \)` returns nothing, `meson.build` and `data/meson.build`
declare no test target, and there is no `webfontkitgenerator/test*.py`, no
`pytest.ini`, no CI test job beyond lint). Parity is **0/0, met trivially**.
**The port therefore inherits no safety net from upstream** — every check
below was written for the port and pins nothing upstream ever considered
worth pinning.

## All three test entry points re-executed this round, not assumed

A prior round's `accountability-ensurance.md` flagged that the dev shell's
"run the specs" banner advertised an RSpec command that resolved to `0
examples, 0 failures` — a suite that had never been written, reading
identical to a passing one. That gap has since been closed (commit
`3b83bef`) and this round re-ran all three commands from a clean worktree
to confirm it stayed closed rather than trusting the commit message:

```
$ nix develop --command xvfb-run -a ruby test/drive_window.rb
63 of 63 checks passed
DRIVE OK

$ nix develop --command xvfb-run -a ruby test/drive_generator.rb
92 of 92 checks passed
DRIVE OK — 4 files in <tmpdir>/kit

$ nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
51 examples, 0 failures
```

63 + 92 = **155**, matching the runtime gate's "155 checks passed, 0 failed"
exactly — confirmed by direct re-execution in this session, not by reading
the number in a report. The RSpec run is a distinct, additional 51 examples
across `spec/font_spec.rb`, `spec/generator_spec.rb`,
`spec/unicode_ranges_spec.rb` — the gate's "14 components" figure does not
include these, and they are unit-level (no window built), which is why they
run faster and exercise paths the window-driving scripts reach only
incidentally (e.g. `UnicodeRanges.parse` edge cases, `Font`'s metadata
extraction, `Generator`'s `Subset`/`Tables`/`Woff`/`Woff2`/`Brotli` helpers
in isolation).

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
- `spec/font_spec.rb`, `spec/generator_spec.rb`, `spec/unicode_ranges_spec.rb`
  — 51 examples, added this round, covering the same units at a finer grain
  than the drive scripts reach (unit tests of `Font`, `UnicodeRanges`,
  `Generator`'s format helpers).

None of this is parity work by this skill's definition — it is extra,
staying extra, because upstream pinned nothing for the port to inherit. It
is, however, real coverage, and it was re-run end-to-end this round rather
than cited from a previous report.
