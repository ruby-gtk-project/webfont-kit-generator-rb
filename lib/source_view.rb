# frozen_string_literal: true

require 'adwaita'
require 'gtksourceview5'

# SourceView shows the generated HTML and CSS snippets the user copies into
# their page, syntax highlighted and following the system light/dark setting.
#
# Ported from upstream's webfontkitgenerator/sourceview.py, which subclasses
# GtkSource.View and hands the highlighting to GtkSourceView's language
# definitions and its Adwaita/Adwaita-dark style schemes. The gtksourceview5
# gem (`require 'gtksourceview5'`) provides the same GtkSource::View here, so
# this port gets the real lexer, the real style schemes and the line-number
# gutter upstream has, instead of a hand-rolled regex highlighter.
class SourceView < GtkSource::View
  type_register

  attr_reader :language

  def initialize
    super()
    @language = ''
    self.show_line_numbers = true
    self.monospace = true
    self.editable = false
    self.wrap_mode = :word_char
    self.hexpand = true
    add_css_class('sourceview')
  end

  def build
    tap do
      buffer.highlight_matching_brackets = false

      style_manager.signal_connect('notify::dark') { apply_scheme }
      apply_scheme
    end
  end

  # Upstream exposes this as a GObject property set from the .blp template;
  # here the window sets it right after building the widget.
  def language=(value)
    @language = value.to_s
    buffer.language = language_manager.get_language(@language)
  end

  def set_text(text)
    buffer.text = text.to_s
  end

  private

    def style_manager = Adwaita::StyleManager.default

    def language_manager = @language_manager ||= GtkSource::LanguageManager.new

    def style_scheme_manager = @style_scheme_manager ||= GtkSource::StyleSchemeManager.new

    def adwaita_scheme = @adwaita_scheme ||= style_scheme_manager.get_scheme('Adwaita')

    def adwaita_dark_scheme = @adwaita_dark_scheme ||= style_scheme_manager.get_scheme('Adwaita-dark')

    def apply_scheme
      if style_manager.dark?
        buffer.style_scheme = adwaita_dark_scheme
      else
        buffer.style_scheme = adwaita_scheme
      end
    end
end
