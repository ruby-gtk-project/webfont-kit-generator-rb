# Component parity — webfont-kit-generator-rb

| | |
|---|---|
| Upstream | `origin/master` @ `032df25285cab1c14ef5bfd1e242bcec2157d14f` |
| Port | `ruby` @ `994afff9c734e0a7e3c144514eea3d0b6cc953e9` |

Each unit from `component-identification.md` compared line-by-line against
its upstream `.blp`/`.py`.

## Window (`window.blp`/`window.py` vs `lib/window.rb`) — PASS

Verified against the full text of `window.blp`: every widget, every CSS
class (`title-1`, `suggested-action`, `pill`, `content`, `heading`,
`bottom-box`), every `styles [...]` block, the full `app-menu` (two sections,
three items: Import from Google Fonts, Keyboard Shortcuts, About), and the
stack page names (`main`/`progress`/`finished`, `empty`/`fonts`,
`info`/`log`) all have a corresponding line in `lib/window.rb`. Signals
checked: `notify::visible-child-name` on both `appstack` and (indirectly,
via `check_ready_state`) the fonts stack; `clicked` on cancel and
open-in-files; the drop target's `drop` signal.

Two documented, deliberate deviations, both explained in-file and neither
hiding a missing feature:
- `Adw.ApplicationWindow` → `Gtk::ApplicationWindow` (binding is broken; the
  comment at `lib/window.rb:23-26` states this, and the drive suite exercises
  the resulting window normally).
- The cancel button's `clicked` handler is connected once instead of once
  per generation (`lib/window.rb:508-511`) — a fix for an upstream handler
  leak, not a gap.

`win.show-help-overlay` is bound as a window action here even though
upstream relies on GTK's built-in default for that action name; functionally
identical, confirmed by the drive suite opening the shortcuts dialog
(`test/drive_window.rb` step "show-help-overlay opens the shortcuts
dialog").

## Options (`options.blp`/`options.py` vs `lib/options.rb`) — PASS

All eight subsetting ranges (`latin`, `latin-ext`, `cyrillic`,
`cyrillic-ext`, `greek`, `greek-ext`, `vietnamese`, `devanagari`), their
two-column layout (`LEFT_SUBSETS`/`RIGHT_SUBSETS`, `lib/options.rb:81-82`),
the custom-range entry and its placeholder, the format checkboxes, Base64
switch and font-display dropdown all present with matching titles and
subtitles.

## Google Fonts dialog (`google.blp`/`google.py` vs `lib/google_dialog.rb`) — PASS, one runtime detail unverified

State machine present in full: entry validation (`on_entry_changed`,
`check_url`, v1/v2 URL parsing, `invalid_url`/`valid_url` CSS+revealer
toggling), ETag-cached database fetch (`database_message`,
`store_database`, `google-fonts-sha` settings key — matches upstream's
`If-None-Match` handling), progress bar pulse-then-determinate behaviour
(`step_progressbar`), per-file download and tmp-file write with
per-font error collection, and dialog termination that either hands the
window the downloaded fonts or toasts the collected errors
(`terminate_dialog`). Cancel wired through `Gio::Cancellable`.

Not independently re-verified: an actual network round-trip against the
live Google Fonts API (no such call is made by `test/drive_*.rb`, by design —
see `test-parity.md`). The code path was read, not executed with a real
network response.

## Shortcuts dialog — PASS with a documented substitution

`Gtk.ShortcutsWindow` cannot be constructed from the Ruby GTK4 bindings
(verified: constructing one raises "GtkWindow is not subtype of
GtkShortcutsWindow"). The port substitutes `Adw.ShortcutsDialog` with the
same five shortcuts, same titles (`msgctxt "shortcut window"` context
preserved via `p_('shortcut window', title)`), same accelerators as
`main.py`'s `set_accels_for_action` calls — including a correction: upstream
writes `<Ctl>o` etc. (not a modifier GTK recognizes; the `<Ctl>` accelerator
upstream advertises never fires), the port correctly uses `<Control>`.

## Application / About dialog — PASS

`about` action, all five upstream accelerators plus the explicit
`show-help-overlay` one, `HANDLES_OPEN` equivalent (`open_files`), About
dialog fields (name, icon, version, developer, license, website, issue URL,
the two metainfo paragraphs kept as two separate msgids, translator
credits) all present.

## Font / FontRow / Log / SourceView / Style / Generator / Loader / Settings — PASS

Each read against its upstream counterpart; no missing widget, signal, or
action found. `lib/source_view.rb` now builds on the real `gtksourceview5`
gem (`GtkSource::View`, real lexing, style-scheme switching, the
line-number gutter) — this closes the gap the prior
`.reports/accountability-ensurance.md` (pre-existing, now superseded)
recorded against an earlier commit; `gtksourceview5` is in the gemspec,
`nix/Gemfile`, and `flake.nix`'s `gtkStack`, and `require 'gtksourceview5'`
succeeds in the dev shell. `lib/log.rb`'s buffer is asserted on by
`test/drive_generator.rb`'s `verify_log` (checked at the specific lines,
see `test-parity.md`) and `lib/style.rb`'s CSS rules are asserted
selector-for-selector against upstream's `style.css` by
`test/drive_window.rb` step 25.

## Verdict

No missing window, dialog, page, menu item, keyboard shortcut, action,
preference, empty state, or error state found. The two substitutions
(`Gtk::ApplicationWindow`, `Adw.ShortcutsDialog`) are binding-forced and
documented, not gaps. See `translation-parity.md` and
`accountability-ensurance.md` for gaps that are not about widget shape —
the extraction tooling behind the translated strings, and the gap between
what the runtime gate executed and what it is described as covering.
