# frozen_string_literal: true

require 'adwaita'
require_relative 'font'

# Loader turns the files the user opened, dropped or imported from Google
# Fonts into Font objects in the window's list model.
#
# Ported from upstream's webfontkitgenerator/loader.py. Upstream reads the
# font's tables with fontTools (`TTFont(path, lazy=True)`); there is no
# fontTools for Ruby and no font-parsing gem in this app's closure, so the
# three tables upstream actually reads — `head` for the mac style bits, `name`
# for every name string, `fvar` for the variation axes — are read by Sfnt
# below. Everything after that, including fontTools' name-table preference
# order, is the same logic upstream runs.
class Loader
  # Style name => CSS font-weight, as upstream's WEIGHTS.
  WEIGHTS = {
    'thin'       => '100',
    'extralight' => '200',
    'light'      => '300',
    'regular'    => '400',
    'medium'     => '500',
    'semibold'   => '600',
    'bold'       => '700',
    'extrabold'  => '800',
    'black'      => '900',
  }.freeze

  # Style name => CSS font-stretch, as upstream's WIDTHS.
  WIDTHS = {
    'ultracondensed' => '50%',
    'extracondensed' => '62.5%',
    'condensed'      => '75%',
    'semicondensed'  => '87.5%',
    'normal'         => '100%',
    'semiexpanded'   => '112.5%',
    'expanded'       => '125%',
    'extraexpanded'  => '150%',
    'ultraexpanded'  => '200%',
  }.freeze

  # Sfnt reads the handful of OpenType tables this port needs out of a .ttf,
  # .otf or .ttc file.
  #
  # It stands in for fontTools' TTFont: the table directory, the `head`
  # table's macStyle, the `name` table's records with fontTools'
  # getDebugName/getBestFullName/getBestFamilyName preference order, and the
  # `fvar` table's axis ranges.
  class Sfnt
    # The sfnt version tags this port accepts: TrueType outlines, CFF
    # outlines ('OTTO'), and the old Mac 'true'. A collection ('ttcf') is read
    # through its first font.
    TRUE_TYPE = "\x00\x01\x00\x00"
    COLLECTION = 'ttcf'
    ACCEPTED = [TRUE_TYPE, 'OTTO', 'true'].freeze

    # fontTools prefers the Mac English and Windows US-English name records
    # over whatever else a font carries.
    PREFERRED_NAMES = [[1, 0], [3, 0x409]].freeze

    def initialize(bytes)
      @bytes = bytes.b
      @offset = font_offset
      @tables = read_directory
    end

    # { "glyf" => bytes, … } for every table the directory lists. The loader
    # only reads three of them; the generator rewrites the set and packs it
    # back into a WOFF container, so it needs them all.
    def tables
      @table_bytes ||= @tables.keys.to_h { |tag| [tag, table(tag)] }
    end

    # The four bytes the font opens with — 0x00010000 for TrueType outlines,
    # 'OTTO' for CFF ones. Both WOFF containers carry it through unchanged as
    # their `flavor` field.
    def sfnt_version = @bytes[@offset, 4]

    def mac_style
      table('head').then do |head|
        if head.nil?
          0
        else
          head[44, 2].unpack1('n')
        end
      end
    end

    # { "wght" => [min, default, max], … }, as fontTools' fvar.getAxes.
    def axes
      @axes ||= read_axes
    end

    # fontTools' NameRecord.getDebugName: the preferred English record for the
    # name id, else the first record carrying it, else nil.
    def debug_name(name_id)
      names.select { |key, _| key[3] == name_id }.then do |matching|
        matching.find { |key, _| PREFERRED_NAMES.include?([key[0], key[2]]) }.then do |english|
          if english
            english.last
          else
            matching.values.first
          end
        end
      end
    end

    # fontTools' getBestFamilyName: typographic family, WWS family, family.
    def best_family_name = first_debug_name([21, 16, 1])

    # fontTools' getBestFullName: a family/subfamily pair at the most specific
    # level the font provides, with "Regular" left off, falling back to the
    # full name record.
    def best_full_name
      [[21, 22], [16, 17], [1, 2]].filter_map do |family_id, subfamily_id|
        [debug_name(family_id), debug_name(subfamily_id)].then do |family, subfamily|
          if family && subfamily
            full_name(family, subfamily)
          end
        end
      end.first.then { |found| found || debug_name(4) }
    end

    private

      def full_name(family, subfamily)
        if subfamily == 'Regular'
          family.strip
        else
          "#{family} #{subfamily}".strip
        end
      end

      def first_debug_name(name_ids)
        name_ids.filter_map { |name_id| debug_name(name_id) }.first
      end

      def table(tag)
        @tables[tag].then do |record|
          if record
            @bytes[record.first, record.last]
          end
        end
      end

    # A collection's header is 'ttcf', a uint32 version, a uint32 font count
    # and then the offsets of each font's own offset table.
      def font_offset
        if @bytes[0, 4] == COLLECTION
          @bytes[12, 4].unpack1('N')
        else
          0
        end
      end

      def read_directory
        unless ACCEPTED.include?(@bytes[@offset, 4])
          raise ArgumentError, 'Not an OpenType or TrueType font file'
        end

        @bytes[@offset + 4, 2].unpack1('n').then do |count|
          (0...count).to_h do |index|
            @bytes[@offset + 12 + (index * 16), 16].then do |record|
              [record[0, 4], record[8, 8].unpack('N2')]
            end
          end
        end
      end

    # { [platform id, encoding id, language id, name id] => string }
      def names
        @names ||= read_names
      end

      def read_names
        table('name').then do |data|
          if data.nil?
            {}
          else
            read_name_records(data)
          end
        end
      end

      def read_name_records(data)
        data[2, 4].unpack('n2').then do |count, storage|
          (0...count).each_with_object({}) do |index, found|
            data[6 + (index * 12), 12].unpack('n6').then do |platform, encoding, language, name_id, length, offset|
              decode(data[storage + offset, length], platform).then do |string|
                if string
                  found[[platform, encoding, language, name_id]] = string
                end
              end
            end
          end
        end
      end

    # Platform 1 is Mac, whose strings are MacRoman; platforms 0 and 3 are
    # Unicode and Windows, both UTF-16BE.
      def decode(bytes, platform)
        if bytes.nil?
          nil
        else
          source_encoding(platform).then do |encoding|
            bytes.dup.force_encoding(encoding).encode('UTF-8', invalid: :replace, undef: :replace)
          end
        end
      end

      def source_encoding(platform)
        if platform == 1
          'macRoman'
        else
          'UTF-16BE'
        end
      end

    # fvar: a header, then `axis_count` records of `axis_size` bytes, each a
    # 4-byte tag and three 16.16 fixed-point values.
      def read_axes
        table('fvar').then do |data|
          if data.nil?
            {}
          else
            read_axis_records(data)
          end
        end
      end

      def read_axis_records(data)
        [data[4, 2].unpack1('n'), *data[8, 4].unpack('n2')].then do |array_offset, count, size|
          (0...count).to_h do |index|
            data[array_offset + (index * size), size].then do |record|
              [record[0, 4], record[4, 12].unpack('N3').map { |fixed| fixed_to_float(fixed) }]
            end
          end
        end
      end

    # 16.16 fixed point, read as a signed value.
      def fixed_to_float(fixed)
        if fixed >= 0x8000_0000
          (fixed - 0x1_0000_0000) / 65_536.0
        else
          fixed / 65_536.0
        end
      end
  end

  def initialize(window, model)
    @window = window
    @model = model
  end

  # `files` is anything enumerable of Gio::File — the file dialog's result,
  # a drop's file list, or the temporary files the Google importer wrote.
  def load(files)
    @window.processing = true
    files.each { |file| load_file(file) }
    @window.processing = false
  end

  private

    def load_file(file)
      unquote(file.path.to_s).then do |path|
        if readable?(path)
          # Upstream posts the append through GLib.idle_add; load runs on the
          # main thread in both ports, so appending directly is the same thing.
          @model.append(Font.new(path, font_data(Sfnt.new(File.binread(path)))))
        else
          show_error("You don’t have read access to #{path} or it doesn’t exists.")
        end
      end
    rescue StandardError => e
      warn "Error loading #{file.path}"
      warn e.message
      show_error("Error: #{e.message}.")
    end

  # Gio hands back percent-encoded paths for files that came from a URI, which
  # is upstream's reason for running them through urllib's unquote.
    def unquote(path) = path.gsub(/%([0-9A-Fa-f]{2})/) { Regexp.last_match(1).hex.chr }

    def readable?(path) = !path.empty? && File.exist?(path) && File.readable?(path)

    def show_error(text)
      @window.toasts.add_toast(Adwaita::Toast.new(text))
    end

  # --- Reading one font's data -------------------------------------------

    def font_data(sfnt)
      FontData.new(
        name:    sfnt.best_full_name,
        family:  sfnt.best_family_name,
        version: sfnt.debug_name(5),
      ).tap do |data|
        apply_mac_style(data, sfnt.mac_style)
        apply_variations(data, sfnt.axes)
        apply_local_names(data, sfnt)
        apply_guessed_names(data, sfnt)
      end
    end

  # The `head` table's macStyle bits: bit 0 is bold, bit 1 is italic.
    def apply_mac_style(data, mac_style)
      unless (mac_style & 0b1).zero?
        data.weight = '700'
      end
      unless (mac_style & 0b10).zero?
        data.style = 'italic'
      end
    end

  # A font with an `fvar` table is variable, and its wght/wdth axis ranges
  # become the CSS ranges.
  #
  # The wdth branch writes the width range into `weight`, not `width`. That is
  # upstream's behaviour — loader.py assigns
  # `font_data.weight = self.__get_font_width_axis_range(wdth)` — and it is
  # reproduced here rather than corrected, so the two ports generate the same
  # CSS for the same font.
    def apply_variations(data, axes)
      if axes.any?
        data.is_variable = true
        axes['wght'].then do |wght|
          if wght
            data.weight = weight_axis_range(wght)
          end
        end
        axes['wdth'].then do |wdth|
          if wdth
            data.weight = width_axis_range(wdth)
          end
        end
      end
    end

    def weight_axis_range(values)
      [values.min.to_i, values.max.to_i].then do |low, high|
        if low == high
          high.to_s
        else
          "#{low} #{high}"
        end
      end
    end

    def width_axis_range(values)
      [values.min, values.max].then do |low, high|
        if low == high
          format('%g%%', high)
        else
          format('%g%% %g%%', low, high)
        end
      end
    end

  # `local()` sources, so a browser with the font installed never downloads
  # it: the PostScript name always, plus the full name when it differs.
    def apply_local_names(data, sfnt)
      data.local << %(local("#{sfnt.debug_name(4)}"))
      unless sfnt.debug_name(6) == sfnt.debug_name(4)
        data.local << %(local("#{sfnt.debug_name(6)}"))
      end
    end

  # Style, weight and width are guessed from the typographic subfamily (or the
  # subfamily) plus the full name, the same two strings upstream joins.
    def apply_guessed_names(data, sfnt)
      normalize([sfnt.debug_name(17) || sfnt.debug_name(2), sfnt.debug_name(4)].join(' ').split).each do |word|
        if word == 'italic'
          data.style = 'italic'
        end
        if sfnt.axes.empty?
          apply_guessed_metrics(data, word)
        end
      end
    end

    def apply_guessed_metrics(data, word)
      if WEIGHTS.key?(word)
        data.weight = WEIGHTS[word]
      elsif WIDTHS.key?(word)
        data.width = WIDTHS[word]
      end
    end

    def normalize(names) = names.map { |name| name.downcase.delete('-_') }
end
