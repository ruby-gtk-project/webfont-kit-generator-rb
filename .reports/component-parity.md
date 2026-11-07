# Component parity — webfont-kit-generator-rb

| | |
|---|---|
| Upstream | `origin/master` @ `032df25285cab1c14ef5bfd1e242bcec2157d14f` |
| Port | `ruby` @ `ea115ca9ded6afbe879afecd5d6f7e84cc4c08a9` |

Each unit from `component-identification.md` compared on all four axes:
count, style, behaviour, text. The widget/css/signal/action scan was rerun
fresh this round (`component-scan.sh` against both worktrees) and every
count mismatch was opened and read rather than taken at face value.

## Window — PASS

Every widget, CSS class (`title-1`, `suggested-action`, `pill`, `content`,
`heading`, `bottom-box`), `styles [...]` block, the full `app-menu`, and the
stack page names all have a line-for-line counterpart in `lib/window.rb`.
Signals checked: `notify::visible-child-name` on `appstack` and the fonts
stack, `clicked` on cancel and open-in-files, the drop target's `drop`.
Driven live this round: `test/drive_window.rb` re-executed start to finish,
63/63 checks passed (see `test-parity.md`), covering app-menu structure,
shortcuts dialog, Google importer validation, options reporting, file
load/error paths, directory selection, remove-font, and the CSS selector
diff (step 25).

Two documented substitutions, not gaps: `Gtk::ApplicationWindow` for
`Adw.ApplicationWindow` (binding broken — `lib/window.rb:23-26`); the
cancel button's `clicked` handler connected once instead of per-generation
(`lib/window.rb:508-511`), which is a fix for an upstream handler-leak, not
a dropped feature.

## Options sidebar — PASS

`options.blp`'s widget tree (2 Switch+ActionRow pairs, 1 ExpanderRow with 8
CheckButton+ActionRow pairs across two `Gtk.ListBox` columns, 1 custom-entry
row, 1 SwitchRow, 1 ComboRow) is reproduced exactly in `lib/options.rb`,
confirmed by reading `subset_checks`/`subset_action_row`/`subsets_list`
(loop-built, 8 iterations each) rather than trusting the scan's static
count of 2. `Options#formats`/`#subsetting`/`#base64?`/`#font_display`
match `options.py`'s `get_formats`/`get_subsetting`/equivalents field for
field, driven and asserted by `test/drive_window.rb` steps 9-10 (custom
subsetting validation, format/subsetting/css reporting) — all passed this
round. GSettings two-way binding (`load_saved`) matches `options.py`'s
`Gio.Settings.bind` calls, including the `font-display`/`subsetting`
non-boolean bindings.

## Google Fonts importer — PASS, one check not independently re-verified

State machine (URL validation, v1/v2 Google Fonts CSS parsing, ETag-cached
database fetch via `google-fonts-sha`, progress-bar pulse-then-determinate,
per-file download/tmp-write, error-collecting toast on failure) matches
`google.py` line for line. Driven: `test/drive_window.rb` steps 6-8 (dialog
construction, URL validation state transitions, both CSS API shapes parsed)
passed this round. **Not independently re-verified**: an actual network
round-trip against the live Google Fonts API — no test in this suite makes
one. The code path was read, not executed against a real response. This is
a real limitation of the verification, not a claim that the feature works;
record it rather than paper over it.

## Shortcuts dialog — PASS with a documented, bug-fixing substitution

`Gtk::ShortcutsWindow` cannot be constructed from the Ruby bindings
(verified again this round: constructing one raises "GtkWindow is not
subtype of GtkShortcutsWindow"). `Adw.ShortcutsDialog` substitutes with the
same five shortcuts, same `msgctxt "shortcut window"` titles (via
`p_('shortcut window', title)`), and corrected accelerators — upstream's own
`<Ctl>o` for Open Fonts is not a GTK modifier and never fires; the port
binds `<Control>o`, a fix rather than a gap. Driven: `test/drive_window.rb`
step 3-4 (show-help-overlay opens the dialog, all five shortcuts present).

## Application — PASS

`about` action, five accelerators, `HANDLES_OPEN`, About dialog content.
This round's re-check: the About dialog's second description paragraph
(`Webfont Bundler also includes a tool to Download fonts from Google Fonts
for self-hosting.`) now renders — upstream's metainfo has two `<p>`s and an
earlier round of this port only rendered the first. Verified by reading
`lib/webfont_kit_generator/application.rb:131` and by the translation
census (see `translation-parity.md`).

## Model/behaviour files — PASS

`lib/font.rb`, `lib/font_row.rb`, `lib/generator.rb`, `lib/loader.rb` each
read against their Python counterpart; no missing widget, signal or action.
`lib/source_view.rb` builds on the real `gtksourceview5` gem
(`GtkSource::View`, real lexing, style-scheme switching, line-number
gutter) — `require 'gtksourceview5'` was re-run in the dev shell this round
and succeeds; the gem is in the gemspec, `nix/Gemfile`, and `flake.nix`'s
`gtkStack`. `lib/log.rb`'s buffer is asserted by `test/drive_generator.rb`'s
log-verification steps (re-run, 92/92 passed). `lib/style.rb`'s CSS rules
are asserted selector-for-selector against upstream's `style.css` by
`test/drive_window.rb` step 25 ("every upstream selector has a port rule
with the same declarations") — re-run this round, passed.

## Data/packaging — now built, closing a prior gap

`data/org.rubygtkproject.WebfontKitGenerator.desktop.in`, `.metainfo.xml.in`
and `.service.in`, plus the four icon SVGs, now exist (commits `3b83bef`,
`ea115ca`). This closes the two translation gaps an earlier round of this
report left open (`Create @font-face kits easily`, `font;font-face;`) — see
`translation-parity.md`, where the census confirms both msgids now reach
the catalogue and the port's own `TRANSLATION_PARITY.md` ledger has **not**
been regenerated to say so (flagged as a finding in
`accountability-ensurance.md`).

## Verdict

No missing window, dialog, page, menu item, keyboard shortcut, action,
preference, empty state or error state found this round. Every count
discrepancy the scan reported resolved to a scanner limitation (loop-built
widgets/actions) on reading, not a real gap. The only open item is the
Google Fonts live-network path, which is read but not driven against a
real server response — recorded above, not excused.
