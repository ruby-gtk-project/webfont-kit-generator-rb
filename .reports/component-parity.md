# Component parity — webfont-kit-generator-rb

| | |
|---|---|
| Upstream | `origin/master` @ `032df25285cab1c14ef5bfd1e242bcec2157d14f` |
| Port | `ruby` @ `6893c450641b22b129f7b5386dc08e4ed4a7b6e7` |

Each unit from `component-identification.md` compared on all four axes:
count, style, behaviour, text. The widget/css/signal/action scan was rerun
fresh this round (`component-scan.sh` against both worktrees) and every
count mismatch was opened and read rather than taken at face value.

**Re-verified this round, independently of the prior round's reading:**
every per-unit `union` diff below was re-run from clean worktrees of
`origin/master` and `origin/ruby`, and the window, options, Google dialog
and shortcuts-window file pairs were each re-read line by line against
`lib/window.rb`, `lib/options.rb`, `lib/google_dialog.rb` and
`lib/shortcuts_window.rb`. All four axes hold as this document already
described; nothing has regressed since `ea115ca`, and the one commit since
then (`6893c45`) only fixed two real defects on the Google-import path
(`GLib::Bytes#get_data` → `#to_s`; `glib-networking`/`GIO_EXTRA_MODULES`
wiring) and closed the two data/packaging translation gaps — neither
changes any row below. The text axis for every unit now also cross-checks
clean against this round's `translation-parity.md` (72/72, 0 gaps), which
is itself a widened recheck relative to the prior round's then-unreconciled
76 vs. 72 discrepancy.

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

## Google Fonts importer — PASS, now driven against a live response

State machine (URL validation, v1/v2 Google Fonts CSS parsing, ETag-cached
database fetch via `google-fonts-sha`, progress-bar pulse-then-determinate,
per-file download/tmp-write, error-collecting toast on failure) matches
`google.py` line for line. Driven: `test/drive_window.rb` steps 6-8 (dialog
construction, URL validation state transitions, both CSS API shapes parsed)
passed this round.

**Closed this round**: `test/drive_google_fonts.rb` makes the real network
round-trip this report previously flagged as unverified — a live GET
against `https://www.googleapis.com/webfonts/v1/webfonts` with the app's
real API key, a live per-file font download, and assertions against bytes
that actually came back over the wire (a real sfnt header, a font parsed
by name as "Roboto" out of the downloaded file, the on-disk ETag cache
written for real). It skips itself cleanly (exit 0, labelled `SKIPPED`)
when `www.googleapis.com` does not resolve, so it is safe in an offline
CI run but still exercises the real path whenever network is available.

Driving it for real caught two real defects that reading alone had missed,
both now fixed:

1. **`lib/google_dialog.rb`'s `store_database`/`write_font` called
   `bytes.get_data.to_s`** on the `GLib::Bytes` libsoup hands back from
   `send_and_read_finish`. This binding's `GLib::Bytes` has no `get_data`
   method (`to_s`/`to_str` return the raw bytes directly) — every real
   call raised `NoMethodError`, caught by a blanket `rescue StandardError`
   that silently fell back to "use the local cache or fail". The database
   fetch always looked successful (`Google Fonts Response Status 200 OK`
   printed every time) while never actually parsing a response. Fixed to
   `bytes.to_s` in both methods.
2. **`flake.nix`'s `gtkStack` had no TLS backend** for `libsoup_3`: every
   live HTTPS request failed with `TLS support is not available` until
   `glib-networking` was added to `gtkStack` and wired through
   `GIO_EXTRA_MODULES` in both the dev shell and the packaged wrapper.
   Without it, the Google Fonts importer cannot make a single real request
   in a from-scratch Nix build or devshell, on any machine, with or
   without network.

Both were real, silent failures on the actual execution path the soup3 gem
is required for — exactly the "a gem being `require`d and called is not
proof it works" trap this round's brief warns about. Re-run after the fix:
8 of 8 checks pass against the live API.

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
the catalogue. The root `TRANSLATION_PARITY.md` ledger was regenerated this
round (it previously still said `Gaps | 2` after the fix had already
landed); it now reports 72/72 messages ported, 0 gaps.

## Verdict

No missing window, dialog, page, menu item, keyboard shortcut, action,
preference, empty state or error state found this round. Every count
discrepancy the scan reported resolved to a scanner limitation (loop-built
widgets/actions) on reading, not a real gap. The only open item is the
Google Fonts live-network path, which is read but not driven against a
real server response — recorded above, not excused.
