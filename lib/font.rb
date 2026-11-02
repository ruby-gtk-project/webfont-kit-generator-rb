# frozen_string_literal: true

require 'adwaita'

# FontData is everything the generator needs to know about one font file:
# the names to show, the CSS descriptors to emit, and the `local()` sources
# that let a browser skip the download when the font is already installed.
#
# Ported from the FontData dataclass in upstream's webfontkitgenerator/font.py.
# A mutable class rather than a Data: the loader fills `style`, `weight`,
# `width`, `is_variable` and `local` in several passes as it works through the
# font's tables, exactly as upstream's _get_font_data does.
class FontData
  attr_accessor :name, :family, :version, :style, :weight, :width, :is_variable
  attr_reader :local

  def initialize(name:, family:, version:, style: 'normal', weight: '400', width: '100%', is_variable: false, local: nil)
    @name = name.to_s
    @family = family.to_s
    @version = version.to_s
    @style = style
    @weight = weight
    @width = width
    @is_variable = is_variable
    @local = local || []
  end

  def variable? = @is_variable == true

  # The file- and directory-name forms: "Fira Sans Bold" => "fira-sans-bold".
  def name_slug = slug(@name)
  def family_slug = slug(@family)

  # The subtitle upstream's FontRow shows, kept here because the generator
  # builds the same string into its log lines.
  def descriptors
    [
      @family,
      @style,
      @weight.tr(' ', '-'),
      @width.tr(' ', '-'),
    ]
  end

  private

    def slug(value) = value.split.join('-').downcase
end

# Font is one loaded font file: its path on disk and its parsed data.
#
# Ported from the Font GObject in upstream's webfontkitgenerator/font.py. It
# stays a GObject subclass because the window keeps the loaded fonts in a
# Gio::ListStore, and a list store can only hold GObjects.
class Font < GLib::Object
  type_register

  attr_accessor :path, :data

  def initialize(path, data)
    super()
    @path = path
    @data = data
  end
end
