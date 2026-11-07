# frozen_string_literal: true

require 'adwaita'
require_relative 'settings'
require_relative 'translatable'

# UnicodeRanges parses the unicode-range syntax the custom subset entry
# accepts: comma separated single hex values and hyphenated ranges, with or
# without the U+ prefix.
#
# It stands in for fontTools' `parse_unicodes`, which upstream imports both to
# validate the entry as it is typed and to expand the ranges when subsetting.
# The substitutions and the hex parsing below are that function's.
module UnicodeRanges
  # Raised for anything the syntax does not cover, so callers can treat a bad
  # entry the same way upstream treats parse_unicodes throwing.
  class Error < StandardError; end

  def self.parse(string)
    tokenize(string).flat_map { |token| codepoints(token) }
  end

  # True when the string is empty or parses cleanly. An empty entry is not an
  # error — it simply contributes no custom subset.
  def self.valid?(string)
    parse(string)
    true
  rescue Error
    false
  end

  def self.tokenize(string)
    string.to_s.gsub(/0[xX]/, ' ').gsub(/[<+>,;&#\\xXuU\n]/, ' ').split
  end

  def self.codepoints(token)
    token.split('-', -1).then do |fields|
      case fields.length
      when 1 then [hex(fields.first)]
      when 2 then Range.new(hex(fields.first), hex(fields.last)).to_a
      else raise Error, "Not a unicode range: #{token}"
      end
    end
  end

  def self.hex(field)
    unless field.match?(/\A[0-9A-Fa-f]+\z/)
      raise Error, "Not a hex value: #{field}"
    end

    field.hex
  end
end

# Options is the sidebar beside the font list: which webfont formats to write,
# which unicode subsets to split them into, and how the CSS should look.
#
# Ported from upstream's webfontkitgenerator/options.py and options.blp. The
# preference rows are bound to the settings in both directions, so a choice
# made here is still made the next time the app starts, exactly as upstream's
# Gio.Settings.bind does.
class Options
  include Translatable

  # Subset name => the unicode ranges it covers. These are Google Fonts'
  # ranges, copied from upstream's PRESET_RANGES.
  PRESET_RANGES = {
    'latin'        => 'U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,' \
                      'U+2000-206F,U+2074,U+20AC,U+2122,U+2212,U+2215',
    'latin-ext'    => 'U+0100-024F,U+0259,U+1E00-1EFF,U+20A0-20CF,U+2C60-2C7F,U+A720-A7FF',
    'cyrillic'     => 'U+0400-045F,U+0490-0491,U+04B0-04B1,U+2116',
    'cyrillic-ext' => 'U+0460-052F,U+1C80-1C88,U+20B4,U+2DE0-2DFF,U+A640-A69F,U+FE2E-FE2F',
    'greek'        => 'U+0370-03FF',
    'greek-ext'    => 'U+1F00-1FFF',
    'vietnamese'   => 'U+0102-0103,U+0110-0111,U+1EA0-1EF9,U+20AB',
    'devanagari'   => 'U+0900-097F,U+1CD0-1CF6,U+1CF8-1CF9,U+200B-200D,U+20A8,' \
                      'U+20B9,U+25CC,U+A830-A839,U+A8E0-A8FB',
  }.freeze

  # The two columns of subset checkboxes, in the order options.blp lists them.
  LEFT_SUBSETS = %w[latin cyrillic greek vietnamese].freeze
  RIGHT_SUBSETS = %w[latin-ext cyrillic-ext greek-ext devanagari].freeze

  # Row labels for the checkboxes, which are not just the key capitalised.
  # This used to be a constant table looked up with `_(SUBSET_TITLES.fetch
  # (name))` in `subset_action_row` — a non-literal `_()` argument that
  # xgettext cannot see, since it can only extract a literal string passed
  # directly to `_()`. `translated_subset_title` below marks each one with
  # its own literal `_()` call instead; `LEFT_SUBSETS`/`RIGHT_SUBSETS` above
  # stay the ordered key lists it is called with.
  #
  # Each `when` is a literal `_()` call xgettext can see; the `name` it
  # switches on is not translated itself, only used to pick which literal to
  # translate.
  def self.translated_subset_title(name)
    case name
    when 'latin' then _('Latin')
    when 'latin-ext' then _('Latin Extended')
    when 'cyrillic' then _('Cyrillic')
    when 'cyrillic-ext' then _('Cyrillic Extended')
    when 'greek' then _('Greek')
    when 'greek-ext' then _('Greek Extended')
    when 'vietnamese' then _('Vietnamese')
    when 'devanagari' then _('Devanagari')
    else raise ArgumentError, "Unknown subset: #{name}"
    end
  end

  # The font-display combo's rows. Row 0 means "emit no font-display at all",
  # which is why it is a label and not a descriptor value. Only "Disabled" is
  # an upstream msgid — the rest are CSS `font-display` values, not prose, and
  # upstream leaves them untranslated too; see `font_display_row` for where
  # "Disabled" is translated.
  FONT_DISPLAY = ['Disabled', 'auto', 'block', 'swap', 'fallback', 'optional'].freeze

  CUSTOM_PLACEHOLDER = '0021-007E,00E7,00EB,00C7,00CB'

  attr_reader :settings

  def initialize(settings)
    @settings = settings
  end

  def build
    page.tap do |options|
      options.add(formats_group)
      options.add(subsetting_group)
      options.add(css_group)

      formats_group.tap do |group|
        group.add(format_row('WOFF2', woff2_switch))
        group.add(format_row('WOFF', woff_switch))
      end

      subsetting_group.add(subsetting_row)

      subsetting_row.tap do |row|
        row.add_row(subsets_row)
        row.add_row(custom_row)

        custom_entry.signal_connect('changed') { validate_subsetting }
      end

      css_group.tap do |group|
        group.add(base64_row)
        group.add(font_display_row)
      end

      load_saved
    end
  end

  # --- What the generator asks for ----------------------------------------

  # The active formats, defaulting to woff2 when the user turned both off.
  def formats
    [['woff2', woff2_switch], ['woff', woff_switch]]
      .select { |_, switch| switch.active? }
      .map(&:first)
      .then do |active|
        if active.empty?
          ['woff2']
        else
          active
        end
      end
  end

  # Subset name => unicode ranges for every active subset, or nil when
  # subsetting is off or nothing is selected.
  def subsetting
    if subsetting_row.enable_expansion?
      active_ranges.then do |ranges|
        unless ranges.empty?
          ranges
        end
      end
    end
  end

  def base64? = base64_row.active?

  # The CSS font-display descriptor, or nil for the "Disabled" row.
  def font_display
    unless font_display_row.selected.zero?
      font_display_row.selected_item.string
    end
  end

  # --- Settings ------------------------------------------------------------

  # Two-way binding between each row and its setting, which is what upstream's
  # load_saved does with Gio.Settings.bind.
  def load_saved
    toggles.each { |key, widget| bind_active(key, widget) }
    bind_selected('font-display', font_display_row)
    bind_expansion('subsetting', subsetting_row)
  end

  # --- Widgets -------------------------------------------------------------

  def page
    @page ||= Adwaita::PreferencesPage.new.tap do |prefs|
      prefs.hexpand = true
    end
  end

  def formats_group
    @formats_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.title = _('Options')
    end
  end

  def subsetting_group = @subsetting_group ||= Adwaita::PreferencesGroup.new

  def css_group
    @css_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.title = _('CSS')
    end
  end

  def woff2_switch = @woff2_switch ||= format_switch
  def woff_switch = @woff_switch ||= format_switch

  def subsetting_row
    @subsetting_row ||= Adwaita::ExpanderRow.new.tap do |row|
      row.title = _('Subsetting')
      row.subtitle = _('Limit the character set to reduce file size')
      row.show_enable_switch = true
      row.add_css_class('expander')
    end
  end

  # The two columns of checkboxes share one non-activatable row, so the
  # dividing line between them runs the row's full height.
  def subsets_row
    @subsets_row ||= Gtk::ListBoxRow.new.tap do |row|
      row.activatable = false
      row.child = subsets_box
    end
  end

  def subsets_box
    @subsets_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.homogeneous = true
      box.hexpand = true
      box.append(left_subsets_list)
      box.append(right_subsets_list)
    end
  end

  def left_subsets_list
    @left_subsets_list ||= subsets_list(LEFT_SUBSETS).tap do |list|
      list.add_css_class('sub-left-box')
    end
  end

  def right_subsets_list = @right_subsets_list ||= subsets_list(RIGHT_SUBSETS)

  def custom_row
    @custom_row ||= Gtk::ListBoxRow.new.tap do |row|
      row.activatable = false
      row.child = custom_box
    end
  end

  def custom_box
    @custom_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.margin_top = 12
      box.margin_end = 12
      box.margin_start = 12
      box.margin_bottom = 12
      box.append(custom_label)
      box.append(custom_help)
      box.append(custom_entry)
    end
  end

  def custom_label
    @custom_label ||= Gtk::Label.new(_('Custom')).tap do |label|
      label.halign = :start
    end
  end

  def custom_help
    @custom_help ||= Gtk::Label.new(
      _('Comma separated values. Single hex values and/or ranges separated with hyphens.'),
    ).tap do |label|
      label.wrap = true
      label.wrap_mode = :word
      label.halign = :start
      label.add_css_class('subtitle')
    end
  end

  def custom_entry
    @custom_entry ||= Gtk::Entry.new.tap do |entry|
      entry.valign = :center
      entry.margin_top = 12
      entry.placeholder_text = CUSTOM_PLACEHOLDER
    end
  end

  def base64_row
    @base64_row ||= Adwaita::SwitchRow.new.tap do |row|
      row.title = _('Base64 Encode')
      row.subtitle = _('Embed fonts in the CSS')
    end
  end

  def font_display_row
    @font_display_row ||= Adwaita::ComboRow.new.tap do |row|
      row.title = _('Font display')
      row.subtitle = _('The CSS font-display descriptor')
      # A literal `_()` argument, not `_(FONT_DISPLAY.first)`: xgettext can
      # only see a literal string passed directly to `_()`.
      row.model = Gtk::StringList.new([_('Disabled'), *FONT_DISPLAY.drop(1)])
    end
  end

  # Checkbox per subset, keyed by subset name so load_saved can bind them.
  def subset_checks
    @subset_checks ||= PRESET_RANGES.keys.to_h do |name|
      [name, Gtk::CheckButton.new.tap { |check| check.valign = :center }]
    end
  end

  private

    def toggles
      [['woff2', woff2_switch], ['woff', woff_switch], ['base64', base64_row]]
        .concat(subset_checks.to_a)
    end

    def active_ranges
      PRESET_RANGES
        .select { |name, _| subset_checks.fetch(name).active? }
        .merge(custom_range)
    end

    def custom_range
      custom_entry.text.then do |text|
        if !text.empty? && UnicodeRanges.valid?(text)
          { 'custom' => text }
        else
          {}
        end
      end
    end

    def format_switch
      Gtk::Switch.new.tap do |switch|
        switch.valign = :center
      end
    end

    def format_row(title, switch)
      Adwaita::ActionRow.new.tap do |row|
        row.title = title
        row.activatable_widget = switch
        row.add_suffix(switch)
      end
    end

    def subsets_list(names)
      Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.add_css_class('sub-box')
        names.each { |name| list.append(subset_action_row(name)) }
      end
    end

    def subset_action_row(name)
      Adwaita::ActionRow.new.tap do |row|
        subset_checks.fetch(name).then do |check|
          row.title = Options.translated_subset_title(name)
          row.activatable_widget = check
          row.add_suffix(check)
        end
      end
    end

  # The entry turns red while its contents are not a unicode range, and goes
  # back to normal as soon as they are.
    def validate_subsetting
      if UnicodeRanges.valid?(custom_entry.text)
        custom_entry.remove_css_class('error')
      else
        custom_entry.add_css_class('error')
      end
    end

  # `active` carries both ways: a Gtk::Switch, a Gtk::CheckButton and an
  # Adwaita::SwitchRow all expose it.
    def bind_active(key, widget)
      widget.active = @settings.get_boolean(key)
      widget.signal_connect('notify::active') { @settings.set_boolean(key, widget.active?) }
    end

    def bind_selected(key, row)
      row.selected = @settings.get_int(key)
      row.signal_connect('notify::selected') { @settings.set_int(key, row.selected) }
    end

    def bind_expansion(key, row)
      row.enable_expansion = @settings.get_boolean(key)
      row.signal_connect('notify::enable-expansion') { @settings.set_boolean(key, row.enable_expansion?) }
    end
end
