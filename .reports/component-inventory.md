# Webfont Bundler — upstream component inventory (update)

Upstream: `origin/master` (Rafael Mardojai CM, *Webfont Kit Generator* /
"Webfont Bundler"), Python + PyGObject + blueprint, GTK4 / libadwaita 1 /
GtkSourceView 5 / libsoup 3, with `fontTools` + `brotli` doing the actual
subsetting.

Port: the `ruby` branch, `lib/`. This supersedes the inventory written at
commit `f17b6ea` ("Inventory upstream components"), which described every
component as missing. `lib/` has since grown from the 3-file stub to 14
files covering every upstream unit. This pass re-surveys the same upstream
units against the current `lib/` to say what now exists and what still has a
known gap.

Scan method: `component-scan.sh`, run against a clean `git archive
origin/master` extraction and against `lib/` on `ruby`, classified with a
GIR-built symbol table (`gir-symbols.sh`) from this fork's `nix develop`
shell (Gtk4, Adwaita, GtkSource, Soup3, Pango, Gio typelibs). Rows are listed
in the previous inventory in full per-widget/CSS/signal detail; this pass
focuses on the file-level mapping and parity status, since that detail still
holds.

## Component list

| Upstream file(s) | → `lib/` path | Kind | Exists |
|---|---|---|---|
| `webfontkitgenerator/main.py` | `lib/webfont_kit_generator/application.rb` | application (actions, accels, About) | yes |
| `webfontkitgenerator/window.blp` + `window.py` | `lib/window.rb` | window (main/progress/finished pages, empty state, output bar) | yes |
| `window.blp`'s `menu app-menu` | folded into `lib/window.rb` (`app_menu`, `importers_section`, `help_section`) | menu | yes |
| `webfontkitgenerator/gtk/help-overlay.blp` | `lib/shortcuts_window.rb` | shortcuts | yes (uses `Adwaita::ShortcutsDialog`, not `Gtk::ShortcutsWindow` — noted port deviation, GTK 4.18 deprecates the latter) |
| `webfontkitgenerator/options.blp` + `options.py` | `lib/options.rb` | page (preferences sidebar) | yes |
| `webfontkitgenerator/google.blp` + `google.py` | `lib/google_dialog.rb` | dialog | yes, with a caveat (below) |
| `webfontkitgenerator/font.py` (`FontData`, `Font`) | `lib/font.rb` | model | yes |
| `webfontkitgenerator/font.py` (`FontRow`) | `lib/font_row.rb` | row | yes |
| `webfontkitgenerator/log.py` | `lib/log.rb` | widget | yes |
| `webfontkitgenerator/sourceview.py` | `lib/source_view.rb` | widget | yes, with a caveat (below) |
| `webfontkitgenerator/loader.py` | `lib/loader.rb` | service | yes |
| `webfontkitgenerator/generator.py` | `lib/generator.rb` | service | yes |
| `webfontkitgenerator/style.css` | `lib/style.rb` | stylesheet | yes |
| `data/com.rafaelmardojai.WebfontKitGenerator.gschema.xml` | `lib/settings.rb` | settings | yes |

All 14 upstream units identified in the prior survey now have a corresponding
`lib/*.rb` file with real content (4,258 lines across 14 files, up from a
125-line stub). No upstream user-facing component — window, dialog, page,
row, menu, shortcuts, empty state, error state — is unaccounted for in
`lib/`.

## Known gaps inside otherwise-present components — both closed this round

Both of the dependency-wiring gaps this inventory previously flagged are now
fixed, in the same pass:

- **`lib/google_dialog.rb`** — **closed.** `soup3` is in
  `webfont-kit-generator-rb.gemspec` (`add_dependency("soup3", "~> 1.0")`),
  `nix/Gemfile`, and `flake.nix`'s `gtkStack` (`libsoup_3`); the lock and
  `nix/gemset.nix` were regenerated with `bundix`, and
  `nix develop --command xvfb-run -a ruby -e 'require "soup3"; puts
  Soup.constants.size'` loads the gem and typelib together. The dialog's two
  HTTP requests go through `Soup::Session`/`Soup::Message`, not hand-rolled
  code.
- **`lib/source_view.rb`** — **closed.** The file's former claim ("There are
  no Ruby bindings for GtkSourceView 5") was false — `gtksourceview5` is on
  RubyGems — and is gone from the file along with the hand-rolled regex
  highlighter it excused. `gtksourceview5` is now in the gemspec, the
  `nix/Gemfile`, and `flake.nix`'s `gtkStack` (with a `gemConfig` entry so its
  native extension actually builds against the typelib, the same way
  `gdk4`/`gtk4`/`adwaita` already needed one). `SourceView` subclasses
  `GtkSource::View` directly: a real `GtkSource::LanguageManager` picks the
  "html"/"css" lexers, a real `GtkSource::StyleSchemeManager` supplies the
  Adwaita/Adwaita-dark schemes upstream uses, and the line-number gutter a
  plain `Gtk::TextView` could never draw now renders, because
  `show_line_numbers` is a real `GtkSource::View` property.
  `nix develop --command xvfb-run -a ruby -e 'require "gtksourceview5"; puts
  GtkSource.constants.size'` loads it cleanly alongside `soup3` and `gtk4`
  (one nixpkgs closure, no duplicate-GType registration).

## Non-components (unchanged from the prior survey)

`webfontkitgenerator/webfontkitgenerator.gresource.xml`, `meson.build` ×3,
`webfontkitgenerator.in`, `build-aux/*`, `debian/*`, `pyproject.toml`,
`requirements.txt`, the `.desktop.in`/`.metainfo.xml.in`/`.service.in`
templates, `brand/`, `webfont-kit-generator.doap`, and `.transifex.yml` —
translation parity is a separate skill's job, not this inventory's, but is no
longer a non-component either: `po/LINGUAS` and the 24 `po/*.po` catalogues
over the `webfontkitgenerator` gettext domain are now copied into this fork
verbatim and wired up via `lib/translatable.rb` — see
`.reports/translation-parity.md` for what is and is not translated.

## Totals

14 upstream components (13 source/blueprint-pair units plus the settings
schema), all 14 present in `lib/` on `ruby`. The two components that carried a
recorded binding gap (Soup, GtkSourceView) are now wired onto their mandatory
gems instead of a hand-rolled substitute.
