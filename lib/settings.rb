# frozen_string_literal: true

require 'json'
require 'fileutils'

# Settings holds the same keys, types and defaults as upstream's
# data/com.rafaelmardojai.WebfontKitGenerator.gschema.xml.
#
# Upstream uses GSettings, which needs the schema compiled and installed into a
# directory on XDG_DATA_DIRS before the app will even start. Requiring an
# install step to run the port from a checkout is worse than the alternative,
# so the same keys are backed by a small JSON file under XDG_CONFIG_HOME.
#
# Writes are flushed immediately, which is what GSettings does too, so the
# options page does not need to remember to save.
class Settings
  SCHEMA_ID = 'com.rafaelmardojai.WebfontKitGenerator'

  # Key => default, in the order the schema lists them. The booleans drive the
  # options page's switches, `font-display` is the index of the selected row in
  # its combo, and the two google-* keys are the Google Fonts API key and the
  # ETag of the last database download.
  DEFAULTS = {
    'woff2'            => true,
    'woff'             => false,
    'subsetting'       => false,
    'latin'            => true,
    'latin-ext'        => true,
    'cyrillic'         => true,
    'cyrillic-ext'     => true,
    'greek'            => true,
    'greek-ext'        => true,
    'vietnamese'       => false,
    'devanagari'       => false,
    'base64'           => false,
    'font-display'     => 0,
    'google-api-key'   => 'AIzaSyD8Uy0-Lhp20KwXzvED4E2OE5Y_YQmTEfA',
    'google-fonts-sha' => '',
  }.freeze

  def initialize(path: nil)
    @path = path || default_path
    @values = DEFAULTS.merge(read)
  end

  def location = @path

  def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

  def []=(key, value)
    @values[key.to_s] = value
    write
    value
  end

  # GSettings' typed getters, so callers read the same way they do upstream.
  def get_boolean(key) = self[key] == true
  def get_int(key) = self[key].to_i
  def get_string(key) = self[key].to_s
  def set_boolean(key, value) = self[key] = (value == true)
  def set_int(key, value) = self[key] = value.to_i
  def set_string(key, value) = self[key] = value.to_s

  private

    def default_path
      File.join(
        ENV.fetch('XDG_CONFIG_HOME', File.join(Dir.home, '.config')),
        'webfont-kit-generator',
        'settings.json',
      )
    end

    def read
      JSON.parse(File.read(@path)).select { |key, _| DEFAULTS.key?(key) }
    rescue Errno::ENOENT, JSON::ParserError
      {}
    end

    def write
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, "#{JSON.pretty_generate(@values)}\n")
    rescue SystemCallError => e
      warn "Could not save settings to #{@path}: #{e.message}"
    end
end
