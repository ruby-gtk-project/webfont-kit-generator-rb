# Test parity — webfont-kit-generator-rb

| | |
|---|---|
| Upstream | `origin/master` @ `032df25285cab1c14ef5bfd1e242bcec2157d14f` |
| Port | `ruby` @ `994afff9c734e0a7e3c144514eea3d0b6cc953e9` |

## Upstream has no test suite

`git ls-tree -r --name-only origin/master` has no `test/`, `tests/` directory
and no test target in `meson.build` or `pyproject.toml`. There is nothing
upstream to port. Every check in this port is additional coverage the port
wrote for itself, not a translation of an existing suite.

## What actually runs, re-executed this round

```
nix develop --command xvfb-run -a ruby test/drive_window.rb      → 63 of 63 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_generator.rb   → 92 of 92 checks passed, DRIVE OK — 4 files written
```

63 + 92 = **155**, matching the runtime gate's "155 checks passed, 0 failed."
Unlike an earlier round (recorded in the stale pre-existing
`.reports/test-parity.md` this report supersedes), the two scripts' counts
now both surface in `DRIVE OK` output — the earlier split where
`drive_generator.rb` ran 28 silent `check()`s with no summary line has been
fixed; both scripts now print `N of N checks passed`.

Coverage, read from the two scripts:
- `drive_window.rb`: empty state, loading valid/invalid/garbage files, the
  fonts list and sidebar appearing, output-directory selection (including the
  unwritable-directory rejection path), Generate enablement, `remove-font`,
  returning to empty state, file-chooser actions disabling off the main
  page, the shortcuts dialog, the About dialog, the Google dialog opening,
  and (step 25) `lib/style.rb`'s CSS rules against upstream's `style.css`
  selector-for-selector.
- `drive_generator.rb`: a full font-loading-through-generation run,
  asserting on the written WOFF/WOFF2 files, the generated CSS/HTML
  snippets, and (`verify_log`, `drive_generator.rb:158-165`) five specific
  lines in `lib/log.rb`'s buffer — closing the previously-flagged gap where
  `lib/log.rb` was built but never read by any check.

All 14 `lib/` components are now touched by at least one assertion in one of
the two scripts (`lib/log.rb` and `lib/style.rb`, the two the prior round's
report flagged as unread, are both asserted on now — see the two bullets
above).

## The gap: the advertised spec suite is empty and was never run as part of the gate

The dev shell's own banner (and `spec/README.md`) advertise a third way to
run tests:

```
ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
```

Re-run this round, under `xvfb-run` inside the dev shell:

```
NOTE: kettle-test isn't installed; running with plain RSpec.
No examples found.
Finished in 0.00145 seconds (files took 4.78 seconds to load)
0 examples, 0 failures
```

`spec/` contains only `spec_helper.rb` and `spec/README.md` — there is not a
single `*_spec.rb` file in the repository. The command the project advertises
as "run the specs" passes trivially because there is nothing in it to fail,
not because anything was verified. This is a suite that has never been
executed in the sense of exercising code — it has only ever been executed in
the sense of loading zero files and reporting zero failures.

This matters for the runtime gate specifically: "155 checks passed, 0 failed,
covering 14 components" is entirely `test/drive_*.rb`'s number. The RSpec
suite contributes **0** checks to that number and 0 components to that
coverage, while still being presented in the dev shell banner, in
`spec/README.md`, and by the gemspec's `kettle-test`/`turbo_tests2`/
`anonymous_loader` development dependencies as this project's test
infrastructure. A reader who sees "run the specs" in the banner and "155
checks … 0 failed" in the gate has no signal that the thing the banner calls
"the specs" is empty.

## Verdict

Not fully clean. The `test/drive_*.rb` suite is real, ported-beyond-upstream
coverage that was re-run this round and passed in full (155/155, matching
the gate). But the project's second, explicitly documented test entry point
(`spec/`) is an empty shell that has never asserted anything, and nothing in
the gate's reported numbers distinguishes "155 real checks" from "0 real
checks plus 155 real checks," because the empty suite's 0-examples-0-failures
result looks identical to a passing suite to anyone who does not run it and
read the "No examples found" line.
