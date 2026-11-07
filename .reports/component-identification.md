# Component identification — webfont-kit-generator-rb

| | |
|---|---|
| Upstream | `origin/master` @ `032df25285cab1c14ef5bfd1e242bcec2157d14f` |
| Port | `ruby` @ `994afff9c734e0a7e3c144514eea3d0b6cc953e9` |

Upstream has no `.ui`/`.blp`-free widgets of consequence — every window and
dialog is declared in blueprint and backed by a `.py` class. That gives a
reliable file-to-file join. Unit boundaries below are one upstream
`.py`+`.blp` pair (or `.py` alone) mapped to one `lib/*.rb` file, read in the
order a user meets them.

## Window — `webfontkitgenerator/window.py` + `window.blp` → `lib/window.rb`

Top-level `Adw.ApplicationWindow` (`Gtk::ApplicationWindow` in the port —
`Adwaita::ApplicationWindow` is broken in the Ruby bindings, documented at
`lib/window.rb:23-26`). Contains:

- `Gtk.Stack appstack` (main / progress / finished) — ported 1:1, same page names.
- Main page: `HeaderBar` (add-fonts button, menu button + `app-menu`
  `Gio::Menu` with the Google-import and help sections), `Adw.OverlaySplitView`
  holding the fonts `Gtk.Stack` (empty / fonts pages, each widget and CSS
  class reproduced, `lib/window.rb:212-271`) and the `Options` sidebar, and the
  bottom `Gtk.ActionBar` (directory label, Browse, Generate).
- Progress page: `Adw.StatusPage` → `ProgressBar` + Cancel button.
- Finished page: `Adw.ToolbarView` with a `HeaderBar`+`Adw.ViewSwitcher`,
  `Adw.ViewStack` with an Info page (two `$SourceView`s, Open-in-Files button)
  and a Log page (`$Log`).
- Window actions: `set-dir`, `open`, `google`, `generate`, `back`,
  `show-help-overlay`, `remove-font` (parameterised) — all seven present in
  `Window::ACTIONS` + `remove_font_action` (`lib/window.rb:36,590-611`),
  matching upstream's `setup_actions` in `window.py`.
- `Gtk.DropTarget` for file drag-and-drop onto the main page.

## Options sidebar — `webfontkitgenerator/options.py` + `options.blp` → `lib/options.rb`

`Adw.PreferencesPage`-shaped sidebar: Options group (format checkboxes),
Subsetting switch + two-column range checkboxes (Latin/Latin-Ext,
Cyrillic/Cyrillic-Ext, Greek/Greek-Ext, Vietnamese/Devanagari, plus a custom
range entry), CSS group (Base64 switch, font-display dropdown).

## Google Fonts importer — `webfontkitgenerator/google.py` + `google.blp` → `lib/google_dialog.rb`

`Adw.Dialog` with a `Gtk.Stack` of two pages: main (URL entry with paste/clear
icon, inline error `Gtk.Revealer`, Download button) and loading
(`Adw.StatusPage`, `ProgressBar`, Cancel). State machine: entry validation →
database fetch (with `If-None-Match`/ETag caching against
`google-fonts-sha`) → family/variant resolution from both legacy and v2
Google Fonts CSS URLs → per-file download → write to tmp files → hand off to
`Window#load_fonts` or toast the collected errors.

## Shortcuts — `webfontkitgenerator/gtk/help-overlay.blp` → `lib/shortcuts_window.rb`

Five shortcuts in one "General" group: Show Shortcuts, Open Fonts, Select
Output Directory, Google Fonts Importer, Generate. `Gtk.ShortcutsWindow`
cannot be constructed from the Ruby bindings (documented, verified by the
raised error quoted at `lib/shortcuts_window.rb:14-17`), so the port uses
`Adw.ShortcutsDialog` instead — same five entries, same accelerators.

## Application — `webfontkitgenerator/main.py` → `lib/webfont_kit_generator/application.rb`

`about` action, five window accelerators (`open`, `google`, `set-dir`,
`generate`, `back`) plus a sixth the port adds explicitly
(`show-help-overlay`, which GTK binds by default anyway), `HANDLES_OPEN` →
`open_files`, About dialog built from the same fields upstream's appdata
carries.

## Model/behaviour files with no upstream `.blp`

`webfontkitgenerator/font.py` → `lib/font.rb` (the `Font` GObject) +
`lib/font_row.rb` (the `Adw.ActionRow`-per-loaded-font widget, built in
`window.py`'s list-binding code rather than its own template).
`webfontkitgenerator/generator.py` → `lib/generator.rb`.
`webfontkitgenerator/loader.py` → `lib/loader.rb`.
`webfontkitgenerator/log.py` → `lib/log.rb`.
`webfontkitgenerator/sourceview.py` → `lib/source_view.rb`.
`webfontkitgenerator/style.css` → `lib/style.rb`.
`webfontkitgenerator/__init__.py`/settings → `lib/settings.rb`.

14 `lib/` files total, matching the runtime gate's "14 components."

## Scope note

This inventory is read-through, not a scripted scan — the app is 14 files and
every upstream widget tree is in a `.blp` already, which the component-parity
pass below reads line by line against the corresponding `lib/*.rb`. No
scripted `component-scan.sh`/`gir-symbols.sh` pass was available in this
environment; every claim above was checked by reading both sides directly
(see `component-parity.md` for the line-level comparisons).
