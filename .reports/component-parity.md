# Component parity — webfont-kit-generator

| | |
|---|---|
| Upstream | `origin/master` @ `032df25285cab1c14ef5bfd1e242bcec2157d14f` |
| Port | `ruby` @ `58977cad7eea5ffff0c174d764fd3946bb9ad598` |
| Units with full (4-axis) parity | 3 / 5 audited this round |

This round audited the units the runtime gate's drive script actually
exercises, plus the two the prior inventory flagged as caveated
(`google_dialog.rb`, `source_view.rb`), plus the shortcuts dialog, which no
prior report had checked at the signal/accelerator level. It is not a
whole-app re-scan; it is adversarial spot-checking of the claims already on
record.

## Unit: keyboard shortcuts — `webfontkitgenerator/gtk/help-overlay.blp` + `main.py`'s accel table → `lib/shortcuts_window.rb` + `lib/webfont_kit_generator/application.rb`

| Row | Up | Port | Verdict |
|---|---|---|---|
| Show Shortcuts shortcut, `<Control>question` | ✓ | ✓ | parity |
| Open Fonts shortcut, `<Control>o` | ✓ | ✓ | parity |
| Select Output Directory shortcut, `<Control>d` | ✓ | ✓ | parity |
| Google Fonts Importer shortcut, `<Control>g` | ✓ | ✓ | parity |
| **Generate shortcut, `<Control>Return`** | ✓ | **absent from both the dialog and the accel table** | **gap** |

**Gap.** Upstream's `help-overlay.blp` lists a fifth `ShortcutsShortcut`
titled "Generate" bound to `win.generate`, and `main.py`'s `setup_actions`
binds `win.generate` to `<Ctl>Return`. The port's `lib/shortcuts_window.rb`
`SHORTCUTS` constant (4 entries) has no "Generate" row, and
`lib/webfont_kit_generator/application.rb`'s `WINDOW_ACCELS` (also 4
entries: `open`, `google`, `set-dir`, `back`, plus `show-help-overlay`,
which upstream does not even bind as a window accel but the port adds) has
no `generate` key. This is not a documentation-only miss: pressing
Ctrl+Return over the window does nothing in the port, where upstream fires
the Generate action. Behaviour, not just text, is missing.

Located: `lib/shortcuts_window.rb:17-22` (`SHORTCUTS` hash); the correct
fifth key would be `'Generate' => '<Control>Return'`.
`lib/webfont_kit_generator/application.rb:34-40` (`WINDOW_ACCELS` hash); the
missing key is `'generate' => ['<Control>Return']`.

No drive check exercises accelerators at all (`drive_window.rb` invokes
`win.generate` as an action directly, never through the keyboard), so this
gap passed the runtime gate.

## Unit: Google Fonts importer — `webfontkitgenerator/google.blp` + `google.py` → `lib/google_dialog.rb`

| Axis | Verdict |
|---|---|
| Widgets (dialog, stack, header, status pages, entry, revealer, progress bar, buttons) | parity — matches `google.blp`'s tree widget-for-widget |
| CSS (`flat`, `error`, `suggested-action`, `pill`) | parity |
| Signals (`changed`, `icon-press`, `clicked` ×2) | parity |
| HTTP transport | **correspondence, now resolved** — upstream uses libsoup 3 directly; the port now also uses libsoup 3 through the `soup3` gem (`require 'soup3'`, `lib/google_dialog.rb:8`), with the gem wired into the gemspec, `nix/Gemfile` and `flake.nix`'s `gtkStack` (`libsoup_3`). The prior inventory's Soup caveat is closed. |
| Text | not re-audited here; folded into the total translation-parity failure below — every string in this file (`'Please set a valid url'`, `"Couldn't find the #{family.name} font family."`, etc.) is a bare literal, unmarked, with no upstream msgid survival |

