#!/usr/bin/env ruby
# frozen_string_literal: true

# Drives the window itself: the empty state, the options sidebar, the app
# menu, the shortcuts dialog, the About dialog, the Google Fonts importer's
# client-side validation, the file-load error path, the remove-font action,
# the window accelerators, and the back action — everything
# test/drive_generator.rb does not already cover because it is aimed at one
# end-to-end generation.
#
# test/drive_generator.rb is the deep check on the generator pipeline (every
# byte of the WOFF/WOFF2 containers it writes); this script is the broad
# check on the rest of the port's UI surface — the window, its dialogs, its
# menu, and its empty/error states actually build and wire up.
#
# Run it from the dev shell:
#
#   nix develop --command xvfb-run -a ruby test/drive_window.rb
#
# Not exercised here, and said plainly rather than faked: the Google Fonts
# importer's actual network download (Soup::Session#send_and_read_async
# against https://www.googleapis.com) needs live network access, which this
# script does not assume. What is exercised here is everything before that
# call — URL parsing, entry validation, button sensitivity, cancel — which
# is the whole client-side surface the port is responsible for regardless
# of network.
#
# test/drive_google_fonts.rb is the companion script that drives the real
# network round trip (the live Google Fonts API, a real font-file download,
# real parsed font data) for environments that do have network access, and
# skips itself cleanly when they do not.

require 'fileutils'
require 'tmpdir'

require 'webfont_kit_generator'
require_relative 'gtk_driver'

# A scratch config directory, so a run never reads or writes the real one.
ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('webfont-window-drive')

SHOTS = File.expand_path('../tmp/shots', __dir__)
FileUtils.rm_rf(SHOTS)

def font_path
  ENV['WEBFONT_SAMPLE_FONT'] ||
    Dir.glob('/nix/store/*dejavu*/share/fonts/truetype/DejaVuSans.ttf').first ||
    abort('no sample font: set WEBFONT_SAMPLE_FONT to a .ttf')
end

# {selector => sorted declarations}, with whitespace, comments and
# brace-placement collapsed away — what is left is the only thing a CSS diff
# should care about.
def parse_css(text)
  text.gsub(%r{/\*.*?\*/}m, '').scan(/([^{}]+)\{([^{}]*)\}/m).to_h do |selector, body|
    [
      selector.strip.gsub(/\s+/, ' '),
      body.split(';').map { |rule| rule.strip.gsub(/\s+/, ' ') }.reject(&:empty?).sort,
    ]
  end
end

application = WebfontKitGenerator::Application.new(settings: Settings.new(path: File.join(Dir.mktmpdir, 'settings.json')))

