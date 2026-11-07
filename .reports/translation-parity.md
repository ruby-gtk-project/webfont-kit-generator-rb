# Translation parity — webfont-kit-generator-rb

| | |
|---|---|
| Upstream | `origin/master` @ `032df25285cab1c14ef5bfd1e242bcec2157d14f` |
| Port | `ruby` @ `994afff9c734e0a7e3c144514eea3d0b6cc953e9` |

## The catalogue content: every msgid survives

```
diff <(git show origin/master:po/webfontkitgenerator.pot | grep '^msgid' | sort -u) \
     <(grep '^msgid' po/webfontkitgenerator.pot | sort -u)
```
→ no differences. The committed `.pot`'s msgid set is byte-identical to
upstream's. Checked the same way for four translated locales (`ru`, `de`,
`fr`, `es`): each has exactly 73 `msgid` entries, matching upstream exactly,
and spot-checked translations (`"Webfont Bundler"` → `"Генератор набора
веб-шрифтов"`, `"Show Shortcuts"` → `"Показать горячие клавиши"` in `ru.po`)
are present and non-empty. `po/LINGUAS` matches upstream's list of 24
locales exactly.

So: nothing was dropped from the shipped catalogue. That is the good half of
this report.

## The gap: the port's own extraction tooling cannot reproduce 15 of those msgids

The Rakefile ships a documented, working command for regenerating the
catalogue from source (`rake gettext:pot:create`, `Rakefile:213-224`,
wrapping `GetText::Tools::XGetText.run` over `lib/**/*.rb` and `exe/*`).
Re-run this round (output saved, then the working tree restored with `git
checkout -- po/webfontkitgenerator.pot` — nothing was left modified):

```
diff <(grep '^msgid' <committed .pot> | sort -u) <(grep '^msgid' <freshly re-extracted .pot> | sort -u)
```

The freshly-extracted `.pot` is **missing** these 15 msgids that the
committed one carries and that real `.po` translations exist for:

```
Create @font-face kits easily
Cyrillic
Cyrillic Extended
Devanagari
Disabled
font;font-face;
General
Google Fonts Importer
Greek
Greek Extended
Latin
Latin Extended
Show Shortcuts
Vietnamese
Webfont Bundler
```

Root cause, confirmed by reading the call sites: `xgettext`/`rxgettext` can
only extract a literal string argument to `_()`/`p_()`. Several of this
port's translated strings are passed as variables instead:

- `lib/window.rb:124`: `win.title = _(TITLE)` — `TITLE` is a constant, not a
  literal, so `"Webfont Bundler"` is invisible to the extractor.
- `lib/webfont_kit_generator/application.rb:64,118`: `_(APP_NAME)`, same
  shape — same msgid, same invisibility.
- `lib/options.rb:364`: `_(SUBSET_TITLES.fetch(name))` — the 8 subset range
  names (Latin, Latin Extended, Cyrillic, Cyrillic Extended, Greek, Greek
  Extended, Vietnamese, Devanagari) are built from a hash lookup in a loop,
  so none of them is a literal `_()` argument.
- `lib/shortcuts_window.rb:67`: `p_('shortcut window', title)` where `title`
  is the loop variable over `SHORTCUTS` — the context argument is a literal
  (`'shortcut window'` is extracted fine, elsewhere) but the message itself
  (`"Show Shortcuts"`, `"General"`, …) is not.
- `"Google Fonts Importer"` is both a shortcut title (same loop-variable
  problem) and upstream's menu-item label at `window.blp`'s `importers-section`
  — in the port that label is `section.append(_('Import from Google Fonts'),
  ...)` (a different, correctly-literal string); `"Google Fonts Importer"`
  itself only exists as the shortcuts-dialog title, which is the same
  loop-variable gap.
- `"Create @font-face kits easily"` and `"font;font-face;"` are the
  `metainfo.xml.in`/`.desktop.in` summary and keywords. `po/POTFILES` only
  lists `lib/**/*.rb`-derived files (`lib/webfont_kit_generator/application.rb`,
  `lib/window.rb`, `lib/options.rb`, `lib/google_dialog.rb`,
  `lib/generator.rb`, `lib/loader.rb`, `lib/font_row.rb`,
  `lib/shortcuts_window.rb`) — there is no port-side desktop/metainfo file
  these two strings could be extracted from at all, literal or not.

The committed `.pot` and the 24 `.po` files are not wrong — their content
was verified above to be complete and correct. But they were not produced,
and cannot currently be reproduced, by the tool the project documents as the
way to maintain them. They match upstream because upstream's own catalogue
was carried over wholesale when the port was written, not because
`rake gettext:pot:create` can regenerate that match. The first contributor
who adds a new translatable string and runs the documented command will get
a `.pot` that is silently missing these 15 entries relative to what is
actually shown in the UI, and merging `.po` updates against that narrower
`.pot` will eventually drop the translations for "Webfont Bundler", the
eight subset names, and the four shortcuts-dialog-only titles.

## A second, related gap: nothing ships or builds the compiled catalogue

`lib/translatable.rb` binds gettext to `locale/` (`LOCALE_DIR =
File.expand_path('../locale', __dir__)`), which is populated by
`rake gettext:mo:update` (`Rakefile:198-209`) compiling `po/*.po` into
`locale/<lang>/LC_MESSAGES/webfontkitgenerator.mo`. `locale/` is gitignored
(`.gitignore:` `locale`, `/locale/`) and currently exists in this checkout
with 24 locale subdirectories — compiled by someone, at some point, by hand.

Neither `flake.nix`'s dev shell nor the gemspec's `spec.files` (which lists
`po/**/*` but not `locale/**/*`) wires `gettext:mo:update` into anything
that runs automatically:
- The dev shell has no `shellHook` step that compiles the `.mo` files, so a
  fresh clone's `nix develop` shell has translations bound to a `locale/`
  directory that does not exist, until someone remembers to run the rake
  task by hand.
- The gemspec ships no compiled catalogue, so an installed release gem
  (`gem install webfont-kit-generator-rb`) would have `po/*.po` on disk but
  no `locale/*/LC_MESSAGES/*.mo` anywhere `bindtextdomain` can find, which
  means every non-English locale silently falls back to the English
  (untranslated) strings for an end user, not a crash — the quiet kind of
  gap that is easy to miss because the app still runs.

Neither of these was checked by `test/drive_*.rb`: both drive scripts run
under whatever locale the host process is in (no `LANG`/`LANGUAGE`
override observed in either script), so neither one actually exercises a
translated string end to end.

## Verdict

Not clean. The shipped catalogue content is complete (every upstream msgid
is present, every spot-checked translation is present), but the
maintenance pipeline that regenerates it is demonstrably lossy when actually
run, and nothing in the build, packaging, or dev-shell setup compiles or
ships the catalogue an end user's non-English UI depends on.
