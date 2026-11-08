# Component identification — webfont-kit-generator-rb

| | |
|---|---|
| Upstream | `origin/master` @ `032df25285cab1c14ef5bfd1e242bcec2157d14f` |
| Port | `ruby` @ `6893c450641b22b129f7b5386dc08e4ed4a7b6e7` |

This round re-ran `component-identification/scripts/component-scan.sh` over
fresh worktrees of both branches (`151` upstream rows, `121` port rows — the
same counts as the prior round, confirming nothing drifted since `ea115ca`;
the only commit since then, `6893c45`, touched `google_dialog.rb`,
`flake.nix`, `TRANSLATION_PARITY.md` and `.reports/`, not the widget tree)
and re-read every discrepancy by hand per Step 4 rather than trusting the
prior round's reading. Independently reproduced in this session: every
"missing" row the scan reports resolves to a loop-built widget/action or an
upstream type-annotation quirk (`options.py` type-annotates eight subset
toggles `Gtk.Switch` while `options.blp` builds them as `CheckButton` — the
blueprint, not the Python annotation, is what GtkBuilder actually
constructs), confirmed by re-reading `window.blp`/`window.py`,
`options.blp`/`options.py`, `google.blp`/`google.py` and
`gtk/help-overlay.blp` against `lib/window.rb`, `lib/options.rb`,
`lib/google_dialog.rb` and `lib/shortcuts_window.rb` line for line this
round, not by re-citing the prior round's inventory.

## File map (one upstream unit, one or more `lib/*.rb` files)

| Upstream | Port |
|---|---|
| `webfontkitgenerator/window.py` + `window.blp` | `lib/window.rb` |
| `webfontkitgenerator/options.py` + `options.blp` | `lib/options.rb` |
| `webfontkitgenerator/google.py` + `google.blp` | `lib/google_dialog.rb` |
| `webfontkitgenerator/gtk/help-overlay.blp` (no `.py`) | `lib/shortcuts_window.rb` |
| `webfontkitgenerator/main.py` | `lib/webfont_kit_generator/application.rb` |
| `webfontkitgenerator/font.py` | `lib/font.rb` + `lib/font_row.rb` |
| `webfontkitgenerator/generator.py` | `lib/generator.rb` |
| `webfontkitgenerator/loader.py` | `lib/loader.rb` |
| `webfontkitgenerator/log.py` | `lib/log.rb` |
| `webfontkitgenerator/sourceview.py` | `lib/source_view.rb` |
| `webfontkitgenerator/style.css` | `lib/style.rb` |
| `webfontkitgenerator/__init__.py` + gschema | `lib/settings.rb` |
| *(house convention, no single upstream file)* | `lib/translatable.rb` |
| `webfontkitgenerator/__init__.py` (entry point) | `lib/webfont_kit_generator.rb`, `lib/webfont/kit/generator/rb/version.rb` |

14 `lib/*.rb` files map 1:1 or many:1 to an upstream unit in the table above;
counting `lib/webfont_kit_generator.rb` (the top-level require aggregator)
and `lib/webfont/kit/generator/rb/version.rb` (the gem version constant) as
additional non-unit files gives 16 total files under `lib/`. This round's
runtime gate reports "12 components" rather than the prior round's "14" —
read as the harness's own component grouping (it groups some of the 14
upstream units above together, e.g. the model/behaviour files as one
"generator pipeline" component, or data/packaging folded into "application"),
not as a change to the file mapping above, which is unchanged. Not
independently re-derivable from inside this repo (the harness computes it,
not a script here), so it is reported as given rather than reconciled by
guessing which grouping the harness used.

## Window — `window.blp`/`window.py` → `lib/window.rb`

`Gtk::ApplicationWindow` (upstream's `Adw.ApplicationWindow` — the Ruby
binding for `Adwaita::ApplicationWindow` is broken, documented at
`lib/window.rb:23-26`). Contains: `Gtk.Stack appstack` (main/progress/
finished); main page's `HeaderBar` + `app-menu` `Gio::Menu` (two sections,
three items: Import from Google Fonts, Keyboard Shortcuts, About);
`Adw.OverlaySplitView` with the fonts `Gtk.Stack` (empty/fonts) and the
`Options` sidebar; bottom `Gtk.ActionBar` (dir label, Browse, Generate);
progress page (`Adw.StatusPage` + `ProgressBar` + Cancel); finished page
(`Adw.ToolbarView`, `Adw.ViewSwitcher`, `Adw.ViewStack` with Info —
two `$SourceView`s + Open-in-Files — and Log — `$Log`). Window actions:
`set-dir`, `open`, `google`, `generate`, `back`, `show-help-overlay`,
plus the parameterised `remove-font` — all built from `ACTIONS =
['set-dir','open','google','generate','back','show-help-overlay']`
(`lib/window.rb:34,594`) and `remove_font_action` (`:603`). The scan only
sees `win.back`/`win.generate`/`win.open`/`win.set-dir` directly because the
other three names are built from the `ACTIONS.each` loop and from a
`GLib::VariantType.new('u')` literal the scanner misreads as an action named
`u` — both are scanner artifacts, verified by reading the loop. `Gtk.DropTarget`
on the main page for drag-and-drop.

