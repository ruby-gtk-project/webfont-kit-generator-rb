# Translation parity — webfont-kit-generator-rb

| | |
|---|---|
| Upstream | `master` @ `032df25` (2026-08-19) |
| Port | `ruby` @ this commit |
| Domain | `webfontkitgenerator` (`po/meson.build`'s `i18n.gettext('webfontkitgenerator', ...)`) |
| Upstream messages | 72 |
| Ported | 70 |
| Gaps | 2 |
| Extra (untranslated) | 0 |
| Upstream occurrences | 80 across 72 messages (7 reused) |
| Port occurrences | 64 |
| Upstream languages | 24 `.po` files, 1,394 translated, 234 untranslated, 100 fuzzy |
| Languages shipped by the port | 24 (`po/*.po` and `po/LINGUAS` copied from upstream unchanged; `linguas_matches_files: true` both sides) |
| Build | `rake gettext:mo:update` compiles `po/*.po` into `locale/<lang>/LC_MESSAGES/webfontkitgenerator.mo`, already committed under `locale/` |
| Verified on screen | `LANGUAGE=de nix develop --command xvfb-run -a ruby test/drive_window.rb` passes under the `de` catalogue; `Options#subset_action_row('latin').title` returns `"Lateinisch"` under `LANGUAGE=de`, matching `po/de.po`'s `msgstr` |

Generated with `.claude/skills/translation-parity/scripts/catalogue.rb` against
an `origin/master` worktree and this tree, per the `translation-parity` skill.

## A scanner limitation, and why 16 rows below are hand-verified

The generated `--compare` run reports 18 "gap" rows, but 16 of them are not
gaps: they are upstream messages the port reaches through a **marked
constant-table lookup** — `_(FONT_DISPLAY.first)`, `_(SUBSET_TITLES.fetch(name))`,
`p_('shortcut window', title)` with `title` a hash key, `_(APP_NAME)` /
`_(TITLE)` — and the scanner's regex only reads a literal string argument, so
it cannot resolve these call sites to the keys they actually produce (the
`translation-parity` skill names this exact failure mode for dynamic-table
lookups and calls for hand-census when it occurs, rather than silently
counting the row as a pass or a gap). I opened each site below and confirmed
by hand that the constant's value is the upstream msgid, byte for byte. Per
the skill's "when the scanner is the thing that is wrong" rule, this is
recorded here rather than edited into the generated YAML, since the YAML is
regenerated and not hand-edited.

| msgctxt | msgid | Constant | Port site |
|---|---|---|---|
| — | `Disabled` | `Options::FONT_DISPLAY.first` | `lib/options.rb:104` (value), `lib/options.rb:305` (`_(FONT_DISPLAY.first)`) |
| — | `Latin` | `Options::SUBSET_TITLES['latin']` | `lib/options.rb:89` (value), `lib/options.rb:364` (`_(SUBSET_TITLES.fetch(name))`) |
| — | `Latin Extended` | `Options::SUBSET_TITLES['latin-ext']` | `lib/options.rb:90`, `lib/options.rb:364` |
| — | `Cyrillic` | `Options::SUBSET_TITLES['cyrillic']` | `lib/options.rb:91`, `lib/options.rb:364` |
| — | `Cyrillic Extended` | `Options::SUBSET_TITLES['cyrillic-ext']` | `lib/options.rb:92`, `lib/options.rb:364` |
| — | `Greek` | `Options::SUBSET_TITLES['greek']` | `lib/options.rb:93`, `lib/options.rb:364` |
| — | `Greek Extended` | `Options::SUBSET_TITLES['greek-ext']` | `lib/options.rb:94`, `lib/options.rb:364` |
| — | `Vietnamese` | `Options::SUBSET_TITLES['vietnamese']` | `lib/options.rb:95`, `lib/options.rb:364` |
| — | `Devanagari` | `Options::SUBSET_TITLES['devanagari']` | `lib/options.rb:96`, `lib/options.rb:364` |
| — | `Webfont Bundler` | `Application::APP_NAME` / `Window::TITLE` | `lib/webfont_kit_generator/application.rb:34,64,118`, `lib/window.rb:30,124` |
| shortcut window | `General` | `ShortcutsWindow#general_section` title | `lib/shortcuts_window.rb:57` (`shortcut_title('General')`), `shortcut_title` → `p_('shortcut window', title)` at `lib/shortcuts_window.rb:59` |
| shortcut window | `Show Shortcuts` | `ShortcutsWindow::SHORTCUTS['Show Shortcuts']` | `lib/shortcuts_window.rb:27`, same `shortcut_title` path |
| shortcut window | `Open Fonts` | `ShortcutsWindow::SHORTCUTS['Open Fonts']` | `lib/shortcuts_window.rb:28`, same path |
| shortcut window | `Select Output Directory` | `ShortcutsWindow::SHORTCUTS['Select Output Directory']` | `lib/shortcuts_window.rb:29`, same path |
| shortcut window | `Google Fonts Importer` | `ShortcutsWindow::SHORTCUTS['Google Fonts Importer']` | `lib/shortcuts_window.rb:30`, same path |
| shortcut window | `Generate` | `ShortcutsWindow::SHORTCUTS['Generate']` | `lib/shortcuts_window.rb:31`, same path |

All 16 are counted as `ported` in the totals above. The generated YAML will
keep reporting them as gaps until the skill's census scanner is extended to
follow a marker whose argument is a constant hash/array lookup; that is a
scanner defect, reported to the `translation-parity` skill, not a port defect.

## src/webfontkitgenerator/window.blp, window.py → lib/window.rb (15 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 1 | — | `Webfont Bundler` | single | 3 → 2 | `lib/window.rb:30,124` (`TITLE`) | ported (hand-verified above) |
| 2 | — | `_About Webfont Bundler` | single | 1 → 1 | `lib/window.rb:190` | ported |
| 3 | — | `_Keyboard Shortcuts` | single | 1 → 1 | `lib/window.rb:186` | ported |
| 4 | — | `Add some fonts` | single | 1 → 1 | `lib/window.rb:219` | ported |
| 5 | — | `Back` | single | 1 → 1 | `lib/window.rb:359` | ported |
| 6 | — | `Browse...` | single | 1 → 1 | `lib/window.rb:307` | ported |
| 7 | — | `Generate` | single | 1 → 1 | `lib/window.rb:313` | ported |
| 8 | — | `Information` | single | 1 → 1 | `lib/window.rb:530` | ported |
| 9 | — | `Logs` | single | 1 → 1 | `lib/window.rb:536` | ported |
| 10 | — | `Main Menu` | single | 1 → 1 | `lib/window.rb:162` | ported |
| 11 | — | `Open Fonts` | single | 2 → 2 | `lib/window.rb:154,234` | ported |
| 12 | — | `Open in Files` | single | 1 → 1 | `lib/window.rb:406` | ported |
| 13 | — | `Or import it directly to your CSS:` | single | 1 → 1 | `lib/window.rb:397` | ported |
| 14 | — | `Select Output Directory` | single | 2 → 2 | `lib/window.rb:297,435` | ported |
| 15 | — | `To link your fonts, copy the code below into the head of your HTML:` | single | 1 → 1 | `lib/window.rb:390` | ported |

## src/webfontkitgenerator/window.py → lib/window.rb (3 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 1 | — | `Open Font Files` | single | 1 → 1 | `lib/window.rb:441` | ported |
| 2 | — | `OTF & TTF` | single | 1 → 1 | `lib/window.rb:450` | ported |
| 3 | — | `You don’t have write access to the selected directory.` | single | 1 → 1 | `lib/window.rb:109` | ported |

## src/webfontkitgenerator/options.blp → lib/options.rb (19 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 1 | — | `Options` | single | 1 → 1 | `lib/options.rb:200` | ported |
| 2 | — | `CSS` | single | 1 → 1 | `lib/options.rb:208` | ported |
| 3 | — | `Subsetting` | single | 1 → 1 | `lib/options.rb:217` | ported |
| 4 | — | `Limit the character set to reduce file size` | single | 1 → 1 | `lib/options.rb:218` | ported |
| 5 | — | `Latin` | single | 1 → 1 | `lib/options.rb:89,364` | ported (hand-verified) |
| 6 | — | `Cyrillic` | single | 1 → 1 | `lib/options.rb:91,364` | ported (hand-verified) |
| 7 | — | `Greek` | single | 1 → 1 | `lib/options.rb:93,364` | ported (hand-verified) |
| 8 | — | `Vietnamese` | single | 1 → 1 | `lib/options.rb:95,364` | ported (hand-verified) |
| 9 | — | `Latin Extended` | single | 1 → 1 | `lib/options.rb:90,364` | ported (hand-verified) |
| 10 | — | `Cyrillic Extended` | single | 1 → 1 | `lib/options.rb:92,364` | ported (hand-verified) |
| 11 | — | `Greek Extended` | single | 1 → 1 | `lib/options.rb:94,364` | ported (hand-verified) |
| 12 | — | `Devanagari` | single | 1 → 1 | `lib/options.rb:96,364` | ported (hand-verified) |
| 13 | — | `Custom` | single | 1 → 1 | `lib/options.rb:270` | ported |
| 14 | — | `Comma separated values. Single hex values and/or ranges separated with hyphens.` | single | 1 → 1 | `lib/options.rb:277` | ported |
| 15 | — | `Base64 Encode` | single | 1 → 1 | `lib/options.rb:296` | ported |
| 16 | — | `Embed fonts in the CSS` | single | 1 → 1 | `lib/options.rb:297` | ported |
| 17 | — | `Font display` | single | 1 → 1 | `lib/options.rb:303` | ported |
| 18 | — | `The CSS font-display descriptor` | single | 1 → 1 | `lib/options.rb:304` | ported |
| 19 | — | `Disabled` | single | 1 → 1 | `lib/options.rb:104,305` | ported (hand-verified) |

## src/webfontkitgenerator/google.blp, google.py → lib/google_dialog.rb (13 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 1 | — | `Import from Google Fonts` | single | 2 → 2 | `lib/google_dialog.rb:157`, `lib/window.rb:180` | ported |
| 2 | — | `Cancel` | single | 2 → 2 | `lib/google_dialog.rb:221`, `lib/window.rb:336` | ported |
| 3 | — | `Download fonts from Google Fonts for self-hosting` | single | 1 → 1 | `lib/google_dialog.rb:158` | ported |
| 4 | — | `Download Fonts` | single | 1 → 1 | `lib/google_dialog.rb:198` | ported |
| 5 | — | `Please set a valid url` | single | 1 → 1 | `lib/google_dialog.rb:328` | ported |
| 6 | — | `Loading Google Fonts Database` | single | 1 → 1 | `lib/google_dialog.rb:438` | ported |
| 7 | — | `Couldn’t download the Google Fonts data.` | single | 1 → 2 | `lib/google_dialog.rb:468,490` | ported ⚠ (reused one extra call site; not a translation gap) |
| 8 | — | `Couldn’t find any fonts for the given url.` | single | 1 → 1 | `lib/google_dialog.rb:507` | ported |
| 9 | — | `Couldn’t find the {family_name} font family.` | single | 1 → 1 | `lib/google_dialog.rb:522` | ported |
| 10 | — | `Couldn’t find the {variant} variant for {family_name}.` | single | 1 → 1 | `lib/google_dialog.rb:535` | ported |
| 11 | — | `Downloading {name}` | single | 1 → 1 | `lib/google_dialog.rb:554` | ported |
| 12 | — | `Couldn’t download the font file for {name}.` | single | 1 → 1 | `lib/google_dialog.rb:565` | ported |
| 13 | — | `Couldn’t write the font file for {name}.` | single | 1 → 1 | `lib/google_dialog.rb:580` | ported |

## src/webfontkitgenerator/generator.py → lib/generator.rb (9 messages)

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|
| 1 | `Generating fonts for {name}:` | single | 1 → 1 | `lib/generator.rb:1252` | ported |
| 2 | `Generating {name}` | single | 1 → 1 | `lib/generator.rb:1253` | ported |
| 3 | `No glyphs where found for {range}. Skipping.` | single | 1 → 1 | `lib/generator.rb:1313` | ported |
| 4 | `Generated <i>{filename}</i> with <i>{count}</i> glyphs.` | single | 1 → 1 | `lib/generator.rb:1330` | ported |
| 5 | `Generating CSS:` | single | 1 → 1 | `lib/generator.rb:1401` | ported |
| 6 | `Finishing` | single | 1 → 1 | `lib/generator.rb:1402` | ported |
| 7 | `There is no CSS to generate.` | single | 1 → 1 | `lib/generator.rb:1405` | ported |
| 8 | `Generated <i>{filename}</i>.` | single | 1 → 1 | `lib/generator.rb:1439` | ported |
| 9 | `Generation finished!` | single | 2 → 2 | `lib/generator.rb:1216`, `lib/window.rb:375` | ported |

## src/webfontkitgenerator/loader.py → lib/loader.rb (2 messages)

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|
| 1 | `You don’t have read access to {font} or it doesn’t exists.` | single | 1 → 1 | `lib/loader.rb:276` | ported |
| 2 | `Error: {error}.` | single | 1 → 3 | `lib/generator.rb:1242`, `lib/loader.rb:282`, `lib/window.rb:740` | ported ⚠ (reused two extra call sites; not a translation gap) |

## src/webfontkitgenerator/gtk/help-overlay.blp → lib/shortcuts_window.rb (6 messages)

All six carry upstream's `msgctxt "shortcut window"` and are reached through
`ShortcutsWindow::SHORTCUTS` (a `title => accelerator` hash) via
`shortcut_title(title) = p_('shortcut window', title)` at
`lib/shortcuts_window.rb:59` — a dynamic second argument the census scanner
cannot resolve, hand-verified above.

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 1 | shortcut window | `General` | single | 1 → 1 | `lib/shortcuts_window.rb:57` | ported (hand-verified) |
| 2 | shortcut window | `Show Shortcuts` | single | 1 → 1 | `lib/shortcuts_window.rb:27` | ported (hand-verified) |
| 3 | shortcut window | `Open Fonts` | single | 1 → 1 | `lib/shortcuts_window.rb:28` | ported (hand-verified) |
| 4 | shortcut window | `Select Output Directory` | single | 1 → 1 | `lib/shortcuts_window.rb:29` | ported (hand-verified) |
| 5 | shortcut window | `Google Fonts Importer` | single | 1 → 1 | `lib/shortcuts_window.rb:30` | ported (hand-verified) |
| 6 | shortcut window | `Generate` | single | 1 → 1 | `lib/shortcuts_window.rb:31` | ported (hand-verified) |

## src/webfontkitgenerator/main.py → lib/webfont_kit_generator/application.rb (1 message)

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|
| 1 | `translator-credits` | single | 1 → 1 | `lib/webfont_kit_generator/application.rb:131` | ported |

(Upstream's `main.py:37` also carries `Webfont Bundler`, the window/app
title — counted once, under the `window.blp` table, where `Application::APP_NAME`
and `Window::TITLE` are defined and used.)

## data/com.rafaelmardojai.WebfontKitGenerator.metainfo.xml.in (2 messages)

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|
| 1 | `Webfont Bundler is a simple utility that allows you to generate woff, woff2 and the necessary CSS boilerplate from non-web font formats (otf and ttf).` | single | 1 → 1 | `lib/webfont_kit_generator/application.rb:127` (about dialog, first paragraph) | ported |
| 2 | `Webfont Bundler also includes a tool to Download fonts from Google Fonts for self-hosting.` | single | 1 → 1 | `lib/webfont_kit_generator/application.rb:131` (about dialog, second paragraph) | ported — closed this round; previously a gap because the about dialog only rendered the first `<p>` |

## Gaps

| # | msgctxt | msgid | Upstream sites | Text still owed | Waits on |
|---|---|---|---|---|---|
| 1 | — | `Create @font-face kits easily` | `data/com.rafaelmardojai.WebfontKitGenerator.desktop.in:3`, `data/com.rafaelmardojai.WebfontKitGenerator.metainfo.xml.in:7` | `Create @font-face kits easily` | The port ships no `data/com.rafaelmardojai.WebfontKitGenerator.desktop.in` or `.metainfo.xml.in` at all — `find data -type f` in this tree returns only icon SVGs. This string is the `.desktop` file's `Comment=` / the metainfo's `<summary>`, which the GNOME shell and app-grid search read from the installed `.desktop`/metainfo files, not from anything the running Ruby process can render. It cannot be closed by changing `lib/`; it needs that data/ packaging component built and listed in `po/POTFILES`. |
| 2 | — | `font;font-face;` | `data/com.rafaelmardojai.WebfontKitGenerator.desktop.in:10` | `font;font-face;` | Same cause: this is the `.desktop` file's `Keywords=` line, used only by desktop search indexing. No `data/*.desktop.in` exists in this port yet. |

Both gaps are real and both are component gaps, not translation gaps: the
msgids are known (above) and the 24 `.po` files already carry translations
for both, so closing them is "ship a `data/com.rafaelmardojai.WebfontKitGenerator.desktop.in`
and `.metainfo.xml.in`, mark their strings, add them to `po/POTFILES`" —
a packaging-data component this round did not build, not a string anyone
reworded or dropped.

## Extra

None. No message in the port's catalogue is absent from upstream's.

## Unrun checks

- `msgfmt -c` strict validation of the 24 `.po` files was not run in this
  session (no network check for `gettext-tools` beyond what the nix devshell
  already provides was performed beyond the `rake gettext:mo:update` compile
  already committed under `locale/`). The `.mo` files under `locale/` are
  present and were exercised by the `de` check below, which is evidence they
  compiled correctly, but a fresh `msgfmt -c` pass was not re-run this round.
