# Webfont Bundler — upstream component inventory

Upstream: `origin/master` (Rafael Mardojai CM, *Webfont Kit Generator* /
"Webfont Bundler"), Python + PyGObject + blueprint, GTK4 / libadwaita 1 /
GtkSourceView 5 / libsoup 3, with `fontTools` + `brotli` doing the actual
subsetting.

Port: the `ruby` branch. The house shape (pilot: `gnome-contacts-rb`) is one
upstream source file → one flat `lib/<thing>.rb`, top-level class, each file
opening with `# frozen_string_literal: true` then `require 'adwaita'` and
`require_relative` for siblings, each class carrying a comment naming the
upstream file it came from. `lib/webfont_kit_generator/application.rb` and
`lib/webfont_kit_generator.rb` are the gem scaffold (the pilot has the same
pair under `lib/gnome_contacts/`); the app itself goes in flat `lib/*.rb`.

Upstream splits almost every component across a `.py` (subclass, template
children, callbacks) and a `.blp` (widget tree, CSS classes, signals). The
component is the pair, so the table below unions them.

## State of the port

`lib/` on `ruby` holds three files:

| File | What it is |
|---|---|
| `lib/webfont_kit_generator.rb` | gem entry point, requires `application` |
| `lib/webfont_kit_generator/application.rb` | placeholder `Application`: one `Adwaita::ApplicationWindow`, `Adwaita::ToolbarView`, `Adwaita::HeaderBar`, and an `Adwaita::StatusPage` reading "The Ruby port has not been written yet." |
| `lib/webfont/kit/generator/rb/version.rb` | gem version constant |

No user-facing component of the app exists yet. Every row below is **missing**,
with the sole partial exception of the application object, which exists as a
stub with none of its actions, accelerators or About dialog.

Totals: 11 components across 13 upstream source/blueprint files, 1 GSettings
schema (16 keys), 1 stylesheet (6 classes), 1 menu model, 1 shortcuts window,
25 `po/` catalogues (`po/LINGUAS`: ar ca cs de es et fa fi fr gl hi hr ka kk nl
oc pt pt_BR ru sk sv tr uk zh) over a `webfontkitgenerator` gettext domain.

---

## webfontkitgenerator/main.py — the application object

→ `lib/main.rb`  ·  kind: application  ·  **partial** (stub in
`lib/webfont_kit_generator/application.rb`)

`Adw.Application`, id `com.rafaelmardojai.WebfontKitGenerator`, flags
`HANDLES_OPEN`; `GLib.set_application_name('Webfont Bundler')`.

| Item | Detail |
|---|---|
| Actions | `app.about` → `Adw.AboutDialog.new_from_appdata('/com/rafaelmardojai/WebfontKitGenerator/appdata.xml', version)` with `translator_credits`, presented on the window |
| Accels | `win.open` `<Ctl>o` · `win.google` `<Ctl>g` · `win.set-dir` `<Ctl>d` · `win.generate` `<Ctl>Return` · `win.back` `Escape` |
| `do_activate` | reuse `props.active_window`, else build `Window`, then `present` |
| `do_open` | activate, then `window.load_fonts(files)` — the app is a file handler for `.otf`/`.ttf` |

Port notes: the Ruby bindings' `Adwaita::Application` is broken, so the
application object is `Gtk::Application` (as the existing stub already does);
`HANDLES_OPEN` and the `open` signal have to be wired by hand. The About
dialog has no appdata GResource in the port, so its fields are set directly.

## webfontkitgenerator/window.blp + window.py — the main window

→ `lib/window.rb`  ·  kind: window  ·  **missing**

`template $Window : Adw.ApplicationWindow`, 1000×600, one `GObject` property
`processing: bool`. Content is `Gtk.Stack appstack` (`crossfade`) with three
pages — `main`, `progress`, `finished` — and
`notify::visible-child-name => _on_appstack_changes` disabling `open` and
`set-dir` off the `main` page.

