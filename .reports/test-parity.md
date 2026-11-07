# Test parity — webfont-kit-generator

| | |
|---|---|
| Upstream | `origin/master` @ `032df25285cab1c14ef5bfd1e242bcec2157d14f` |
| Port | `ruby` @ `58977cad7eea5ffff0c174d764fd3946bb9ad598` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |
| Test command | none exists — see below |

## Upstream has no test suite

Verified directly: `git ls-tree -r --name-only origin/master | grep -i test`
returns nothing. No `tests/` directory, no `unittest`/`pytest` imports in
any `.py` file, no test target in `meson.build` or `pyproject.toml`. Parity
is 0/0 and is met trivially, per `test-parity`'s own rule for this case.

**The port therefore inherits no safety net from upstream.** Everything
below is extra, written for the port, pinning nothing upstream considered
worth pinning, and not a substitute for the census this skill exists to
run.

## The port's own test setup is, on inspection, two things wearing one name

`spec/` is kettle-jem's generated RSpec scaffold and nothing else:

```
spec/README.md       — documents harness helpers (stub_env, hide_env, …)
spec/spec_helper.rb   — requires kettle/test/rspec, configures RSpec
```

**There is not one `*_spec.rb` file in the repository.** `bundle exec
rspec` (or the banner's `ruby -e 'require "rspec/core"; …'`) runs and
reports **0 examples, 0 failures** — a green RSpec run that has executed
nothing. That is a suite that has never meaningfully run, and per this
audit's brief it is reported as exactly that, not folded into "tests pass."

## What actually exists: two driver scripts, not a test suite

```
test/drive_window.rb      — 62 check() calls, prints "N of N checks passed"
test/drive_generator.rb   — 28 check() calls, raises on failure, prints nothing on success
test/gtk_driver.rb        — shared headless-driving helper (harness, not tests)
```

Both were run for this audit, from this fork's own dev shell:

```
nix develop --command xvfb-run -a ruby test/drive_window.rb     -> 62 of 62 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_generator.rb  -> DRIVE OK — 4 files written (no per-check output)
```

Two things follow from reading the scripts rather than trusting the banner:

1. **`drive_generator.rb`'s 28 checks are invisible in any gate report.**
   Its `check(condition, message)` (`test/drive_generator.rb:415-419`)
   `raise`s on failure and prints **nothing** on success — there is no
   counter, no "N of N" line. The round's runtime gate ("62 checks passed,
   0 failed") is arithmetically `drive_window.rb`'s count alone; the 28
   checks in `drive_generator.rb` ran, and this audit confirmed they
   passed, but no artifact in this repo records that they exist or that
   they passed, short of reading the source and re-running it. A gate
   number quoted as "the" check count, when it is actually one of two
   scripts' counts, is the kind of narrow-drive-read-as-broad this audit
   was told to flag.

2. **Two of the fourteen inventoried `lib/` components are exercised by
   neither script's checks**: `lib/log.rb` (receives calls during
   `drive_generator.rb` but nothing reads its buffer back — see
   `.reports/component-parity.md`) and `lib/style.rb` (never diffed or
   asserted against upstream's CSS at all). Per this audit's brief, these
   are **unverified**, not passing.

## Extra

- `test/drive_window.rb` — 62 checks driving the window, the app menu, the
  shortcuts/about dialogs, the Google Fonts importer's URL parsing and
  error states, the options sidebar's reporting, font loading (good path,
  unreadable path, non-font path), output-directory picking (writable and
  unwritable), font removal, and page-navigation sensitivity.
- `test/drive_generator.rb` — 28 checks end-to-end generating a real WOFF
  and WOFF2 from a sample font and verifying both containers byte-for-byte
  (sfnt checksum reconstruction, woff/woff2 header fields, per-table
  checksums, Brotli-decompressed stream lengths, transform flags) plus the
  emitted HTML/CSS snippet text.

These are real and substantial — the generator's binary-format checks in
particular are the kind of test upstream's own suite (which does not exist)
never had reason to write. They are listed here as extra, not as parity,
because upstream wrote none of them and so none of them map back to an
upstream test by this skill's definition.

## Rules check

- No upstream test was lowered, merged, or skipped — there were none to
  touch.
- The "0/0, met trivially" state is stated plainly, per the skill's own
  instruction for this case, rather than left to be inferred from an
  absent table.
- The RSpec scaffold's 0-examples state is named explicitly above rather
  than allowed to stand in silently for "has a test suite."
