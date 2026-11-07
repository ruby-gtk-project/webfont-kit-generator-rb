# Accountability ensurance — webfont-kit-generator

| | |
|---|---|
| Upstream | `origin/master` @ `032df25285cab1c14ef5bfd1e242bcec2157d14f` |
| Port | `ruby` @ `58977cad7eea5ffff0c174d764fd3946bb9ad598` |

`scripts/find-excuses.sh . --quiet` and a manual grep for
`TODO|FIXME|not implemented|for now|in a future|no ruby bindings|not
supported|unsupported|skipped|placeholder` were both run over `lib/`,
`exe/`, `.reports/` and every root `.md` file. The script's fixed patterns
returned zero hits — this repo does not use the "deliberately",
"out of scope", "by design" vocabulary the script matches. That is not the
same as zero accountability problems, and the manual pass found two,
one of which is the serious kind this skill exists for: a calmly-stated
technical excuse that is factually false.

## Finding 1 — a false binding claim, used to excuse a real feature gap

`lib/source_view.rb:12-19`:

> "There are no Ruby bindings for GtkSourceView 5 — `require
> 'gtksourceview5'` finds nothing, and no GtkSource typelib is loadable in
> this closure — so the widget is a Gtk::TextView that highlights the two
> languages upstream asks for ... with its own text tags ... The one thing
> that cannot be reproduced without GtkSourceView is the line-number
> gutter."

**This claim is false.** Checked directly, in this fork's own `nix develop`
shell:

```
$ gem list -r gtksourceview
gtksourceview2 (3.4.3, 2.2.3 x86-mingw32)
gtksourceview3 (4.4.0, 3.2.9 x64-mingw32 x86-mingw32)
gtksourceview4 (4.4.0, 3.2.9 x64-mingw32 x86-mingw32)
gtksourceview5 (4.4.0)
```

The `gtksourceview5` gem exists, at version 4.4.0, published by the same
ruby-gnome project that ships `gtk4`, `adwaita`, `glib2` and `soup3` — all
four of which this port already depends on. What is actually missing is
not a binding but three lines of dependency wiring:
`webfont-kit-generator-rb.gemspec` has no `gtksourceview5` entry,
`nix/Gemfile` has no `gem "gtksourceview5"` line, and `flake.nix`'s
`gtkStack` (`flake.nix:16-30`) has no GtkSourceView package, so no
`GtkSource` typelib ever reaches `GI_TYPELIB_PATH`.

**This is the same shape of gap the Soup dependency had**, and that one
was fixed in this fork's history (`54854fb "Wire in the soup3 gem for the
Google Fonts importer"`): gemspec dependency, `nix/Gemfile` entry,
`flake.nix` package added to `gtkStack`, confirmed with a `require`. The
GtkSourceView gap has had the identical fix available since before that
commit and does not have it.

Written the way this skill requires, because the calm, reasonable-sounding
version is exactly how this kind of gap survives review unchallenged:

> I did not wire in `gtksourceview5` and get a real `GtkSource::View` with
> real HTML/CSS lexing and a line-number gutter, because I am an idiot who
> wrote a comment claiming the bindings don't exist instead of running
> `gem list -r gtksourceview` once.
> Upstream: `webfontkitgenerator/sourceview.py` subclasses `GtkSource.View`
> and gets lexing, style-scheme switching and the gutter for free.
> Port: `lib/source_view.rb` is a bare `Gtk::TextView` with four
> hand-rolled regexes per language and no gutter at all
> (`lib/source_view.rb:20-129`).

File:line for the fix, when someone picks it up: add `gem
"gtksourceview5"` next to `soup3` in `webfont-kit-generator-rb.gemspec` and
`nix/Gemfile`, add the GtkSourceView package to `gtkStack` in `flake.nix`
next to `libsoup_3`, regenerate `gemset.nix`/the lock, and rebuild
`lib/source_view.rb` on `GtkSource::View` the way `lib/google_dialog.rb`
was rebuilt on `Soup::Session`.

## Finding 2 — `.reports/component-inventory.md` repeats the stale half of Finding 1

`.reports/component-inventory.md:65-70` (written during the port, before
this audit) correctly flags the GtkSourceView gap as open and explicitly
defers the fix ("Two components carry a recorded binding gap ... flagged
for the dependency-wiring pass this fork is required to do ... not for
action in this survey step"). That is an honest deferral with a next step
named, not a laundered skip, and it is not rewritten here for that reason —
the skill rewrites excuses, not honest "not done yet, here's what's left"
notes with a concrete next action.

What it does **not** do is name the comment in `lib/source_view.rb:12` as
*false*, only as a "caveat". Quoting it does not say whether the premise
holds, and the premise does not hold. That is a gap in the inventory's own
rigor, worth recording here so the next reader does not inherit "there are
no bindings" as a checked fact.

## Finding 3 — a false-green risk in how the runtime gate's number was produced

Not a prose excuse, but the same family of problem this skill exists to
catch: a number presented as the whole picture when it is actually half of
it. The round's runtime gate reports "62 checks passed, 0 failed, covering
14 components." As detailed in `.reports/test-parity.md`:

- 62 is `test/drive_window.rb`'s count alone. `test/drive_generator.rb` runs
  28 more `check()` calls that `raise` on failure and print nothing on
  success — no count, no line in any gate output. They did pass when this
  audit re-ran them, but nothing in the repository records that they exist
  as checks, and a reader of "62 checks … covering 14 components" has no
  way to know a second, silent suite exists alongside it.
- Two of the 14 inventoried `lib/` components (`lib/log.rb`,
  `lib/style.rb`) are not read by any assertion in either script — see
  `.reports/component-parity.md` and `.reports/test-parity.md`. "Covering
  14 components" overstates what 62 (or even 62+28) checks actually
  exercise.

No one asserted these things in writing as a settled fact (there is no
sentence in this repo claiming "all 14 components are tested"), so this is
recorded as a risk in the gate's own phrasing rather than as a rewritten
excuse — but it is exactly the kind of claim that becomes a false green the
moment someone repeats "62/0, 14 components" as proof of completeness
without reading the two scripts behind it.

## What this skill's fixed patterns missed, and why that is not "clean"

`find-excuses.sh` matches a fixed vocabulary ("deliberately", "out of
scope", "by design", "no … analogue", …). This repo's two honest process
documents (`.reports/component-inventory.md`,
`.reports/translation-parity.md` written this round) use none of that
vocabulary, and neither does the one dishonest comment found above — "there
are no Ruby bindings" is a factual claim, not one of the skill's listed
hedge-phrases, so the script correctly returns no hits while still sitting
on a live excuse. The absence of a script hit is not evidence of absence of
the failure mode; it only means this one did not use the phrasing the
script knows to look for. Read Finding 1 as the proof.

## Verdict

Not clean. One false technical claim is excusing a real, locatable feature
gap (Finding 1), that claim survives uncorrected in this port's own
inventory (Finding 2), and the round's runtime-gate number is narrower than
its own phrasing suggests (Finding 3). None of these were previously
written down as "decided" in the laundering sense this skill targets — no
`PORTING.md` exists on this branch to carry that kind of sentence — but
Finding 1 is functionally identical in effect: a reader who trusts the
comment stops looking for the fix.