### Page `main`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ToastOverlay toasts` | 1 | — | — | `vexpand`; every error in the app lands here |
| `Adw.ToolbarView toolbar_view` | 1 | — | — | `bottom-bar-style: raised`, `reveal-bottom-bars: false`; `top_bar_style` flipped FLAT↔RAISED by `_check_ready_state` |
| `Gtk.HeaderBar headerbar` | 1 | — | — | top bar |
| `Gtk.Button btn_add_fonts` | 1 | — | `win.open` | `list-add-symbolic`, tooltip "Open Fonts" |
| `Gtk.MenuButton` | 1 | — | `menu-model: app-menu` | tooltip "Main Menu", `direction: none`, `focus-on-click: false` |
| `Adw.OverlaySplitView split` | 1 | — | — | sidebar at `end`, 350–600 px, `show-sidebar` follows "has fonts" |
| `Gtk.Stack fonts_stack` | 1 | — | — | `crossfade`; pages `empty` / `fonts` |
| `Gtk.ActionBar` | 1 | `bottom-box` | — | bottom bar |

Empty state (`fonts_stack` page `empty`):

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 2 | — | — | vertical, spacing 48, `valign: center`; inner box `halign: center` |
| `Gtk.Label` | 1 | `title-1` | — | "Add some fonts" |
| `Gtk.Image` | 2 | — | — | `splash-a-symbolic`, `splash-b-symbolic`, `pixel-size: 192` (app icons, GResource) |
| `Gtk.Button` | 1 | `suggested-action`, `pill` | `win.open` | "Open Fonts" |

Fonts list (`fonts_stack` page `fonts`):

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.ScrolledWindow` → `Gtk.Viewport` → `Adw.Clamp` → `Gtk.Box` ×2 | 1 each | — | — | margins 24 side / 48 top-bottom |
| `Gtk.ListBox fonts_list` | 1 | `content` | `selection-mode: none` | `bind_model(model, _create_font_row)` — **repeater** over the `Gio.ListStore` of `Font`, one `FontRow` per item |

Output-directory bar (inside the `ActionBar`):

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 2 | — | — | spacing 12 / 6 |
| `Gtk.Image` | 1 | — | — | `folder-open-symbolic` |
| `Gtk.Label directory` | 1 | `heading` | — | "Select Output Directory" until a dir is picked, then its basename |
| `Gtk.Button` | 1 | — | `win.set-dir` | "Browse..." |
| `Gtk.Button` | 1 | `suggested-action` | `win.generate` | "Generate", `[end]` |

### Page `progress`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.WindowHandle` | 1 | — | — | draggable, no header bar on this page |
| `Adw.StatusPage progress` | 1 | — | — | title set per font by the generator |
| `Adw.Clamp` → `Gtk.Box` | 1 each | — | — | vertical, spacing 36 |
| `Gtk.ProgressBar progressbar` | 1 | — | — | `show-text: true` |
| `Gtk.Button cancel` | 1 | `pill` | `clicked` → `Generator.do_stop` | "Cancel"; handler connected by `Generator.run`, not the template |

### Page `finished`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ToolbarView` | 1 | — | — | |
| `Gtk.HeaderBar` | 1 | — | — | `title-widget: Adw.ViewSwitcher` (`policy: wide`) |
| `Gtk.Button btn_back` | 1 | — | `win.back` | `go-previous-symbolic`, tooltip "Back" |
| `Adw.ViewSwitcher` | 1 | — | — | drives `finished_stack` |
| `Adw.ViewStack finished_stack` | 1 | — | — | pages below |
| `Adw.ViewStackPage` "info" | 1 | — | — | icon `completed-symbolic`, title "Information" |
| `Gtk.ScrolledWindow` / `Gtk.Viewport` | 1 each | — | — | |
| `Adw.StatusPage` | 1 | — | — | "Generation finished!", `completed-symbolic` |
| `Adw.Clamp` → `Gtk.Box` | 1 each | — | — | vertical, spacing 12 |
| `Gtk.Label` | 2 | — | — | "To link your fonts, copy the code below into the head of your HTML:" / "Or import it directly to your CSS:", `halign: start` |
| `$SourceView src_html`, `src_css` | 2 | `sourceview` (set in `style.css`, applied via the widget) | — | app widget, `language: "html"` / `"css"` |
| `Gtk.Button` | 1 | `pill` | `clicked => _open_generation_dir` | "Open in Files" → `Gtk.FileLauncher(file=out_dir).launch` |
| `Adw.ViewStackPage` "log" | 1 | — | — | icon `view-list-bullet-symbolic`, title "Logs" |
| `Gtk.ScrolledWindow` / `Gtk.Viewport` / `Adw.Clamp` | 1 each | — | — | clamp `margin-top: 20` |
| `$Log log` | 1 | `log` | — | app widget |

