# frozen_string_literal: true

require 'adwaita'
require_relative 'translatable'

# ShortcutsWindow lists the window's keyboard shortcuts.
#
# Ported from upstream's webfontkitgenerator/gtk/help-overlay.blp, which GTK
# picks up automatically because it sits at the magic resource path and so
# becomes the window's `win.show-help-overlay` target.
#
# The blueprint's Gtk.ShortcutsWindow cannot be built from Ruby — the bindings
# raise "GtkWindow is not subtype of GtkShortcutsWindow" on construction, and
# the widget is deprecated in GTK 4.22 anyway — so the same one section of
# shortcuts is presented as the Adwaita replacement, Adw.ShortcutsDialog.
# AdwShortcutsDialog is a final GType, so this holds one rather than being one.
class ShortcutsWindow
  include Translatable

  # Title => accelerator, in help-overlay.blp's order. The accelerators are
  # the ones main.py binds; upstream writes "<Ctl>o" for Open Fonts, which is
  # not a modifier GTK knows, so the shortcut it advertises never fires. This
  # port binds the modifier upstream meant. The titles are marked at use, with
  # upstream's `msgctxt "shortcut window"` context, since that is what
  # `help-overlay.blp` ships them under.
  SHORTCUTS = {
    'Show Shortcuts'          => '<Control>question',
    'Open Fonts'              => '<Control>o',
    'Select Output Directory' => '<Control>d',
    'Google Fonts Importer'   => '<Control>g',
    'Generate'                => '<Control>Return',
  }.freeze

  def build
    dialog.tap do |dlg|
      dlg.add(general_section)

      general_section.tap do |section|
        SHORTCUTS.each { |title, accelerator| section.add(item(shortcut_title(title), accelerator)) }
      end
    end
  end

  def present(parent) = dialog.present(parent)

  def dialog
    @dialog ||= Adwaita::ShortcutsDialog.new.tap do |dlg|
      # Not an upstream msgid: AdwShortcutsDialog has no blueprint of its own
      # to carry one, so this title is left untranslated rather than
      # fabricating a msgid upstream never shipped.
      dlg.title = 'Keyboard Shortcuts'
    end
  end

  def general_section
    @general_section ||= Adwaita::ShortcutsSection.new(nil).tap do |section|
      section.title = shortcut_title('General')
    end
  end

  private

  # Positional, not keyword, arguments — even though the error a no-argument
  # `new` raises advertises the signatures as "title: utf8, accelerator: utf8".
    def item(title, accelerator) = Adwaita::ShortcutsItem.new(title, accelerator)

    def shortcut_title(title) = p_('shortcut window', title)
end
