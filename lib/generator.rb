# frozen_string_literal: true

require 'fiddle'
require 'fileutils'
require 'set'
require 'zlib'

require 'adwaita'

require_relative 'font'
require_relative 'loader'
require_relative 'options'
require_relative 'translatable'

# Generator turns the window's loaded fonts into a webfont kit: one font file
# per format per unicode range, a stylesheet per family declaring them, and
# the HTML and CSS snippets that link the result.
#
# Ported from upstream's webfontkitgenerator/generator.py. The work happens on
# a thread, as it does upstream, and every touch of a widget is posted back to
# the main loop — upstream through GLib.idle_add, here through GLib::Idle.add.
#
# Upstream reaches the whole job through fontTools: `Subsetter` drops the
# glyphs outside a range, and `TTFont.flavor = 'woff2'` writes the compressed
# container. There is no fontTools for Ruby and no font gem in this app's
# closure, so the three things it is used for live here as nested classes:
# Subset reduces a font to the glyphs a range needs, and Woff and Woff2 are
# the two containers fontTools' `flavor` writes. Brotli, which WOFF2 is
# compressed with, is the same C library fontTools' `brotli` dependency wraps,
# called through Fiddle.
#
# Two upstream behaviours are deliberately not reproduced:
#
#   * The log line for a range with no glyphs interpolates Python's `range`
#     builtin — `text = range if range else name` — and so always reads "No
#     glyphs where found for <class 'range'>". This port interpolates the
#     range, which is what the line means to say.
#   * `run` connects the cancel button's `clicked` signal on every
#     generation, so upstream's handlers accumulate across runs. Here the
#     window owns that connection and forwards it to the generator it last
#     started.
class Generator
  include Translatable

  # Raised for a font this port cannot take apart, or a compressor it cannot
  # reach. The log and a toast carry the message.
  class Error < StandardError; end

  # Brotli is the compressor WOFF2 is defined in terms of, bound straight to
  # libbrotlienc with Fiddle: upstream reaches the same library through
  # fontTools' `brotli` dependency.
  #
  # The dev shell and the packaged wrapper both export WEBFONT_BROTLI_LIB,
  # because a Nix store path is on no loader search path. Elsewhere the
  # sonames are enough — libbrotlienc ships with curl, fontconfig and
  # harfbuzz, so a desktop with GTK on it has one.
  module Brotli
    # BROTLI_MODE_FONT, and the quality and window size the WOFF2 reference
    # encoder uses.
    MODE_FONT = 2
    QUALITY = 11
    WINDOW = 22

    CANDIDATES = [
      ENV.fetch('WEBFONT_BROTLI_LIB', nil),
      'libbrotlienc.so.1',
      'libbrotlienc.so',
      'libbrotlienc.dylib',
    ].compact.freeze

    def self.available? = !library.nil?

    # The compressed bytes, or nil when there is no library to compress with.
    def self.compress(bytes)
      library.then do |handle|
        unless handle.nil?
          encode(bytes.b)
        end
      end
    end

    def self.library
      unless @looked_up
        @looked_up = true
        @library = CANDIDATES.lazy.filter_map { |name| open_library(name) }.first
      end
      @library
    end

    def self.open_library(name)
      Fiddle.dlopen(name)
    rescue Fiddle::DLError
      nil
    end

    def self.encode(input)
      Fiddle::Pointer.malloc(max_size(input.bytesize), Fiddle::RUBY_FREE).then do |buffer|
        [buffer.size].pack('J').then do |size|
          compress_into(input, size, buffer).then do |ok|
            if ok.zero?
              raise Error, 'Brotli could not compress the font data'
            end

            buffer.to_str(size.unpack1('J'))
          end
        end
      end
    end

    # `size` goes in holding the buffer's capacity and comes back holding how
    # much of it was used, which is why it is a packed string and not an
    # Integer.
    def self.compress_into(input, size, buffer)
      encoder.call(
        QUALITY,
        WINDOW,
        MODE_FONT,
        input.bytesize,
        input,
        size,
        buffer,
      )
    end

    def self.max_size(length) = sizer.call(length)

    # BROTLI_BOOL BrotliEncoderCompress(int quality, int lgwin, int mode,
    #   size_t input_size, const uint8_t* input, size_t* encoded_size,
    #   uint8_t* encoded);
    def self.encoder
      @encoder ||= Fiddle::Function.new(
        library['BrotliEncoderCompress'],
        [
          Fiddle::TYPE_INT,
          Fiddle::TYPE_INT,
          Fiddle::TYPE_INT,
          Fiddle::TYPE_SIZE_T,
          Fiddle::TYPE_VOIDP,
          Fiddle::TYPE_VOIDP,
          Fiddle::TYPE_VOIDP,
        ],
        Fiddle::TYPE_INT,
      )
    end

    # size_t BrotliEncoderMaxCompressedSize(size_t input_size);
    def self.sizer
      @sizer ||= Fiddle::Function.new(
        library['BrotliEncoderMaxCompressedSize'],
        [Fiddle::TYPE_SIZE_T],
        Fiddle::TYPE_SIZE_T,
      )
    end
  end

  # Subset is one font reduced to the glyphs a unicode range needs. It stands
  # in for fontTools' `Subsetter`.
  #
  # The reduction keeps every glyph id and empties the outlines of the glyphs
  # the range does not reach, rather than renumbering the glyphs the way
  # fontTools does. Renumbering means rewriting `cmap`, `hmtx` and every
  # layout table that names a glyph; emptying leaves all of those valid
  # untouched, costs the few bytes of the now-unreachable `cmap` entries, and
  # drops the thing that actually makes a font big. The CSS the generator
  # writes carries the matching `unicode-range`, so a browser never asks one
  # of these files for a character whose outline is gone.
  #
  # TrueType outlines are emptied by giving the glyph a zero-length `glyf`
  # record, which is how a blank glyph is spelled. CFF outlines cannot be
  # shortened that way: the CharStrings INDEX's offsets are reachable from the
  # Top DICT, so moving them would mean re-encoding offsets across the whole
  # table. Each unused charstring is instead overwritten in place with
  # `endchar` repeated to its original length — the interpreter stops at the
  # first byte, so the glyph draws nothing, every offset stays valid, and the
  # run of identical bytes costs almost nothing once the table is Deflate- or
  # Brotli-compressed. Deprecated `seac` accent composition is the one thing
  # this misses: a CFF glyph assembled out of two others by `endchar` would
  # lose its parts.
  class Subset
    # The order fontTools' getBestCmap prefers `cmap` subtables in.
    PREFERENCE = [[3, 10], [0, 6], [0, 4], [3, 1], [0, 3], [0, 2], [0, 1], [0, 0]].freeze

    # Composite glyph component flags, from the `glyf` table spec.
    ARG_1_AND_2_ARE_WORDS = 0x0001
    WE_HAVE_A_SCALE = 0x0008
    MORE_COMPONENTS = 0x0020
    WE_HAVE_AN_X_AND_Y_SCALE = 0x0040
    WE_HAVE_A_TWO_BY_TWO = 0x0080

    # The CFF charstring operator that ends a glyph.
    ENDCHAR = "\x0E"

    # The highest codepoint a `cmap` group may claim.
    MAX_CODEPOINT = 0x10FFFF

    # One `cmap` format 4 segment, so the four parallel arrays the format
    # stores travel together.
    Segment = Struct.new(
      :start_code,
      :end_code,
      :delta,
      :range_offset,
      :position,
    )

    # True when this port can drop outlines from the font at all. A font with
    # neither `glyf` nor `CFF ` — a CFF2 variable font, say — is still
    # converted, but every range gets the whole thing.
    def self.reducible?(sfnt) = sfnt.tables.key?('glyf') || sfnt.tables.key?('CFF ')

    # `unicodes` is the codepoints the range covers, or nil for no subsetting
    # at all, which is the branch upstream takes when subsetting is off.
    def initialize(sfnt, unicodes = nil)
      @sfnt = sfnt
      @unicodes = unicodes
    end

    def flavor = @sfnt.sfnt_version

    def reducible? = Subset.reducible?(@sfnt)

    # True when the range reaches none of the font's characters, which is the
    # state upstream detects as an empty `getBestCmap` and skips.
    def empty? = covered.empty?

    # The glyphs this subset draws, less `.notdef` — the count upstream logs
    # as `len(font.getGlyphOrder()) - 1`.
    def glyph_count = [retained.length - 1, 0].max

    def tables
      @tables ||= rewrite
    end

    private

      def source = @sfnt.tables

      def num_glyphs
        @num_glyphs ||= source['maxp'].then do |maxp|
          if maxp.nil?
            0
          else
            maxp[4, 2].unpack1('n')
          end
        end
      end

      # --- What the range covers -------------------------------------------

      def covered
        @covered ||= cmap.keys.select { |code| wanted?(code) }
      end

      def wanted?(code)
        if @unicodes.nil?
          true
        else
          unicode_set.include?(code)
        end
      end

      def unicode_set = @unicode_set ||= Set.new(@unicodes)

      def retained
        @retained ||= closure(covered.map { |code| cmap.fetch(code) }.push(0).uniq)
      end

      def retained_set = @retained_set ||= Set.new(retained)

      # A composite TrueType glyph draws other glyphs, which have to be kept
      # as well — and so do theirs.
      def closure(seeds)
        if glyf?
          expand(seeds)
        else
          in_range(seeds).sort
        end
      end

      def in_range(glyphs) = glyphs.select { |glyph| glyph < num_glyphs }

      def expand(seeds)
        [in_range(seeds), Set.new].then do |queue, found|
          found.merge(queue)
          until queue.empty?
            in_range(components(queue.shift)).each do |component|
              unless found.include?(component)
                found << component
                queue << component
              end
            end
          end
          found.to_a.sort
        end
      end

      # --- cmap -------------------------------------------------------------

      def cmap = @cmap ||= read_cmap

      def read_cmap
        source['cmap'].then do |data|
          if data.nil?
            {}
          else
            subtable_offsets(data).filter_map { |offset| read_subtable(data, offset) }.first || {}
          end
        end
      end

      # The subtable offsets, best first: fontTools' preference order, with
      # anything it does not name left in the order the font lists it.
      def subtable_offsets(data)
        data[2, 2].to_s.unpack1('n').to_i.then do |count|
          (0...count).map { |index| data[4 + (index * 8), 8].to_s.unpack('n2N') }
        end.then do |records|
          records.each_with_index
            .sort_by { |record, index| [preference(record), index] }
            .map { |record, _| record.last }
        end
      end

      def preference(record)
        PREFERENCE.index([record[0], record[1]]) || PREFERENCE.length
      end

      def read_subtable(data, offset)
        subtable(data, offset).then do |found|
          unless found.nil? || found.empty?
            found
          end
        end
      end

      def subtable(data, offset)
        data[offset, 2].to_s.unpack1('n').then do |format_id|
          case format_id
          when 0 then byte_cmap(data, offset)
          when 4 then segment_cmap(data, offset)
          when 6 then trimmed_cmap(data, offset)
          when 12 then group_cmap(data, offset)
          end
        end
      end

      # Format 0: one byte of glyph id per codepoint, 256 of them.
      def byte_cmap(data, offset)
        data[offset + 6, 256].to_s.bytes.each_with_index.each_with_object({}) do |(glyph, code), found|
          unless glyph.zero?
            found[code] = glyph
          end
        end
      end

      # Format 4: the segmented mapping every TrueType font carries.
      def segment_cmap(data, offset)
        (data[offset + 6, 2].to_s.unpack1('n').to_i / 2).then do |count|
          segments(data, offset, count).each_with_object({}) do |segment, found|
            map_segment(data, found, segment)
          end
        end
      end

      def segments(data, offset, count)
        segment_arrays(data, offset, count * 2).then do |ends, starts, deltas, range_offsets, base|
          (0...count).map do |index|
            Segment.new(
              starts[index],
              ends[index],
              deltas[index],
              range_offsets[index],
              base + (index * 2),
            )
          end
        end
      end

      # endCode, startCode, idDelta and idRangeOffset, each `width` bytes
      # long, plus the position idRangeOffset is counted from.
      def segment_arrays(data, offset, width)
        [
          data[offset + 14, width].to_s.unpack('n*'),
          data[offset + 16 + width, width].to_s.unpack('n*'),
          data[offset + 16 + (width * 2), width].to_s.unpack('n*'),
          data[offset + 16 + (width * 3), width].to_s.unpack('n*'),
          offset + 16 + (width * 3),
        ]
      end

      def map_segment(data, found, segment)
        unless segment.start_code.nil? || segment.end_code.nil? || segment.start_code > segment.end_code
          (segment.start_code..segment.end_code).each do |code|
            unless code == 0xFFFF
              record_glyph(found, code, segment_glyph(data, segment, code))
            end
          end
        end
      end

      def record_glyph(found, code, glyph)
        unless glyph.nil? || glyph.zero?
          found[code] = glyph
        end
      end

      def segment_glyph(data, segment, code)
        if segment.range_offset.zero?
          (code + segment.delta) & 0xFFFF
        else
          indexed_glyph(data, segment, code)
        end
      end

      def indexed_glyph(data, segment, code)
        (segment.position + segment.range_offset + ((code - segment.start_code) * 2)).then do |at|
          data[at, 2].then do |raw|
            if raw.nil? || raw.bytesize < 2
              nil
            else
              delta_applied(raw.unpack1('n'), segment.delta)
            end
          end
        end
      end

      def delta_applied(glyph, delta)
        if glyph.zero?
          nil
        else
          (glyph + delta) & 0xFFFF
        end
      end

      # Format 6: a run of glyph ids starting at one codepoint.
      def trimmed_cmap(data, offset)
        data[offset + 6, 4].to_s.unpack('n2').then do |first, count|
          (0...count.to_i).each_with_object({}) do |index, found|
            data[offset + 10 + (index * 2), 2].to_s.unpack1('n').then do |glyph|
              record_glyph(found, first + index, glyph)
            end
          end
        end
      end

      # Format 12: grouped ranges, which is how anything past the BMP is
      # mapped.
      def group_cmap(data, offset)
        data[offset + 12, 4].to_s.unpack1('N').to_i.then do |groups|
          (0...groups).each_with_object({}) do |index, found|
            map_group(found, data[offset + 16 + (index * 12), 12].to_s.unpack('N3'))
          end
        end
      end

      def map_group(found, group)
        group.then do |first, last, glyph|
          unless first.nil? || last.nil? || last < first
            (first..[last, MAX_CODEPOINT].min).each_with_index do |code, step|
              found[code] = glyph + step
            end
          end
        end
      end

      # --- Rewriting the tables ---------------------------------------------

      def rewrite
        if @unicodes.nil?
          source.dup
        elsif glyf?
          source.merge(rewritten_glyf)
        elsif source.key?('CFF ')
          source.merge('CFF ' => emptied_cff(source['CFF ']))
        else
          source.dup
        end
      end

      def glyf?
        source.key?('glyf') && source.key?('loca') && source.key?('head') && num_glyphs.positive?
      end

      # The glyphs the range keeps, in glyph-id order, with everything else
      # given a zero-length record. `loca` keeps the format the font already
      # used, which it can: the new offsets are never past the old ones.
      def rewritten_glyf
        [+''.b, [0]].then do |data, offsets|
          (0...num_glyphs).each do |glyph|
            data << glyph_bytes(glyph)
            offsets << data.bytesize
          end
          { 'glyf' => data, 'loca' => pack_loca(offsets) }
        end
      end

      def glyph_bytes(glyph)
        if retained_set.include?(glyph)
          glyph_data(glyph).to_s.b.then { |bytes| bytes + padding(bytes.bytesize) }
        else
          +''.b
        end
      end

      # Short `loca` counts in words, so a record has to start on an even
      # byte; the long format is padded to four, the way fontTools pads it.
      def padding(length)
        if long_loca?
          "\x00".b * ((-length) % 4)
        else
          "\x00".b * ((-length) % 2)
        end
      end

      def pack_loca(offsets)
        if long_loca?
          offsets.pack('N*')
        else
          offsets.map { |offset| offset / 2 }.pack('n*')
        end
      end

      def long_loca? = index_to_loc_format == 1

      def index_to_loc_format
        @index_to_loc_format ||= source['head'][50, 2].unpack1('n')
      end

      def loca_offsets
        @loca_offsets ||= read_loca
      end

      def read_loca
        source['loca'].to_s.then do |data|
          if long_loca?
            data.unpack('N*')
          else
            data.unpack('n*').map { |offset| offset * 2 }
          end
        end
      end

      def glyph_data(glyph)
        loca_offsets.then do |offsets|
          if glyph + 1 < offsets.length && offsets[glyph + 1] > offsets[glyph]
            source['glyf'][offsets[glyph], offsets[glyph + 1] - offsets[glyph]]
          end
        end
      end

      # The glyphs a composite glyph draws. A simple glyph draws none.
      def components(glyph)
        glyph_data(glyph).then do |data|
          if data.nil? || data.bytesize < 10 || data[0, 2].unpack1('n') < 0x8000
            []
          else
            read_components(data)
          end
        end
      end

      def read_components(data)
        position = 10
        found = []
        more = true
        while more && position + 4 <= data.bytesize
          data[position, 4].unpack('n2').then do |flags, index|
            found << index
            position += component_size(flags)
            more = !(flags & MORE_COMPONENTS).zero?
          end
        end
        found
      end

      def component_size(flags)
        4 + argument_size(flags) + transform_size(flags)
      end

      def argument_size(flags)
        if (flags & ARG_1_AND_2_ARE_WORDS).zero?
          2
        else
          4
        end
      end

      def transform_size(flags)
        if !(flags & WE_HAVE_A_TWO_BY_TWO).zero?
          8
        elsif !(flags & WE_HAVE_AN_X_AND_Y_SCALE).zero?
          4
        elsif !(flags & WE_HAVE_A_SCALE).zero?
          2
        else
          0
        end
      end

      # --- CFF ---------------------------------------------------------------

      def emptied_cff(data)
        charstring_ranges(data).then do |ranges|
          if ranges.nil?
            data
          else
            blank_charstrings(data, ranges)
          end
        end
      end

      def blank_charstrings(data, ranges)
        data.dup.b.tap do |bytes|
          ranges.each_with_index do |range, glyph|
            unless retained_set.include?(glyph) || range.last.zero?
              bytes[range.first, range.last] = ENDCHAR.b * range.last
            end
          end
        end
      end

      def charstring_ranges(data)
        charstrings_offset(data).then do |offset|
          if offset.nil? || offset <= 0 || offset >= data.bytesize
            nil
          else
            index_ranges(data, offset)
          end
        end
      end

      # The CFF header's size is its third byte; the Name INDEX follows it and
      # the Top DICT INDEX follows that. The Top DICT's operator 17 holds the
      # CharStrings INDEX's offset from the start of the table.
      def charstrings_offset(data)
        index_end(data, data.getbyte(2).to_i).then do |position|
          index_ranges(data, position).then do |ranges|
            unless ranges.nil? || ranges.empty?
              dict_operand(data[ranges.first.first, ranges.first.last].to_s, 17)
            end
          end
        end
      end

      # A CFF INDEX: a uint16 count, a one-byte offset width, count + 1
      # offsets of that width, then the data they index — one-based from the
      # byte before it.
      def index_ranges(data, position)
        index_count(data, position).then do |count|
          if count.zero?
            []
          else
            index_offsets(data, position, count).then do |offsets|
              (0...count).map { |index| [offsets[index], offsets[index + 1] - offsets[index]] }
            end
          end
        end
      end

      def index_count(data, position) = data[position, 2].to_s.unpack1('n').to_i

      # The absolute position of every entry's first byte, with one extra past
      # the end so each entry's length is a subtraction.
      def index_offsets(data, position, count)
        data.getbyte(position + 2).to_i.then do |width|
          (position + 2 + ((count + 1) * width)).then do |base|
            (0..count).map { |index| base + offset_value(data, position + 3 + (index * width), width) }
          end
        end
      end

      def offset_value(data, at, width)
        data[at, width].to_s.bytes.inject(0) { |value, byte| (value << 8) | byte }
      end

      def index_end(data, position)
        index_count(data, position).then do |count|
          if count.zero?
            position + 2
          else
            index_offsets(data, position, count).last
          end
        end
      end

      # The operand of a one-byte DICT operator. DICT operands come before
      # their operator, so the stack is collected and read when one arrives.
      def dict_operand(dict, key)
        operands = []
        position = 0
        found = nil
        while position < dict.bytesize && found.nil?
          dict.getbyte(position).then do |byte|
            if byte <= 21
              if byte == key
                found = operands.last
              end
              operands = []
              position += dict_operator_size(byte)
            else
              dict_number(dict, position).then do |value, after|
                operands << value
                position = after
              end
            end
          end
        end
        found
      end

      def dict_operator_size(byte)
        if byte == 12
          2
        else
          1
        end
      end

      # [value, the position after it] for one DICT operand.
      def dict_number(dict, position)
        dict.getbyte(position).then do |byte|
          case byte
          when 28 then [signed(dict[position + 1, 2].to_s.unpack1('n'), 16), position + 3]
          when 29 then [signed(dict[position + 1, 4].to_s.unpack1('N'), 32), position + 5]
          when 30 then dict_real(dict, position)
          when 32..246 then [byte - 139, position + 1]
          when 247..250 then [((byte - 247) * 256) + dict.getbyte(position + 1).to_i + 108, position + 2]
          when 251..254 then [-((byte - 251) * 256) - dict.getbyte(position + 1).to_i - 108, position + 2]
          else [nil, position + 1]
          end
        end
      end

      # A real number, stored as nibbles ending in 0xF. Only its length
      # matters here: no offset in a Top DICT is written this way.
      def dict_real(dict, position)
        (position + 1).then do |at|
          while at < dict.bytesize && !nibble_terminated?(dict.getbyte(at))
            at += 1
          end
          [nil, at + 1]
        end
      end

      def nibble_terminated?(byte)
        (byte & 0x0F) == 0x0F || (byte >> 4) == 0x0F
      end

      def signed(value, bits)
        if value.nil?
          nil
        elsif value >= (1 << (bits - 1))
          value - (1 << bits)
        else
          value
        end
      end
  end

  # Tables packs a rewritten table set back into the shape both WOFF
  # containers need: sorted by tag, four-byte padded, with the OpenType
  # checksums recomputed and `head`'s checkSumAdjustment set to match the
  # sfnt a decoder will rebuild. fontTools does this inside `TTFont.save`.
  class Tables
    # The constant an sfnt's checksums are required to add up to.
    MAGIC = 0xB1B0_AFBA
    HEADER_SIZE = 12
    ENTRY_SIZE = 16
    ADJUSTMENT_AT = 8
    REVISION_AT = 4

    # One table as a container stores it: its tag, those bytes, and the
    # checksum the rebuilt sfnt's directory will record for it.
    Entry = Struct.new(:tag, :data, :checksum)

    def self.checksum(bytes)
      pad(bytes).unpack('N*').sum & 0xFFFF_FFFF
    end

    def self.pad(bytes)
      bytes.b.then { |raw| raw + ("\x00".b * ((-raw.bytesize) % 4)) }
    end

    attr_reader :flavor

    def initialize(tables, flavor)
      @flavor = flavor.b
      @tables = tables.sort.to_h { |tag, bytes| [tag, bytes.b] }
      unless @tables['head'].nil?
        @tables['head'] = zeroed_head
      end
    end

    def count = @tables.length

    def entries
      @entries ||= @tables.map { |tag, bytes| Entry.new(tag, output(tag, bytes), checksums.fetch(tag)) }
    end

    # What a decoder's reconstructed sfnt will weigh, which both containers
    # record so the decoder can allocate it in one go.
    def total_sfnt_size
      HEADER_SIZE + (ENTRY_SIZE * count) + @tables.values.sum { |bytes| padded_size(bytes.bytesize) }
    end

    # The font's own version, from `head`'s fontRevision: both containers
    # carry it in their header.
    def version
      revision.then do |fixed|
        [fixed >> 16, (((fixed & 0xFFFF) * 1000) / 65_536.0).round]
      end
    end

    private

      def revision
        @tables['head'].then do |head|
          if head.nil?
            0x0001_0000
          else
            head[REVISION_AT, 4].unpack1('N')
          end
        end
      end

      # The directory's checksum for `head` is the one taken with
      # checkSumAdjustment zeroed, which is what the OpenType spec asks for.
      def zeroed_head
        @tables['head'].dup.tap { |head| head[ADJUSTMENT_AT, 4] = [0].pack('N') }
      end

      def output(tag, bytes)
        if tag == 'head'
          adjusted_head(bytes)
        else
          bytes
        end
      end

      def adjusted_head(head)
        head.dup.tap do |bytes|
          bytes[ADJUSTMENT_AT, 4] = [(MAGIC - whole_checksum) & 0xFFFF_FFFF].pack('N')
        end
      end

      def whole_checksum
        @whole_checksum ||= (Tables.checksum(offset_table + directory) + checksums.values.sum) & 0xFFFF_FFFF
      end

      def checksums
        @checksums ||= @tables.transform_values { |bytes| Tables.checksum(bytes) }
      end

      def offset_table
        [@flavor, [count, search_range, entry_selector, range_shift].pack('n4')].join
      end

      def directory
        offsets.map { |tag, offset| directory_entry(tag, offset) }.join
      end

      def directory_entry(tag, offset)
        [
          tag.b,
          [checksums.fetch(tag), offset, @tables.fetch(tag).bytesize].pack('N3'),
        ].join
      end

      def offsets
        @offsets ||= @tables.inject([HEADER_SIZE + (ENTRY_SIZE * count), {}]) do |(offset, found), (tag, bytes)|
          [offset + padded_size(bytes.bytesize), found.merge(tag => offset)]
        end.last
      end

      def padded_size(length) = length + ((-length) % 4)

      def entry_selector = Math.log2([count, 1].max).floor

      def search_range = 16 * (2**entry_selector)

      def range_shift = (count * 16) - search_range
  end

  # Woff wraps a table set in the WOFF 1.0 container: each table Deflated on
  # its own, behind a 44-byte header and a 20-byte-per-table directory. This
  # is the file fontTools writes for `font.flavor = 'woff'`.
  class Woff
    SIGNATURE = 'wOFF'
    HEADER_SIZE = 44
    ENTRY_SIZE = 20

    # One table in the file: where it sits, the bytes stored there, and what
    # it weighs once inflated.
    Block = Struct.new(
      :tag,
      :offset,
      :data,
      :length,
      :checksum,
    )

    def initialize(tables)
      @tables = tables
    end

    def bytes
      @bytes ||= [header, directory, body].join
    end

    private

      def header
        [
          SIGNATURE.b,
          @tables.flavor,
          [file_size].pack('N'),
          [@tables.count, 0].pack('n2'),
          [@tables.total_sfnt_size].pack('N'),
          @tables.version.pack('n2'),
          [0, 0, 0, 0, 0].pack('N5'),
        ].join
      end

      def directory
        blocks.map { |block| directory_entry(block) }.join
      end

      def directory_entry(block)
        [
          block.tag.b,
          [block.offset, block.data.bytesize, block.length, block.checksum].pack('N4'),
        ].join
      end

      def body
        blocks.map { |block| block.data + align(block.data.bytesize) }.join
      end

      def align(length) = "\x00".b * ((-length) % 4)

      def file_size
        blocks.last.then do |last|
          if last.nil?
            table_offset
          else
            last.offset + last.data.bytesize + align(last.data.bytesize).bytesize
          end
        end
      end

      def table_offset = HEADER_SIZE + (ENTRY_SIZE * @tables.count)

      def blocks
        @blocks ||= @tables.entries.inject([table_offset, []]) do |(offset, found), entry|
          stored(entry).then do |data|
            [
              offset + data.bytesize + align(data.bytesize).bytesize,
              found + [block_for(entry, offset, data)],
            ]
          end
        end.last
      end

      def block_for(entry, offset, data)
        Block.new(
          entry.tag,
          offset,
          data,
          entry.data.bytesize,
          entry.checksum,
        )
      end

      # A table whose Deflate stream is no smaller than the table itself is
      # stored as it is, which the container spells by making the two lengths
      # equal.
      def stored(entry)
        Zlib::Deflate.deflate(entry.data, Zlib::BEST_COMPRESSION).then do |deflated|
          if deflated.bytesize < entry.data.bytesize
            deflated
          else
            entry.data
          end
        end
      end
  end

  # Woff2 wraps a table set in the WOFF 2.0 container: one Brotli stream over
  # every table at once, behind a 48-byte header and a directory that spends
  # a single byte on a table's tag wherever the spec's list already names it.
  # This is the file fontTools writes for `font.flavor = 'woff2'`.
  #
  # Every table is stored with the null transform. The spec's `glyf`/`loca`
  # transform re-encodes outlines into a stream format of its own, which buys
  # a few percent on top of Brotli; transform version 3 says a decoder gets
  # `glyf` and `loca` exactly as the sfnt had them, and is what fontTools
  # itself writes whenever it cannot transform a font.
  class Woff2
    SIGNATURE = 'wOF2'
    HEADER_SIZE = 48

    # Transform version 3 on `glyf` and `loca` means "not transformed"; on
    # every other table that is version 0.
    NULL_TRANSFORM = 3
    UNTRANSFORMED = %w[glyf loca].freeze

    # The tags the spec numbers, in its order: a directory entry whose tag is
    # one of these spends one byte on it. Index 63 is the escape, and the tag
    # follows in full.
    KNOWN_TAGS = [
      'cmap', 'head', 'hhea', 'hmtx', 'maxp', 'name', 'OS/2', 'post',
      'cvt ', 'fpgm', 'glyf', 'loca', 'prep', 'CFF ', 'VORG', 'EBDT',
      'EBLC', 'gasp', 'hdmx', 'kern', 'LTSH', 'PCLT', 'VDMX', 'vhea',
      'vmtx', 'BASE', 'GDEF', 'GPOS', 'GSUB', 'EBSC', 'JSTF', 'MATH',
      'CBDT', 'CBLC', 'COLR', 'CPAL', 'SVG ', 'sbix', 'acnt', 'avar',
      'bdat', 'bloc', 'bsln', 'cvar', 'fdsc', 'feat', 'fmtx', 'fvar',
      'gvar', 'hsty', 'just', 'lcar', 'mort', 'morx', 'opbd', 'prop',
      'trak', 'Zapf', 'Silf', 'Glat', 'Gloc', 'Feat', 'Sill',
    ].freeze

    ARBITRARY_TAG = 63

    def initialize(tables)
      @tables = tables
    end

    # nil when there is no Brotli to compress with, which is the one thing
    # that can stop a WOFF2 being written.
    def bytes
      @bytes ||= compressed.then do |stream|
        unless stream.nil?
          [header(stream), directory, stream, align(stream)].join
        end
      end
    end

    private

      def compressed
        Brotli.compress(@tables.entries.map(&:data).join)
      end

      # The compressed block has to end on a four-byte boundary, and the
      # padding counts towards the file's length. A decoder checks that
      # boundary against the file it was handed, so a file that stops two
      # bytes short of it is rejected outright.
      def align(stream) = "\x00".b * ((-body_size(stream)) % 4)

      def body_size(stream) = HEADER_SIZE + directory.bytesize + stream.bytesize

      def header(stream)
        [
          SIGNATURE.b,
          @tables.flavor,
          [body_size(stream) + align(stream).bytesize].pack('N'),
          [@tables.count, 0].pack('n2'),
          [@tables.total_sfnt_size, stream.bytesize].pack('N2'),
          @tables.version.pack('n2'),
          [0, 0, 0, 0, 0].pack('N5'),
        ].join
      end

      def directory
        @directory ||= @tables.entries.map { |entry| directory_entry(entry) }.join
      end

      def directory_entry(entry)
        [
          flags(entry.tag),
          tag_bytes(entry.tag),
          base128(entry.data.bytesize),
        ].join
      end

      def flags(tag)
        [(transform(tag) << 6) | tag_index(tag)].pack('C')
      end

      def transform(tag)
        if UNTRANSFORMED.include?(tag)
          NULL_TRANSFORM
        else
          0
        end
      end

      def tag_index(tag) = KNOWN_TAGS.index(tag) || ARBITRARY_TAG

      def tag_bytes(tag)
        if tag_index(tag) == ARBITRARY_TAG
          tag.b
        else
          +''.b
        end
      end

      # UIntBase128: seven bits per byte, most significant byte first, the top
      # bit set on every byte but the last.
      def base128(value)
        septets(value).reverse.then do |ordered|
          ordered.each_with_index.map { |septet, index| septet_byte(septet, index == ordered.length - 1) }.join
        end
      end

      def septet_byte(septet, last)
        if last
          [septet].pack('C')
        else
          [septet | 0x80].pack('C')
        end
      end

      # Least significant septet first, which is the order the shifting
      # produces; base128 reverses them. A one-septet value gets no
      # continuation bit, so the single byte is also the last byte.
      def septets(value)
        [].tap do |found|
          found << (value & 0x7F)
          while value > 0x7F
            value >>= 7
            found << (value & 0x7F)
          end
        end
      end
  end

  # --- The generator itself -------------------------------------------------

  # One subset on its way to disk: the tables it packs to, the CSS block it
  # declares, and the base name its files take.
  Job = Struct.new(
    :subset,
    :data,
    :name,
    :range,
    :css,
    :tables,
  )

  def initialize(window, path:, fonts:, formats:, ranges:, base64:, font_display:)
    @window = window
    @path = path
    @list = fonts
    @requested = formats
    @ranges = ranges
    @base64 = base64
    @font_display = font_display
    @stop = false
    @progress = 0
    @css = {}
  end

  # The formats that can actually be written. WOFF2 is a Brotli stream by
  # definition, so without libbrotlienc there is nothing to write it with and
  # the format drops out, with a line in the log saying why.
  def formats
    @formats ||= @requested.select { |name| name != 'woff2' || Brotli.available? }
  end

  def total
    @total ||= @list.length * formats.length * ranges_count
  end

  def run
    tap do
      @window.progressbar.fraction = 0
      @window.progress.title = ''
      @window.log.reset
      @thread = Thread.new { generate }
    end
  end

  # What the window's cancel button calls. No further font is started, and the
  # view goes back to the list.
  def stop
    @stop = true
    @window.processing = false
    @window.appstack.visible_child_name = 'main'
  end

  private

    def ranges_count
      if @ranges.nil?
        1
      else
        [@ranges.length, 1].max
      end
    end

    def generate
      @window.processing = true
      show('progress')
      if formats.empty?
        abandon
      else
        convert
      end
    rescue StandardError => e
      report(e)
    end

    def convert
      report_dropped_formats
      @list.each do |font|
        unless @stop
          generate_font(font.path, font.data)
        end
      end
      unless @stop
        finish(generate_css)
      end
    end

    def finish(sheets)
      end_code(sheets)
      append_log(_('Generation finished!'), bold: true)
      @window.processing = false
      show('finished')
      on_main { @window.finished_stack.visible_child_name = 'info' }
    end

    # Nothing can be written at all: every requested format needed Brotli.
    def abandon
      append_log(brotli_missing, italic: true)
      @window.processing = false
      show('main')
    end

    def report_dropped_formats
      unless @requested.length == formats.length
        append_log(brotli_missing, italic: true)
      end
    end

    def brotli_missing
      'WOFF2 needs the Brotli compressor, and libbrotlienc could not be loaded. Skipping it.'
    end

    def report(error)
      warn "Error generating fonts: #{error.message}"
      # Same msgid as loader.py:76 / lib/loader.rb's own error toast.
      error_text = _('Error: {error}.').sub('{error}', error.message.to_s)
      append_log(error_text, italic: true)
      @window.processing = false
      show('main')
      on_main { @window.toasts.add_toast(Adwaita::Toast.new(error_text)) }
    end

    # --- One font -----------------------------------------------------------

    def generate_font(filename, data)
      append_log(_('Generating fonts for {name}:').sub('{name}', data.name), bold: true)
      set_progress_title(_('Generating {name}').sub('{name}', data.family))
      Loader::Sfnt.new(File.binread(filename)).then do |sfnt|
        warn_unreducible(sfnt, data)
        subsets(sfnt).each do |char_range, subset|
          unless @stop
            write_font(subset, data, char_range)
          end
        end
      end
    end

    # Range name => the subset it asks for, or one nameless subset when
    # subsetting is off.
    def subsets(sfnt)
      if @ranges.nil?
        { nil => Subset.new(sfnt) }
      else
        @ranges.transform_values { |unicodes| Subset.new(sfnt, UnicodeRanges.parse(unicodes)) }
      end
    end

    def warn_unreducible(sfnt, data)
      unless @ranges.nil? || Subset.reducible?(sfnt)
        append_log(unreducible_text(data), italic: true)
      end
    end

    def unreducible_text(data)
      format(
        'The outlines in %s are in a format this build cannot subset: every ' \
        'subset carries all of them, and only the CSS unicode-range limits what is used.',
        data.family,
      )
    end

    def write_font(subset, data, char_range)
      if subset.empty?
        skip(subset_name(data, char_range), char_range)
      else
        write_formats(job(subset, data, char_range))
      end
    end

    def job(subset, data, char_range)
      Job.new(
        subset,
        data,
        subset_name(data, char_range),
        char_range,
        declaration(data, char_range),
        Tables.new(subset.tables, subset.flavor),
      )
    end

    def subset_name(data, char_range)
      [data.name_slug, char_range].compact.join('-')
    end

    def skip(name, char_range)
      step_done(formats.length)
      append_log(_('No glyphs where found for {range}. Skipping.').sub('{range}', char_range || name), italic: true)
    end

    def write_formats(work)
      formats.each { |extension| write_format(work, extension) }
      @css[work.data.family_slug][work.name] = work.css
    end

    def write_format(work, extension)
      "#{work.name}.#{extension}".then do |filename|
        store(work, filename, extension)
        step_done
        append_log(generated_text(work, filename))
      end
    end

    def generated_text(work, filename)
      _('Generated <i>{filename}</i> with <i>{count}</i> glyphs.')
        .sub('{filename}', File.join(work.data.family_slug, filename))
        .sub('{count}', work.subset.glyph_count.to_s)
    end

    def store(work, filename, extension)
      package(work.tables, extension).then do |bytes|
        if @base64
          work.css['src'] << data_url(bytes, extension)
        else
          write_file(work.data.family_slug, filename, bytes)
          work.css['src'] << %(url(#{filename}) format("#{extension}"))
        end
      end
    end

    def package(tables, extension)
      case extension
      when 'woff' then Woff.new(tables).bytes
      when 'woff2' then Woff2.new(tables).bytes
      else raise Error, "Unknown webfont format #{extension}"
      end
    end

    def data_url(bytes, extension)
      format(
        'url(data:font/%s;charset=utf-8;base64,%s) format("%s")',
        extension,
        [bytes].pack('m0'),
        extension,
      )
    end

    def write_file(slug, filename, bytes)
      File.join(@path, slug).then do |folder|
        FileUtils.mkdir_p(folder)
        File.binwrite(File.join(folder, filename), bytes)
      end
    end

    # --- CSS ----------------------------------------------------------------

    # The CSS block this subset gets, with `src` holding only the font's
    # `local()` sources: a url is appended to it for each format written.
    def declaration(data, char_range)
      @css[data.family_slug] ||= {}
      {
        'font-family'  => %("#{data.family}"),
        'font-style'   => data.style,
        'font-weight'  => data.weight,
        'font-stretch' => data.width,
        'src'          => data.local.dup,
      }.tap do |css|
        add_range(css, char_range)
        add_display(css)
      end
    end

    def add_range(css, char_range)
      unless char_range.nil? || @ranges.nil?
        css['unicode-range'] = @ranges[char_range]
      end
    end

    def add_display(css)
      unless @font_display.nil?
        css['font-display'] = @font_display
      end
    end

    def generate_css
      append_log(_('Generating CSS:'), bold: true)
      set_progress_title(_('Finishing'))
      @css.map { |family, subsets| write_sheet(family, sheet(subsets)) }.tap do |sheets|
        if sheets.empty?
          append_log(_('There is no CSS to generate.'), italic: true)
        end
      end
    end

    def sheet(subsets)
      subsets.map { |name, properties| "#{font_face(name, properties)}\n" }.join
    end

    def font_face(name, properties)
      [
        "/* #{name} */",
        '@font-face {',
        declarations(properties),
        '}',
      ].join("\n")
    end

    def declarations(properties)
      properties.map { |key, value| "\t#{key}: #{flatten(value)};" }.join("\n")
    end

    def flatten(value)
      if value.is_a?(Array)
        value.join(', ')
      else
        value
      end
    end

    def write_sheet(family, css)
      "#{family}.css".then do |basename|
        write_file(family, basename, "#{css}\n")
        File.join(family, basename).then do |filename|
          append_log(_('Generated <i>{filename}</i>.').sub('{filename}', filename))
          filename
        end
      end
    end

    def end_code(sheets)
      on_main do
        @window.src_html.set_text(sheets.map { |sheet| %(<link href="#{sheet}" rel="stylesheet">) }.join("\n"))
        @window.src_css.set_text(sheets.map { |sheet| %(@import url("#{sheet}");) }.join("\n"))
      end
    end

    # --- Talking to the window ----------------------------------------------

    def step_done(increment = 1)
      @progress += increment
      fraction.then { |value| on_main { @window.progressbar.fraction = value } }
    end

    def fraction
      if total.zero?
        1.0
      else
        @progress / total.to_f
      end
    end

    def set_progress_title(text)
      on_main { @window.progress.title = text }
    end

    def append_log(text, bold: false, italic: false)
      on_main { @window.log.append(text, bold: bold, italic: italic) }
    end

    def show(name)
      on_main { @window.appstack.visible_child_name = name }
    end

    # Every widget touch above runs here, on the main loop, because the
    # generation itself is on a thread.
    def on_main(&work)
      GLib::Idle.add do
        work.call
        false
      end
    end
end