### Window actions, dialogs and controllers (window.py)

| Item | Detail |
|---|---|
| Actions | `win.remove-font` (param `u`, removes by index) · `win.set-dir` · `win.open` · `win.google` · `win.generate` (starts disabled) · `win.back` (no-op while `processing`) · plus `win.show-help-overlay` from the shortcuts window |
| `Gtk.FileDialog` ×2 | `out_dir_chooser` ("Select Output Directory", `select_folder`) and `fonts_chooser` ("Open Font Files", `open_multiple`) |
| `Gtk.FileFilter` | name "OTF & TTF", mime `font/otf`+`font/ttf`, patterns `.otf`/`.ttf`, in a `Gio.ListStore` |
| `Gtk.DropTarget` | controller on the window, `Gdk.FileList` / `DragAction.COPY`, `drop` → `load_fonts`, only on the `main` page |
| `Gio.ListStore` of `Font` | `items-changed` → `_check_ready_state` |
| Error states | toast "You don't have write access to the selected directory." when the chosen dir is not writable |
| `_check_ready_state` | enables `generate` only with items **and** an out dir; toggles `split.show_sidebar`, `toolbar_view.reveal_bottom_bars`, `fonts_stack` page and `top_bar_style` |
| `set_default_icon_name` | `com.rafaelmardojai.WebfontKitGenerator` |

## webfontkitgenerator/window.blp — `menu app-menu`

→ folded into `lib/window.rb`  ·  kind: menu  ·  **missing**

`Gio.Menu` with two sections: `importers-section` → "Import from Google Fonts"
(`win.google`); `help-section` → "_Keyboard Shortcuts"
(`win.show-help-overlay`) and "_About Webfont Bundler" (`app.about`).
3 items, no `custom:` slots.

## webfontkitgenerator/gtk/help-overlay.blp — shortcuts window

→ `lib/shortcuts_window.rb`  ·  kind: shortcuts  ·  **missing**

Standalone `ShortcutsWindow help_overlay` with no backing source file; `modal`,
one `ShortcutsSection` "shortcuts" (`max-height: 10`), one `ShortcutsGroup`
"General", 5 `ShortcutsShortcut` rows: Show Shortcuts
(`win.show-help-overlay`), Open Fonts (`win.open`), Select Output Directory
(`win.set-dir`), Google Fonts Importer (`win.google`), Generate
(`win.generate`). Titles use the `shortcut window` message context.

Port note: `Gtk::ShortcutsWindow` is deprecated in GTK 4.18; the pilot ports
this as a hand-built `lib/shortcuts_dialog.rb` — check it before choosing.

## webfontkitgenerator/options.blp + options.py — the options sidebar

→ `lib/options.rb`  ·  kind: page (preferences)  ·  **missing**

`template $Options : Adw.PreferencesPage`, shown as the `OverlaySplitView`
sidebar, every control bound to GSettings with `SettingsBindFlags.DEFAULT`.

