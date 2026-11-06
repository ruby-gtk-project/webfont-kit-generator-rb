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

## Known gaps inside otherwise-present components

These are not missing components; they are places the existing file admits
(in its own comments) that it worked around a missing binding instead of
using the released gem the fork is required to ship:

- **`lib/google_dialog.rb:39-40`** — "Upstream makes its requests with
  libsoup 3; there are no Ruby bindings for libsoup and no Soup typelib in
  this app's closure, so the two requests it makes ... [are hand-rolled]."
  This fork's task brief requires `soup3` (provides `Soup`) as a mandatory
  dependency. Checked and confirmed still true as of this survey:
  `webfont-kit-generator-rb.gemspec` has no `add_dependency` lines at all
  (not even `gtk4`/`adwaita`/`glib2`), `nix/Gemfile` lists only `adwaita` and
  `gtk4`, and `flake.nix`'s `gtkStack` has no Soup/libsoup package, so no
  Soup typelib reaches `GI_TYPELIB_PATH`. The comment's premise ("no Ruby
  bindings for libsoup") is the thing this fork is meant to fix by wiring in
  `soup3`, not a reason to keep the hand-rolled HTTP code.
- **`lib/source_view.rb:12`** — "There are no Ruby bindings for
  GtkSourceView 5 — `require 'gtksourceview5'` [fails/is unavailable]," so the
  two code panes on the finished page likely degrade from highlighted
  `GtkSource::View` to plain `Gtk::TextView`. `gtkStack` in `flake.nix` was
  not checked for a GtkSourceView package in this pass beyond the Soup check
  above; worth confirming in the same pass as the Soup fix, since both are
  "typelib missing from gtkStack" issues of the same shape.

Both are flagged for the dependency-wiring pass this fork is required to do
(gemspec → `nix/Gemfile` → regenerated lock → `gtkStack`/`typelibPath` →
prove with `require`), not for action in this survey step.

## Non-components (unchanged from the prior survey)

`webfontkitgenerator/webfontkitgenerator.gresource.xml`, `meson.build` ×3,
`webfontkitgenerator.in`, `build-aux/*`, `debian/*`, `pyproject.toml`,
`requirements.txt`, the `.desktop.in`/`.metainfo.xml.in`/`.service.in`
templates, `brand/`, `webfont-kit-generator.doap`, `.transifex.yml`, and the
25 `po/*.po` catalogues (`po/LINGUAS`) over the `webfontkitgenerator` gettext
domain — translation parity is a separate skill's job, not this inventory's.

## Totals

14 upstream components (13 source/blueprint-pair units plus the settings
schema), all 14 present in `lib/` on `ruby`. Two components carry a recorded
binding gap (Soup, GtkSourceView) rather than using this fork's mandatory
gems.
