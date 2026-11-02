# frozen_string_literal: true

require 'adwaita'

# SourceView shows the generated HTML and CSS snippets the user copies into
# their page, syntax highlighted and following the system light/dark setting.
#
# Ported from upstream's webfontkitgenerator/sourceview.py, which subclasses
# GtkSource.View and hands the highlighting to GtkSourceView's language
# definitions and its Adwaita/Adwaita-dark style schemes.
#
# There are no Ruby bindings for GtkSourceView 5 — `require 'gtksourceview5'`
# finds nothing, and no GtkSource typelib is loadable in this closure — so the
# widget is a Gtk::TextView that highlights the two languages upstream asks
# for ("html" and "css") with its own text tags. The tag colours are swapped
# when Adwaita::StyleManager flips `dark`, which is the same signal upstream
# listens to in order to switch style scheme. The one thing that cannot be
# reproduced without GtkSourceView is the line-number gutter: a plain
# Gtk::TextView has no gutter to draw into.
class SourceView < Gtk::TextView
  type_register

  # One entry per tag the rules below reference. The light colours are the
  # Adwaita scheme's, the dark ones Adwaita-dark's.
  PALETTE = {
    light: {
      'element'   => '#1c71d8',
      'attribute' => '#c061cb',
      'string'    => '#26a269',
      'keyword'   => '#c64600',
    },
    dark:  {
      'element'   => '#78aeed',
      'attribute' => '#dc8add',
      'string'    => '#8ff0a4',
      'keyword'   => '#ffbe6f',
    },
  }.freeze

  # Applied in order, so a later tag paints over an earlier one where they
  # overlap: in `<link href="x.css">` the element rule claims `<link` and the
  # string rule then claims the quoted value.
  RULES = {
    'html' => [
      ['element', %r{</?[a-zA-Z][\w.:-]*|/?>}],
      ['attribute', /[\w-]+(?==)/],
      ['string', /"[^"\n]*"/],
    ],
    'css'  => [
      ['keyword', /@[\w-]+|\burl\b/],
      ['attribute', /[\w-]+(?=\s*:)/],
      ['string', /"[^"\n]*"|'[^'\n]*'/],
    ],
  }.freeze

  attr_reader :language

  def initialize
    super()
    @language = ''
    self.monospace = true
    self.editable = false
    self.wrap_mode = :word_char
    self.hexpand = true
    add_css_class('sourceview')
  end

  def build
    tap do
      PALETTE.fetch(:light).each_key { |name| buffer.tag_table.add(tag(name)) }

      style_manager.signal_connect('notify::dark') { apply_palette }
      apply_palette
    end
  end

  # Upstream exposes this as a GObject property set from the .blp template;
  # here the window sets it right after building the widget.
  def language=(value)
    @language = value.to_s
    highlight
  end

  def set_text(text)
    buffer.text = text.to_s
    highlight
  end

  private

    def style_manager = Adwaita::StyleManager.default

    def tag(name)
      tags[name] ||= Gtk::TextTag.new(name)
    end

    def tags = @tags ||= {}

    def apply_palette
      PALETTE.fetch(dark_variant).each { |name, colour| tag(name).foreground = colour }
    end

    def dark_variant
      if style_manager.dark?
        :dark
      else
        :light
      end
    end

    def highlight
      buffer.remove_all_tags(buffer.start_iter, buffer.end_iter)
      buffer.text.then do |text|
        RULES.fetch(@language, []).each { |name, pattern| apply_rule(text, name, pattern) }
      end
    end

    def apply_rule(text, name, pattern)
      text.to_enum(:scan, pattern).each do
        Regexp.last_match.then do |match|
          buffer.apply_tag(
            name,
            buffer.get_iter_at(offset: match.begin(0)),
            buffer.get_iter_at(offset: match.end(0)),
          )
        end
      end
    end
end