| Widget | × | CSS | Signals / bindings | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesGroup` | 3 | — | — | "Options", untitled (subsetting), "CSS" |
| `Adw.ActionRow` | 10 | — | each `activatable-widget` → its toggle | WOFF2, WOFF, and the 8 subset rows |
| `Gtk.Switch woff2`, `woff` | 2 | — | bound `woff2`, `woff` | `valign: center` |
| `Adw.ExpanderRow subsetting` | 1 | `expander` (styled by `style.css`) | `enable-expansion` bound `subsetting` | title "Subsetting", subtitle "Limit the character set to reduce file size", `show-enable-switch` |
| `Gtk.ListBoxRow` | 2 | — | `activatable: false` | the two-column grid, and the custom-range block |
| `Gtk.Box` | 2 | — | — | homogeneous row of the two list boxes; vertical custom block, margins 12 |
| `Gtk.ListBox` | 2 | `sub-left-box`+`sub-box`, `sub-box` | `selection-mode: none` | left/right subset columns |
| `Gtk.CheckButton` | 8 | — | bound `latin`, `latin-ext`, `cyrillic`, `cyrillic-ext`, `greek`, `greek-ext`, `vietnamese`, `devanagari` | note: `options.py` type-annotates these as `Gtk.Switch`; the blueprint says `CheckButton` |
| `Gtk.Label` | 2 | — / `subtitle` | — | "Custom" and the comma-separated-values explanation (`wrap`, word mode) |
| `Gtk.Entry custom` | 1 | **`error`** added/removed dynamically by `_validate_subsetting` | `changed => _validate_subsetting` | placeholder `0021-007E,00E7,00EB,00C7,00CB`; validated with `fontTools.subset.parse_unicodes` |
| `Adw.SwitchRow base64` | 1 | — | bound `base64` | "Base64 Encode" / "Embed fonts in the CSS" |
| `Adw.ComboRow font_display` | 1 | — | `selected` bound `font-display` | "Font display" / "The CSS font-display descriptor"; `Gtk.StringList` of "Disabled" (translated), auto, block, swap, fallback, optional |

Also carries `PRESET_RANGES` (8 named Unicode ranges) and the accessors
`get_formats` (defaults to `['woff2']` when nothing is on), `get_subsetting`
(nil when the expander is off or nothing selected), `get_base64`,
`get_font_display` (nil at index 0). It also owns the `Gio.Settings` object
that `GoogleDialog` borrows.

## webfontkitgenerator/google.blp + google.py — Google Fonts import dialog

→ `lib/google_dialog.rb`  ·  kind: dialog  ·  **missing**

`template $GoogleDialog : Adw.Dialog`, `content-width: 500`,
`focus-widget: url_entry`. A `Gtk.WindowHandle` holding `Gtk.Stack stack`
(`crossfade`) with pages `main` and `loading`.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ToolbarView` | 1 | — | — | page `main` |
| `Adw.HeaderBar` | 1 | `flat` | — | `show-title: false`, `valign: start` |
| `Adw.StatusPage` | 1 | — | — | `font-x-generic-symbolic`, "Import from Google Fonts", "Download fonts from Google Fonts for self-hosting" |
| `Adw.Clamp` → `Gtk.Box` | 1 / 2 | — | — | vertical, spacing 12 and 3 |
| `Gtk.Entry url_entry` | 1 | **`error`** added/removed by `invalid_url`/`valid_url`/`_on_entry_changed` | `changed => _on_entry_changed`, `icon-press => _on_entry_icon` | 300 px, placeholder `https://fonts.googleapis.com/css2?family=Roboto`; secondary icon flips `edit-paste-symbolic` ↔ `edit-clear-symbolic`; the paste icon reads `Gdk.Clipboard` async |
| `Gtk.Revealer error_revealer` | 1 | — | — | `reveal-child: false` |
| `Gtk.Label error_label` | 1 | `error` | — | "Please set a valid url" |
| `Gtk.Button download_btn` | 1 | `suggested-action`, `pill` | `clicked => _on_download_clicked` | starts insensitive |
| `Adw.StatusPage progress` | 1 | — | — | page `loading`; title "Loading Google Fonts Database" then "Downloading {name}" |
| `Adw.Clamp` → `Gtk.Box` | 1 each | — | — | vertical, spacing 36 |
| `Gtk.ProgressBar progressbar` | 1 | — | — | `show-text`, 300 px, `halign: center`; pulsed on a 50 ms `GLib.timeout_add` until counts are known |
| `Gtk.Button cancel_btn` | 1 | `pill` | `clicked => _on_cancel_clicked` | cancels the `Gio.Cancellable` and closes |

