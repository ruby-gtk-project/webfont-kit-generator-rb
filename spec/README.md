# Specs

This project uses `kettle-test` as its RSpec harness. The generated
`spec/spec_helper.rb` requires `kettle/test/rspec`, which installs the shared
test configuration and helper APIs used throughout the suite.

`spec_helper.rb` requires `webfont_kit_generator`, which requires `gtk4` at
its top — the same as `exe/webfont-kit-generator` and `test/drive_*.rb` — so
the suite needs a display the same way they do. From the dev shell:

```
xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
```

The examples under `spec/*_spec.rb` are unit-level coverage of `lib/font.rb`,
`lib/options.rb`'s `UnicodeRanges`/subset tables, and `lib/generator.rb`'s
`Subset`/`Tables`/`Woff`/`Woff2`/`Brotli` — the pieces
`test/drive_window.rb` and `test/drive_generator.rb` only ever exercise
indirectly, through a whole built window or a whole threaded generation run.

## Harness Helpers

These helpers are available in specs after `spec/spec_helper.rb` loads:

- `stub_env("NAME" => "value")` temporarily sets environment variables and
  restores them after the example.
- `hide_env("NAME")` temporarily removes environment variables and restores
  them after the example.
- `block_is_expected` supports expectation syntax for blocks.
- `:check_output` disables default stream silencing for examples that need to
  assert output.
- `:freeze` and `:travel` metadata integrate with Timecop for example-level
  time control.
- `:skip_global_travel` opts an example out of global time travel.
- `pending_for` marks examples pending for selected runtimes or dependency
  versions.
- `include_context "with rake", "task_name"` is available when `rake` was
  loaded before `kettle/test/rspec`.

Prefer these helpers over ad hoc ENV mutation, direct Timecop setup, or direct
stdout/stderr plumbing. They keep specs isolated across parallel workers and
make local runs match CI behavior.