## Options sidebar — `options.blp`/`options.py` → `lib/options.rb`

`Adw.PreferencesPage`: Options group (2 `Adw.ActionRow`+`Switch` pairs,
WOFF2/WOFF); Subsetting group (`Adw.ExpanderRow`, two `Gtk.ListBox` columns
of 4 `Adw.ActionRow`+`CheckButton` each — Latin/Latin-Ext, Cyrillic/
Cyrillic-Ext, Greek/Greek-Ext, Vietnamese/Devanagari — plus a custom-range
`Gtk.Entry` with live validation); CSS group (`Adw.SwitchRow` base64,
`Adw.ComboRow` font-display). The scan's raw count for `lib/options.rb`
shows only 2 `Gtk.Switch`, 2 `Gtk.CheckButton`, 2 `Adw.ActionRow` because
`subset_checks` and `subset_action_row` build the other 8+8 inside a
`PRESET_RANGES.keys.to_h`/`names.each` loop — read by hand, both loops run
over all 8 subset keys, so the real built count matches upstream's 2+8
switches/checkboxes-as-pairs and 10 action rows. (Upstream's own
`options.py` type-annotates `latin`..`devanagari` as `Gtk.Switch` even
though `options.blp` builds them as `CheckButton` — an upstream annotation
bug; the blueprint is the ground truth and the port matches the blueprint.)

## Google Fonts importer — `google.blp`/`google.py` → `lib/google_dialog.rb`

`Adw.Dialog`, two-page `Gtk.Stack`: main (URL entry + paste/clear icon,
inline error `Gtk.Revealer`, Download button) and loading (`Adw.StatusPage`,
`ProgressBar`, Cancel). State machine: entry validation → ETag-cached
database fetch (`If-None-Match` / `google-fonts-sha`) → family/variant
resolution over both legacy and v2 Google Fonts CSS URL shapes → per-file
download to tmp files → hand-off to `Window#load_fonts` or a toast of
collected errors.

## Shortcuts — `help-overlay.blp` (no `.py`) → `lib/shortcuts_window.rb`

Five shortcuts in one "General" `C_("shortcut window", …)` group: Show
Shortcuts, Open Fonts, Select Output Directory, Google Fonts Importer,
Generate. `Gtk::ShortcutsWindow` cannot be constructed from the Ruby
bindings (raises "GtkWindow is not subtype of GtkShortcutsWindow",
documented at `lib/shortcuts_window.rb:14-17`); the port substitutes
`Adw.ShortcutsDialog` with the same five entries and the same accelerators,
with one upstream bug fixed in the process — upstream's `main.py` binds
`<Ctl>o` for Open Fonts, which is not a GTK modifier name and so never
fires; the port binds `<Control>o`.

## Application — `main.py` → `lib/webfont_kit_generator/application.rb`

`about` action, five window accelerators (open/google/set-dir/generate/back)
plus `show-help-overlay` (GTK's default binding, added explicitly anyway),
`HANDLES_OPEN` → `open_files`, About dialog built from the same fields
upstream's appdata carries (including the about dialog's second `<p>`,
fixed this round — see `translation-parity.md`).

## Model/behaviour files with no upstream `.blp`

`font.py` → `lib/font.rb` (the `Font` GObject) + `lib/font_row.rb` (the
per-loaded-font `Adw.ActionRow`, built in a loop over the font list model,
not from its own template — hence 1 static `Adw.ActionRow` row in the scan
and N on screen). `generator.py` → `lib/generator.rb`. `loader.py` →
`lib/loader.rb`. `log.py` → `lib/log.rb` (`Gtk.TextView` subclass). `source
view.py` → `lib/source_view.rb` (now a real `GtkSource::View` subclass —
see "What it found here" in `accountability-ensurance.md` for why this one
file's history matters). `style.css` → `lib/style.rb`. `__init__.py`/
gschema → `lib/settings.rb`.

## Data/packaging (no `lib/*.rb` unit, but part of the upstream tree)

`data/com.rafaelmardojai.WebfontKitGenerator.desktop.in`,
`.metainfo.xml.in`, `.service.in`, and the four icon SVGs all now have a
counterpart under `data/org.rubygtkproject.WebfontKitGenerator.*` (added in
commits `3b83bef` and `ea115ca`, after the first round of parity reports was
written — see `translation-parity.md` for the two msgids this closed).

## Scope note

Read-through, not scripted-scan-only: `component-scan.sh` was run on both
worktrees (151 upstream rows / 121 port rows), every discrepancy between the
two was opened and read, and every "missing" row turned out to be a
loop-built widget, a loop-built action, or an upstream type-annotation bug —
none were real gaps. See `component-parity.md` for the axis-by-axis
comparison this inventory feeds.