Behaviour: validates the URL is `fonts.googleapis.com` with path `/css` or
`/css2`; parses v1 (`family=Name:400,700i|…`) and v2
(`family=Name:wght@400;700` with `ital`) query forms; fetches the Google Fonts
API over `Soup.Session` (user agent "Webfont Bundler", API key and ETag in
GSettings, `If-None-Match` for 304), caches
`$XDG_DATA_HOME/webfont-kit-generator/google-fonts.json`, downloads each
variant to a `Gio.File.new_tmp`, then hands the files to `window.load_fonts`.

Error states, all surfaced as toasts on the window after the dialog closes:
"Couldn't download the Google Fonts data.", "Couldn't find the {variant}
variant for {family_name}.", "Couldn't find the {family_name} font family.",
"Couldn't find any fonts for the given url.", "Couldn't download the font file
for {name}.", "Couldn't write the font file for {name}."

Port note: no libsoup binding is a given in the Ruby dev shell — check what
the fork's `nix develop` provides before committing to `Soup`; otherwise this
is a `Gio`/net-http job on a worker thread with `GLib::Idle` hand-back.

## webfontkitgenerator/font.py — `Font` model

→ `lib/font.rb`  ·  kind: model  ·  **missing**

`FontData` dataclass (name, family, version, style, weight, width,
is_variable, local[], plus `name_slug`/`family_slug`) and
`Font(GObject.Object)` with a `path` string property. Not a widget, but
`fonts_list.bind_model` needs a `GLib::Object` subclass, which is the main
binding quirk in this file.

## webfontkitgenerator/font.py — `FontRow`

→ `lib/font_row.rb`  ·  kind: row  ·  **missing**