GtkDriver.drive(application, shots: SHOTS) do |d, app|
  window = -> { app.window }

  d.window { window.call.window }

  # --- Empty state ---------------------------------------------------------

  d.step('empty state on launch') do
    d.check('main page is showing') { window.call.appstack.visible_child_name == 'main' }
    d.check('fonts stack shows the empty page') { window.call.fonts_stack.visible_child_name == 'empty' }
    d.check('sidebar is hidden with no fonts') { window.call.split.show_sidebar? == false }
    d.check('bottom bar is hidden with no fonts') { window.call.toolbar_view.reveal_bottom_bars? == false }
    d.check('generate is disabled with no fonts') { !window.call.window.lookup_action('generate').enabled? }
    d.check('open is enabled on the main page') { window.call.window.lookup_action('open').enabled? }
    d.check('set-dir is enabled on the main page') { window.call.window.lookup_action('set-dir').enabled? }
    d.shot('01-empty')
  end

  # --- Window accelerators --------------------------------------------------

  d.step('window accelerators are bound') do
    {
      'open'              => ['<Control>o'],
      'google'            => ['<Control>g'],
      'set-dir'           => ['<Control>d'],
      'back'              => ['Escape'],
      'show-help-overlay' => ['<Control>question'],
    }.each do |name, accels|
      d.check("win.#{name} is bound to #{accels}") { app.app.get_accels_for_action("win.#{name}") == accels }
    end
  end

  # --- App menu --------------------------------------------------------------

  d.step('the app menu has the importers and help sections') do
    d.check('app menu has two sections') { window.call.app_menu.n_items == 2 }
    d.check('importers section has one item') { window.call.importers_section.n_items == 1 }
    d.check('help section has two items') { window.call.help_section.n_items == 2 }
  end

  # --- Shortcuts dialog ------------------------------------------------------

  d.step('show-help-overlay opens the shortcuts dialog') do
    window.call.window.lookup_action('show-help-overlay').activate(nil)
  end

  d.step('the shortcuts dialog is built') do
    shortcuts = window.call.instance_variable_get(:@shortcuts_window)
    d.check('a ShortcutsWindow was built') { !shortcuts.nil? }
    d.check('it lists all five shortcuts') { shortcuts.general_section.n_items == 5 }
    d.check('the dialog is visible') { shortcuts.dialog.visible? }
    shortcuts.dialog.close
  end

  # --- About dialog ------------------------------------------------------------

  d.step('app.about opens the About dialog without raising') do
    d.check('the about action exists') { !app.about_action.nil? }
    d.check('activating it does not raise') do
      app.about_action.activate(nil)
      true
    rescue StandardError
      false
    end
  end

  # --- Google Fonts importer (client-side only — see header) -----------------

  d.step('win.google opens the importer') do
    window.call.window.lookup_action('google').activate(nil)
  end

  d.step('the importer validates the url without making a request') do
    google = window.call.instance_variable_get(:@google_dialog)
    d.check('a GoogleDialog was built') { !google.nil? }
    d.check('the dialog is visible') { google.dialog.visible? }
    d.check('download starts disabled') { google.download_button.sensitive? == false }

    google.url_entry.text = 'not a url at all'
    d.check('a bad url is flagged') { google.url_entry.has_css_class?('error') }
    d.check('a bad url keeps download disabled') { !google.download_button.sensitive? }
    d.check('a bad url reveals the error label') { google.error_revealer.reveal_child? }

    google.url_entry.text = 'https://fonts.googleapis.com/css2?family=Roboto'
    d.check('a good url clears the error class') { !google.url_entry.has_css_class?('error') }
    d.check('a good url enables download') { google.download_button.sensitive? }
    d.check('a good url hides the error label') { !google.error_revealer.reveal_child? }

    google.url_entry.text = ''
    # Clearing the entry only resets the error state (icon back to paste,
    # error class removed) — it does not touch download_button's
    # sensitivity, so a previously-valid url leaves it enabled. That is the
    # app's actual behaviour, not a bug this test should paper over.
    d.check('clearing the entry removes the error class') { !google.url_entry.has_css_class?('error') }

    d.shot('02-google-dialog')
    google.dialog.close
  end

  d.step('the importer parses both Google Fonts css api shapes') do
    google = window.call.instance_variable_get(:@google_dialog)
    v1 = google.parse_api_v1('family=Roboto:400,700|Open+Sans:400')
    d.check('css api v1 finds both families') { v1.map(&:name) == ['Roboto', 'Open Sans'] }

    v2 = google.parse_api_v2('family=Roboto:ital,wght@0,400;1,700')
    d.check('css api v2 finds the family') { v2.length == 1 && v2.first.name == 'Roboto' }
    d.check('css api v2 finds both variants') { v2.first.variants.sort == ['700italic', 'regular'].sort }
  end

  # --- Options sidebar: validation, subsetting, css options ------------------

  d.step('the custom subsetting entry validates as it is typed') do
    options = window.call.options
    options.custom_entry.text = 'not a unicode range'
    d.check('an invalid range is flagged red') { options.custom_entry.has_css_class?('error') }

    options.custom_entry.text = 'U+0041-005A,0041'
    d.check('a valid range clears the flag') { !options.custom_entry.has_css_class?('error') }

    options.custom_entry.text = ''
  end

  d.step('the options sidebar reports formats, subsetting and css choices') do
    options = window.call.options
    options.woff2_switch.active = true
    options.woff_switch.active = false
    d.check('woff2 alone is reported') { options.formats == ['woff2'] }

    options.woff_switch.active = true
    d.check('both formats are reported') { options.formats.sort == ['woff', 'woff2'] }

    options.subsetting_row.enable_expansion = false
    d.check('subsetting off reports nil') { options.subsetting.nil? }

    options.subsetting_row.enable_expansion = true
    options.subset_checks.each { |name, button| button.active = name == 'latin' }
    d.check('the active subset is reported') { options.subsetting&.keys == ['latin'] }

    options.base64_row.active = true
    d.check('base64 reports true once enabled') { options.base64? }
    options.base64_row.active = false

    options.font_display_row.selected = 0
    d.check('font-display row 0 (Disabled) reports nil') { options.font_display.nil? }

    options.font_display_row.selected = 3
    d.check('font-display row 3 reports "swap"') { options.font_display == 'swap' }
  end

  # --- Loading fonts: the error path, then the real one -----------------------

  d.step('loading an unreadable path leaves the model untouched') do
    window.call.load_fonts([Gio::File.new_for_path('/no/such/font.ttf')])
  end

  d.step('the bad path produced no font and no crash') do
    d.check('the model is still empty') { window.call.model.n_items.zero? }
    d.check('still showing the empty page') { window.call.fonts_stack.visible_child_name == 'empty' }
  end

  d.step('loading a file that is not a font at all is rejected, not crashed') do
    not_a_font = File.join(Dir.mktmpdir, 'not-a-font.ttf')
    File.write(not_a_font, 'this is plainly not sfnt data')
    window.call.load_fonts([Gio::File.new_for_path(not_a_font)])
  end

  d.step('the garbage file produced no font and no crash') do
    d.check('the model is still empty after garbage input') { window.call.model.n_items.zero? }
  end

  d.step('loading a real font populates the list') do
    window.call.load_fonts([Gio::File.new_for_path(font_path)])
  end

  d.step('the fonts page takes over') do
    d.check('one font loaded') { window.call.model.n_items == 1 }
    d.check('fonts stack shows the loaded font') { window.call.fonts_stack.visible_child_name == 'fonts' }
    d.check('sidebar appears once fonts are loaded') { window.call.split.show_sidebar? }
    d.check('bottom bar appears once fonts are loaded') { window.call.toolbar_view.reveal_bottom_bars? }
    d.check('generate is still disabled with no output dir') { !window.call.window.lookup_action('generate').enabled? }
    d.shot('03-fonts-loaded')
  end

  # --- Output directory: the unwritable-dir toast, then a real one -----------

  d.step('picking an unwritable directory is refused, not crashed') do
    window.call.select_out_dir(Gio::File.new_for_path('/root'))
  end

  d.step('the unwritable directory changed nothing') do
    d.check('the directory label is unchanged') { window.call.directory.label == 'Select Output Directory' }
    d.check('generate is still disabled') { !window.call.window.lookup_action('generate').enabled? }
  end

  d.step('picking a writable directory is accepted') do
    @out_dir = Dir.mktmpdir('webfont-window-drive-out')
    window.call.select_out_dir(Gio::File.new_for_path(@out_dir))
  end

  d.step('generate is now enabled') do
    d.check('the directory label shows the chosen folder') { window.call.directory.label == File.basename(@out_dir) }
    d.check('generate is enabled with a font and an output dir') { window.call.window.lookup_action('generate').enabled? }
  end

  # --- Removing a font --------------------------------------------------------

  d.step('win.remove-font drops the font by index') do
    window.call.window.lookup_action('remove-font').activate(GLib::Variant.new(0, GLib::VariantType.new('u')))
  end

  d.step('removing the only font returns to the empty state') do
    d.check('the model is empty again') { window.call.model.n_items.zero? }
    d.check('the empty page is showing again') { window.call.fonts_stack.visible_child_name == 'empty' }
    d.check('generate is disabled again') { !window.call.window.lookup_action('generate').enabled? }
    d.shot('04-removed-back-to-empty')
  end

  # --- File-chooser actions follow the visible page ---------------------------

  d.step('reload a font and move off the main page') do
    window.call.load_fonts([Gio::File.new_for_path(font_path)])
    window.call.appstack.visible_child_name = 'progress'
  end

  d.step('open/set-dir disable off the main page, back returns and re-enables them') do
    d.check('open is disabled off the main page') { !window.call.window.lookup_action('open').enabled? }
    d.check('set-dir is disabled off the main page') { !window.call.window.lookup_action('set-dir').enabled? }

    window.call.window.lookup_action('back').activate(nil)
    d.check('back returns to the main page') { window.call.appstack.visible_child_name == 'main' }
    d.check('open is enabled again on the main page') { window.call.window.lookup_action('open').enabled? }
    d.check('set-dir is enabled again on the main page') { window.call.window.lookup_action('set-dir').enabled? }
  end

  # --- The stylesheet, diffed against upstream --------------------------------

  # lib/style.rb was never diffed rule-by-rule against upstream's style.css;
  # this normalises both to {selector => sorted declarations} (collapsing
  # whitespace and brace-placement differences, which carry no meaning) and
  # compares the two rule sets for equality.
  d.step('lib/style.rb carries the same rules as upstream style.css') do
    upstream_css = File.read(File.join(__dir__, 'fixtures', 'upstream-style.css'))
    d.check('every upstream selector has a port rule with the same declarations') do
      parse_css(upstream_css) == parse_css(Style::CSS)
    end
  end
end