Driven: `test/drive_window.rb` checks 6-9 (url validation, both CSS API
shapes, error label, download enable/disable). No check drives an actual
network response (success, 304-not-modified, or failure) through
`on_database_response`/`on_font_downloaded` — the download/error paths
(`fail_with`, `use_local_or_fail`, `write_font`'s rescue) are built but
unexercised by any check. Not a code gap by itself, but it means "parity"
on this unit rests on reading the code, not on a passing assertion, for
roughly half of it.

## Unit: generated-code preview — `webfontkitgenerator/sourceview.py` → `lib/source_view.rb`

| Axis | Verdict |
|---|---|
| Widget type | **gap, open** — upstream subclasses `GtkSource.View`; the port is a plain `Gtk::TextView` |
| CSS (`sourceview`) | parity (class name reproduced) |
| Signals (`notify::dark` on the style manager, to re-apply the palette) | parity in spirit — correctly tracks light/dark |
| Behaviour: syntax highlighting | **gap** — upstream gets HTML/CSS lexing and Adwaita/Adwaita-dark style schemes for free from GtkSourceView's `LanguageManager`/`StyleSchemeManager`. The port reimplements it with four hand-written regexes per language (`RULES` in `lib/source_view.rb:43-54`) and a 4-entry colour table (`PALETTE`), which is a materially smaller rule set than a real lexer's (no comments, no nesting, no malformed-markup recovery) |
| Behaviour: line-number gutter | **gap** — upstream's `GtkSource.View` draws one; a bare `Gtk::TextView` has no gutter to draw into, and the port adds none |

**This is marked a gap, not a correspondence**, because the stated reason
("There are no Ruby bindings for GtkSourceView 5") is false — see
`.reports/accountability-ensurance.md`. The `gtksourceview5` gem exists on
RubyGems (confirmed: `gem list -r gtksourceview` lists `gtksourceview5
(4.4.0)` from this fork's own `nix develop` shell). It is simply not in
`webfont-kit-generator-rb.gemspec`, not in `nix/Gemfile`, and
`flake.nix`'s `gtkStack` has no GtkSourceView/`gtksourceview5` package —
the identical shape of gap that the Soup dependency had, and that one *was*
fixed (see the Google importer unit above). This one was not.

Driven: `test/drive_generator.rb` checks that `window.src_html`/
`window.src_css` contain the expected substrings (lines 152-153), which
proves the *text* is right but asserts nothing about highlighting or the
gutter — a check that this widget shows the right bytes, not that it is the
right widget.

## Unit: main window — `webfontkitgenerator/window.blp` + `window.py` → `lib/window.rb`

Audited only on the axes the drive script actually reaches (empty state,
app menu, help/about actions, font loading, output-dir picking, remove-font,
page navigation) — all pass, per `test/drive_window.rb` checks 0-24 (62/62).
Not re-derived widget-by-widget against the `.blp` in this pass; the prior
`.reports/component-inventory.md` already did the file-level mapping and
nothing found here contradicts it. The one gap inside this unit is the
missing `win.generate` accelerator, reported under the shortcuts unit
above since that is also where the dialog-side half of the gap lives.

## Unit: the generation log — `webfontkitgenerator/log.py` → `lib/log.rb`

Not exercised by any check in either drive script. `lib/generator.rb` calls
`@window.log.reset` and `@window.log.append(text, bold:, italic:)`
(`lib/generator.rb:1164,1469`) during a real drive run
(`test/drive_generator.rb`), so the widget receives real calls — but no
`check(...)` anywhere reads `window.log`'s buffer text to confirm the lines,
the bold/italic markup, or the ordering match what upstream's `log.py`
would have produced. Per this audit's brief ("a component no check
exercises is unverified, not done"): **this component is unverified**, not
confirmed at parity and not confirmed broken.

## Unit: the stylesheet — `webfontkitgenerator/style.css` → `lib/style.rb`

Not diffed rule-by-rule in this pass. `component-parity`'s Step 4 calls for
a literal diff between the two stylesheets (accounting for build-time
tokens and Adwaita named colours); that diff was not run this round, so
this unit's CSS axis is **unverified**, not confirmed clean.

## Summary of this round's gaps

| Gap | Where | Severity |
|---|---|---|
| `win.generate` keyboard shortcut and its dialog entry are entirely absent | `lib/shortcuts_window.rb:17-22`, `lib/webfont_kit_generator/application.rb:34-40` | behaviour gap — a bound upstream key does nothing in the port |
| GtkSourceView not wired despite being available; highlighting and gutter are a reduced reimplementation | `lib/source_view.rb` | feature gap, falsely excused (see accountability report) |
| Every user-visible string in every unit above (and the rest of `lib/`) is unmarked and untranslated | all of `lib/` | see `.reports/translation-parity.md` — total, not partial |
| `lib/log.rb` and `lib/style.rb` carry no asserting check | — | unverified, not a confirmed pass |

None of the units audited this round reach full 4-axis parity without at
least one open row.