One font in `fonts_list`. Built in code, no blueprint.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` | 1 | — | — | title = font name; subtitle = `family / style / weight / width` joined with " / ", spaces in weight/width hyphenated |
| `Gtk.Button` | 1 | `flat`, `circular` | `clicked` → `activate_action('win.remove-font', uint32(get_index()))` | `webfontkitgenerator-remove-symbolic` (app icon, GResource), `valign: center`, as row suffix |

## webfontkitgenerator/log.py — `Log`

→ `lib/log.rb`  ·  kind: widget  ·  **missing**

`Gtk.TextView` subclass, CSS class `log` (`style.css` repaints its `text` node
`@theme_bg_color`); non-editable, monospace, `WrapMode.WORD_CHAR`, `hexpand`.
API: `append(text, bold:, italic:)` via `insert_markup` on the end iter, and
`reset()` clearing the buffer.

## webfontkitgenerator/sourceview.py — `SourceView`

→ `lib/source_view.rb`  ·  kind: widget  ·  **missing**

`GtkSource.View` subclass used twice on the finished page. Line numbers,
monospace, non-editable, `WORD_CHAR` wrap, `hexpand`; matching-bracket
highlight off; a `language` GObject string property setting the buffer language
through `GtkSource.LanguageManager`; follows
`Adw.StyleManager::notify::dark` between the `Adwaita` and `Adwaita-dark`
style schemes. CSS class `sourceview` (border + 12 px radius in `style.css`).

Port note: `GtkSource` needs its own gem/typelib in the dev shell. If it is
absent, this degrades to a `Gtk::TextView` and the two code panes lose
highlighting — a parity gap worth recording explicitly rather than hiding.

## webfontkitgenerator/loader.py — `Loader`

→ `lib/loader.rb`  ·  kind: service (has user-facing error states)  ·  **missing**

Reads each dropped/opened file with `fontTools.ttLib.TTFont`, derives
`FontData` (best full/family name, version, macStyle bold/italic bits,
variable-font `wght`/`wdth` axis ranges, `local(...)` sources, and
weight/width guessed from name strings via the `WEIGHTS`/`WIDTHS` tables),
appends to the model on `GLib.idle_add`, and flips `window.processing`.

Error toasts: "You don't have read access to {font} or it doesn't exists." and
"Error: {error}.".

Port note: no `fontTools` in Ruby. The port has to parse the TTF/OTF `head`,
`name` and `fvar` tables itself (or wrap a gem); this is the single largest
non-UI gap and it decides what `FontRow` can show.

## webfontkitgenerator/generator.py — `Generator`

→ `lib/generator.rb`  ·  kind: service (owns the progress and finished views)  ·  **missing**

Runs on a daemon thread. Drives `window.progressbar`, `window.progress` title,
`window.log`, `window.appstack` (`main` → `progress` → `finished`) and
`window.finished_stack` (→ `info`), connects `window.cancel` `clicked` to
`do_stop`, subsets with `fontTools` `Subsetter`/`parse_unicodes` per selected
range, writes `woff2`/`woff` flavours (optionally base64-inlined), builds the
`@font-face` CSS and the HTML `<link>` snippet shown in the two `SourceView`s,
and logs "Generating fonts for {name}:" / "Generating {name}" /
"Generation finished!".

## webfontkitgenerator/style.css — stylesheet

→ `lib/style.rb` (or a `data/style.css` loaded by a `Gtk::CssProvider`)  ·  kind: stylesheet  ·  **missing**

6 rules, all applied by the components above: `.sub-box row:not(:last-child)`,
`.sub-left-box`, `.expander revealer list row`, `.sourceview`, `.log text`,
`.bottom-box > revealer > box`. None dead.

## data/com.rafaelmardojai.WebfontKitGenerator.gschema.xml — settings

→ `lib/settings.rb`  ·  kind: settings  ·  **missing**

Schema `com.rafaelmardojai.WebfontKitGenerator`, 16 keys: `woff2` (true),
`woff` (false), `subsetting` (false), `latin` (true), `latin-ext` (true),
`cyrillic` (true), `cyrillic-ext` (true), `greek` (true), `greek-ext` (true),
`vietnamese` (false), `devanagari` (false), `base64` (false), `font-display`
(i, 0), `google-api-key` (s, baked default), `google-fonts-sha` (s, '').

Port note: the pilot keeps a `lib/settings.rb` that wraps `Gio::Settings` and
falls back to an in-memory hash when the schema is not installed — the fork
has no schema compiled into the dev shell, so that fallback is required for
the app to start at all.

## Non-components, listed so nothing is mistaken for a gap

`webfontkitgenerator/webfontkitgenerator.gresource.xml` (UI/CSS/icons/appdata
bundle — the port builds widgets in code and needs only the four symbolic
icons: `splash-a`, `splash-b`, `completed`, `webfontkitgenerator-remove`),
`meson.build` ×3, `webfontkitgenerator.in` launcher, `build-aux/*`, `debian/*`,
`pyproject.toml`, `requirements.txt`, the `.desktop.in`, `.metainfo.xml.in`
and `.service.in` templates, `brand/`, `webfont-kit-generator.doap`,
`.transifex.yml`.

## Port order

1. `lib/settings.rb`, `lib/font.rb` — nothing renders without them.
2. `lib/window.rb` with the `main` page, empty state, menu and actions; plus
   `lib/main.rb` for the application, accels and About.
3. `lib/font_row.rb` + `lib/loader.rb` — the list becomes real.
4. `lib/options.rb` — the sidebar and its bindings.
5. `lib/log.rb`, `lib/source_view.rb`, then `lib/generator.rb` with the
   `progress` and `finished` pages.
6. `lib/google_dialog.rb`, `lib/shortcuts_window.rb`, `lib/style.rb`.
