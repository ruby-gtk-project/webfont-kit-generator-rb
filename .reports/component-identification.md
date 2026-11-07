# Component identification — webfont-kit-generator

| | |
|---|---|
| Upstream | `origin/master` @ `032df25285cab1c14ef5bfd1e242bcec2157d14f` |
| Port | `ruby` @ `58977cad7eea5ffff0c174d764fd3946bb9ad598` |

This restates `.reports/component-inventory.md` (written during the port
itself) as this audit's independent identification pass, and adds what that
pass did not check: accelerators, the shortcuts dialog's content, and the
`po/` catalogue as a component in its own right.

## Declarative UI

Upstream ships two `.blp` files and nothing else declarative:

- `webfontkitgenerator/window.blp` — the main window's template root
  (`template $WebfontKitGeneratorWindow: Adw.ApplicationWindow`), the
  `app-menu` menu model, and the options/fonts/finished stack pages.
- `webfontkitgenerator/google.blp` — the Google Fonts importer dialog.
- `webfontkitgenerator/options.blp` — the preferences sidebar.
- `webfontkitgenerator/gtk/help-overlay.blp` — a standalone
  `ShortcutsWindow help_overlay { }` named root with **no backing source
  file** (per `component-identification`'s scope rule, this is its own unit).

The port has no `.blp`/`.ui` files, by house style; all five map to Ruby
files built with memoized accessors.

## File mapping (one upstream unit → one port file, with one exception)

| Upstream file(s) | → `lib/` path |
|---|---|
| `webfontkitgenerator/main.py` | `lib/webfont_kit_generator/application.rb` |
| `webfontkitgenerator/window.blp` + `window.py` | `lib/window.rb` |
| `webfontkitgenerator/gtk/help-overlay.blp` | `lib/shortcuts_window.rb` |
| `webfontkitgenerator/options.blp` + `options.py` | `lib/options.rb` |
| `webfontkitgenerator/google.blp` + `google.py` | `lib/google_dialog.rb` |
| `webfontkitgenerator/font.py` (`FontData`, `Font`) | `lib/font.rb` |
| `webfontkitgenerator/font.py` (`FontRow`) | `lib/font_row.rb` |
| `webfontkitgenerator/log.py` | `lib/log.rb` |
| `webfontkitgenerator/sourceview.py` | `lib/source_view.rb` |
| `webfontkitgenerator/loader.py` | `lib/loader.rb` |
| `webfontkitgenerator/generator.py` | `lib/generator.rb` |
| `webfontkitgenerator/style.css` | `lib/style.rb` |
| `data/com.rafaelmardojai.WebfontKitGenerator.gschema.xml` | `lib/settings.rb` |
| **`po/*.po` (24 files) + `po/webfontkitgenerator.pot`** | **no port file — see `.reports/translation-parity.md`** |

14 UI/logic units all have a corresponding `lib/*.rb` file with real
content. The 15th row above is the one the prior inventory explicitly
deferred ("translation parity is a separate skill's job, not this
inventory's") and that deferral is where this round's single largest gap
lives — see the translation-parity report.

## Per-unit detail not previously recorded

### `lib/shortcuts_window.rb` — the keyboard-shortcuts dialog

Upstream's `help-overlay.blp` declares one `ShortcutsGroup` ("General") with
**five** `ShortcutsShortcut` rows:

| Title | `action-name` |
|---|---|
| Show Shortcuts | `win.show-help-overlay` |
| Open Fonts | `win.open` |
| Select Output Directory | `win.set-dir` |
| Google Fonts Importer | `win.google` |
| **Generate** | **`win.generate`** |

`lib/shortcuts_window.rb`'s `SHORTCUTS` constant has **four** entries — it
drops the "Generate" row entirely. See `.reports/component-parity.md` for
the full axis comparison; the accelerator itself is also missing (see
below), so this is not a display-only gap.

### Accelerators — a unit the prior inventory did not cover at all

Upstream's `main.py` (`setup_actions`) binds five window accelerators:

```
win.open      <Ctl>o
win.google    <Ctl>g
win.set-dir   <Ctl>d
win.generate  <Ctl>Return
win.back      Escape
```

(`<Ctl>` is not a GTK modifier name; both upstream and the port actually
rely on `<Control>`/`<Primary>` resolving it, a known quirk, not a
port-side bug.)

`lib/webfont_kit_generator/application.rb`'s `WINDOW_ACCELS` binds **four**
of the five — `open`, `google`, `set-dir`, `back`, `show-help-overlay` — and
has **no entry for `generate`**. Pressing Ctrl+Return in the port does
nothing; upstream fires `win.generate`.

### `lib/log.rb` — the generation scrollback

One-to-one with `webfontkitgenerator/log.py`: a `Gtk.TextView` with
`append(text, bold:, italic:)` and `reset`. Present and apparently faithful.
No test or drive script asserts its content — see
`.reports/test-parity.md`.

### `lib/style.rb` — the stylesheet

Upstream's `webfontkitgenerator/style.css` is a file; the port's
`lib/style.rb` holds the same rules as a Ruby string loaded through
`Gtk::CssProvider`. Not diffed rule-by-rule in this pass (see
`component-parity.md`, Step 4, for what remains unverified).

## Totals

14 of the 15 upstream units this inventory enumerates (14 UI/logic files +
the `po/` catalogue) have a corresponding port artifact. `po/` has none at
all — zero `.po` files, zero `gettext` calls anywhere in `lib/` or `exe/`.
That is detailed fully in `.reports/translation-parity.md` and is this
round's headline finding, not a footnote.
