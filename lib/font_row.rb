# frozen_string_literal: true

require 'adwaita'
require_relative 'font'

# FontRow is one row in the window's list of loaded fonts: the font's full
# name, the descriptors it will be generated with, and a button that drops it
# from the list again.
#
# Ported from the FontRow class in upstream's webfontkitgenerator/font.py.
# The remove button activates `win.remove-font` with the row's own index
# rather than calling back into the window, which is what keeps the row
# independent of whatever is holding it.
class FontRow < Adwaita::ActionRow
  type_register

  def initialize(font_data)
    super()
    @font_data = font_data
    self.title = font_data.name
    self.subtitle = font_data.descriptors.join(' / ')
  end

  def build
    tap do |row|
      row.add_suffix(remove_button)

      remove_button.signal_connect('clicked') { remove_font }
    end
  end

  def remove_button
    @remove_button ||= Gtk::Button.new.tap do |button|
      button.valign = :center
      button.icon_name = 'webfontkitgenerator-remove-symbolic'
      button.tooltip_text = 'Remove Font'
      button.add_css_class('flat')
      button.add_css_class('circular')
    end
  end

  private

  # The action parameter is a uint32, matching the GLib::VariantType the
  # window declares for `win.remove-font`.
    def remove_font
      activate_action(
        'win.remove-font',
        GLib::Variant.new(index, GLib::VariantType.new('u')),
      )
    end
end
