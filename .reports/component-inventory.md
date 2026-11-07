# Component inventory — webfont-kit-generator-rb

Surveyed `origin/master` (Python/GJS upstream, GtkBuilder via blueprint) against
`lib/` on `ruby`. This is the opening survey of a fork whose port already has
substantial coverage, so the table below records parity at the file/unit
level — kind, upstream source, port destination, and whether the port file
exists — rather than a full five-facet widget scan. Deep per-widget
comparison (CSS classes, signal wiring, dynamic classes) is the job of
`component-parity` on a unit-by-unit basis, not this survey.

## Components

| # | Upstream file(s) | Port file | Kind | Exists in `lib/`? |
|---|---|---|---|---|
| 1 | `webfontkitgenerator/main.py` (`Application`) | `lib/webfont_kit_generator/application.rb` | application class — actions (`about`), accelerators for all `win.*` actions, About dialog | Yes |
| 2 | `webfontkitgenerator/window.py` + `webfontkitgenerator/window.blp` (`Window`) | `lib/window.rb` | main window — `Adw.ApplicationWindow`: app-stack (main/progress/finished), header bar, app menu, overlay split view (fonts list + `Options` sidebar), empty-state page, bottom action bar, progress `Adw.StatusPage`, finished view (`Adw.ViewStack` with Info/Logs pages), file/dir choosers, drag-and-drop, all `win.*` actions (`open`, `set-dir`, `google`, `generate`, `back`, `remove-font`) | Yes |
| 3 | `webfontkitgenerator/font.py` (`FontRow` class) | `lib/font_row.rb` | row widget — `Adw.ActionRow` subclass with a flat/circular remove button that activates `win.remove-font` | Yes |
| 4 | `webfontkitgenerator/font.py` (`Font`, `FontData`) | `lib/font.rb` | data/model classes — `Font` (GObject wrapping a path) and `FontData` (name/family/version/style/weight/width/variable/local) | Yes |
| 5 | `webfontkitgenerator/options.py` + `webfontkitgenerator/options.blp` (`Options`) | `lib/options.rb` | sidebar page — `Adw.PreferencesPage`: WOFF2/WOFF switches, subsetting `Adw.ExpanderRow` with per-script `Adw.ActionRow`+`CheckButton` pairs (Latin, Latin Ext, Cyrillic, Cyrillic Ext, Greek, Greek Ext, Vietnamese, Devanagari), custom-ranges `Gtk.Entry` with live validation (`error` CSS class), CSS group (`Adw.SwitchRow` base64, `Adw.ComboRow` font-display), GSettings bindings | Yes |
| 6 | `webfontkitgenerator/google.py` + `webfontkitgenerator/google.blp` (`GoogleDialog`) | `lib/google_dialog.rb` | dialog — `Adw.Dialog`: URL entry + paste icon + error revealer, download button, loading `Adw.StatusPage` with progress bar and cancel, Google Fonts API fetch/cache via `Soup`, v1/v2 Google Fonts URL parsing, file download and import | Yes |
| 7 | `webfontkitgenerator/loader.py` (`Loader`) | `lib/loader.rb` | non-widget service — reads dropped/opened font files into `Font`/`FontData` models | Yes |
| 8 | `webfontkitgenerator/generator.py` (`Generator`) | `lib/generator.rb` | non-widget service — subsetting, WOFF2/WOFF conversion, CSS/HTML snippet generation, drives the progress page and log | Yes |
| 9 | `webfontkitgenerator/log.py` (`Log`) | `lib/log.rb` | widget — `Gtk.TextView` subclass (monospace, non-editable, `log` CSS class) used as the finished view's log pane | Yes |
| 10 | `webfontkitgenerator/sourceview.py` (`SourceView`) | `lib/source_view.rb` | widget — `GtkSource.View` subclass (line numbers, monospace, non-editable, light/dark Adwaita style scheme) used for the HTML/CSS snippet panes | Yes |
| 11 | `webfontkitgenerator/gtk/help-overlay.blp` (standalone `.blp`, no backing `.py`) | `lib/shortcuts_window.rb` | shortcuts window — `Gtk.ShortcutsWindow` equivalent for `win.show-help-overlay`, built with `Adwaita::ShortcutsItem`/`ShortcutsSection` since the Ruby bindings reject building `Gtk::ShortcutsWindow` directly | Yes |
| 12 | `data/com.rafaelmardojai.WebfontKitGenerator.gschema.xml` | `lib/settings.rb` | GSettings schema wrapper — `woff2`, `woff`, `base64`, `font-display`, `subsetting`, per-script subset toggles, `google-api-key`, `google-fonts-sha` | Yes |
| 13 | `webfontkitgenerator/style.css` | `lib/style.rb` | CSS provider — loads the app stylesheet (`log`, `sub-box`, `sub-left-box`, `bottom-box`, `subtitle`, etc.) | Yes |
| 14 | *(house convention; no single upstream file)* `_()`/`gettext` calls across all `.py`/`.blp` | `lib/translatable.rb` | translation helper shared by the widget classes | Yes |
| 15 | `webfontkitgenerator/__init__.py` | `lib/webfont_kit_generator.rb`, `lib/webfont/kit/generator/rb/version.rb` | entry point / version constant | Yes |
| 16 | `data/com.rafaelmardojai.WebfontKitGenerator.metainfo.xml.in` | — (consumed by `Adwaita::AboutDialog.new_from_appdata` equivalent in `application.rb`'s `show_about`) | metadata — About dialog content | Present via `application.rb` |
| 17 | `po/*.po`, `po/webfontkitgenerator.pot` | — | translation catalogue | Not yet surveyed for parity (out of scope for widget inventory; flag for `translation-parity`) |
| 18 | `data/com.rafaelmardojai.WebfontKitGenerator.desktop.in`, `.service.in`, icons (`webfontkitgenerator-remove-symbolic.svg`, `completed-symbolic.svg`, `splash-a-symbolic.svg`, `splash-b-symbolic.svg`, app icon SVGs) | — (packaging/build-system concern, not `lib/` code) | desktop integration / icon assets | N/A — not a `lib/*.rb` unit |

## Summary

Upstream (`origin/master`) has 10 Python source files plus 4 blueprint UI
files (`window.blp`, `options.blp`, `google.blp`, `gtk/help-overlay.blp`), one
GSettings schema, one stylesheet, and a `po/` catalogue of 23 languages.

The `ruby` branch's `lib/` directory (14 files, ~4,300 lines) already has a
1:1 counterpart for every user-facing component identified above: the
application class, the main window and all its stack pages (empty state,
fonts list + options sidebar, progress page, finished view with Info/Logs),
the Google Fonts import dialog, the font row widget, the shortcuts window,
the log and source-view widgets, the settings wrapper, and the stylesheet
loader. No upstream component was found with no corresponding `lib/*.rb`
file.

**Open items for follow-on work (not blockers to this survey):**
- `po/` catalogue parity (translated strings vs. `lib/translatable.rb` usage)
  was not checked here — that is `translation-parity`'s job.
- A full five-facet widget scan (CSS classes, signals, actions down to each
  dynamic case) was not run per `component-identification`'s Step 2–4
  tooling; the table above was built by direct reading of each upstream file
  against its `lib/` counterpart. A `component-parity` pass per unit (window,
  options, google dialog) would surface any gaps in CSS classes or dynamic
  signal wiring that a file-level comparison cannot see.
- `GoogleDialog` (`lib/google_dialog.rb`) already uses the `soup3` gem's
  `Soup` module for its HTTP requests, matching the mandatory-gem
  requirement for this fork — confirmed by `grep` (`require 'soup3'`) in the
  file header.
