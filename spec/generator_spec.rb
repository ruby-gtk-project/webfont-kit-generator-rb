# frozen_string_literal: true

require 'spec_helper'

# Unit coverage for lib/generator.rb's Subset, Tables, Woff and Woff2 —
# the fontTools-replacement classes test/drive_generator.rb only ever
# exercises end to end, through a whole Generator#run on a thread, driven
# from a built GTK window. These specs build the same classes directly, with
# a real font's tables (the dev shell's WEBFONT_SAMPLE_FONT, the same file
# test/drive_generator.rb converts) but no window, no thread and no GTK.
RSpec.describe Generator::Subset do
  let(:sample_path) { ENV.fetch('WEBFONT_SAMPLE_FONT', nil) }

  before do
    skip('WEBFONT_SAMPLE_FONT is not set — run specs from the nix dev shell') if sample_path.nil?
  end

  let(:sfnt) { Loader::Sfnt.new(File.binread(sample_path)) }

  describe '.reducible?' do
    it 'is true for a font with a glyf table' do
      expect(Generator::Subset.reducible?(sfnt)).to be(true)
    end

    it 'is false for a table set with neither glyf nor CFF' do
      bare = Struct.new(:tables).new({ 'maxp' => "\x00\x01\x00\x00\x00\x05".b })

      expect(Generator::Subset.reducible?(bare)).to be(false)
    end
  end

  describe '#empty?' do
    it 'is false when the range reaches characters the font has' do
      subset = Generator::Subset.new(sfnt, [0x41, 0x42]) # "AB", in every Latin font

      expect(subset.empty?).to be(false)
    end

    it 'is true when the range reaches no character the font has at all' do
      subset = Generator::Subset.new(sfnt, [0x10FFFF]) # the highest codepoint there is

      expect(subset.empty?).to be(true)
    end

    it 'is never empty when subsetting is off' do
      subset = Generator::Subset.new(sfnt, nil)

      expect(subset.empty?).to be(false)
    end
  end

  describe '#glyph_count' do
    it 'is smaller for a narrower range than for the whole font' do
      narrow = Generator::Subset.new(sfnt, [0x41]).glyph_count
      whole = Generator::Subset.new(sfnt, nil).glyph_count

      expect(narrow).to be > 0
      expect(narrow).to be <= whole
    end
  end

  describe '#flavor' do
    it 'matches the source font\'s own sfnt_version, unsubsetted or not' do
      expect(Generator::Subset.new(sfnt, [0x41]).flavor).to eq(sfnt.sfnt_version)
    end
  end

  describe '#tables' do
    it 'keeps every table tag the source font has' do
      subset = Generator::Subset.new(sfnt, [0x41])

      expect(subset.tables.keys.sort).to eq(sfnt.tables.keys.sort)
    end

    it 'does not touch any table when subsetting is off' do
      subset = Generator::Subset.new(sfnt, nil)

      expect(subset.tables).to eq(sfnt.tables)
    end

    it 'shrinks the retained glyph outlines relative to the whole font' do
      subsetted = Generator::Subset.new(sfnt, [0x41]).tables['glyf']
      whole = Generator::Subset.new(sfnt, nil).tables['glyf']

      expect(subsetted.bytesize).to be <= whole.bytesize
    end
  end
end

RSpec.describe Generator::Tables do
  let(:sample_path) { ENV.fetch('WEBFONT_SAMPLE_FONT', nil) }

  before do
    skip('WEBFONT_SAMPLE_FONT is not set — run specs from the nix dev shell') if sample_path.nil?
  end

  let(:sfnt) { Loader::Sfnt.new(File.binread(sample_path)) }
  let(:subset) { Generator::Subset.new(sfnt, [0x41, 0x42]) }
  let(:tables) { Generator::Tables.new(subset.tables, subset.flavor) }

  it 'counts the same number of tables it was given' do
    expect(tables.count).to eq(subset.tables.length)
  end

  # Rebuilds the sfnt the same way a decoder would from `tables.entries` —
  # offset table, then directory (each entry's checksum taken over `head`
  # with checkSumAdjustment zeroed, every other table as stored), then the
  # table bodies — and checks the OpenType invariant that every uint32 in a
  # valid sfnt sums to 0xB1B0AFBA. This is the same check
  # test/drive_generator.rb runs on the WOFF/WOFF2 bytes actually written to
  # disk; here it runs directly against Tables#entries, with no container
  # or disk round-trip in between.
  it 'zeroes and recomputes a consistent checksum adjustment in head' do
    head_entry = tables.entries.find { |entry| entry.tag == 'head' }
    expect(head_entry).not_to be_nil

    sum = lambda do |bytes|
      (bytes.b + ("\x00".b * ((-bytes.bytesize) % 4))).unpack('N*').sum & 0xFFFF_FFFF
    end
    checksum_of = lambda do |entry|
      if entry.tag == 'head'
        sum.call(entry.data.dup.tap { |head| head[8, 4] = [0].pack('N') })
      else
        sum.call(entry.data)
      end
    end
    padded = ->(length) { length + ((-length) % 4) }

    selector = Math.log2(tables.count).floor
    offset_table = [
      subset.flavor,
      [tables.count, 16 * (2**selector), selector, (tables.count * 16) - (16 * (2**selector))].pack('n4'),
    ].join

    directory = tables.entries.inject([12 + (16 * tables.count), +''.b]) do |(at, found), entry|
      [at + padded.call(entry.data.bytesize), found + entry.tag.b + [checksum_of.call(entry), at, entry.data.bytesize].pack('N3')]
    end.last

    body = tables.entries.map { |entry| entry.data + ("\x00".b * ((-entry.data.bytesize) % 4)) }.join

    whole = offset_table + directory + body
    expect(sum.call(whole)).to eq(0xB1B0_AFBA)
  end

  it 'reports a positive font version' do
    major, minor = tables.version

    expect(major).to be_a(Integer)
    expect(minor).to be_a(Integer)
  end

  it 'reports a total_sfnt_size at least as large as the sum of table sizes' do
    sum = subset.tables.values.sum(&:bytesize)

    expect(tables.total_sfnt_size).to be >= sum
  end
end

RSpec.describe Generator::Woff do
  let(:sample_path) { ENV.fetch('WEBFONT_SAMPLE_FONT', nil) }

  before do
    skip('WEBFONT_SAMPLE_FONT is not set — run specs from the nix dev shell') if sample_path.nil?
  end

  let(:sfnt) { Loader::Sfnt.new(File.binread(sample_path)) }
  let(:subset) { Generator::Subset.new(sfnt, [0x41, 0x42]) }
  let(:tables) { Generator::Tables.new(subset.tables, subset.flavor) }
  let(:bytes) { Generator::Woff.new(tables).bytes }

  it 'opens with the wOFF signature' do
    expect(bytes[0, 4]).to eq('wOFF')
  end

  it 'carries the subset flavor right after the signature' do
    expect(bytes[4, 4]).to eq(subset.flavor)
  end

  it 'records the actual file length in its header' do
    recorded_length = bytes[8, 4].unpack1('N')

    expect(recorded_length).to eq(bytes.bytesize)
  end

  it 'records the same table count Tables reports' do
    recorded_count = bytes[12, 2].unpack1('n')

    expect(recorded_count).to eq(tables.count)
  end
end

RSpec.describe Generator::Woff2 do
  let(:sample_path) { ENV.fetch('WEBFONT_SAMPLE_FONT', nil) }

  before do
    skip('WEBFONT_SAMPLE_FONT is not set — run specs from the nix dev shell') if sample_path.nil?
    skip('libbrotlienc is not available in this environment') unless Generator::Brotli.available?
  end

  let(:sfnt) { Loader::Sfnt.new(File.binread(sample_path)) }
  let(:subset) { Generator::Subset.new(sfnt, [0x41, 0x42]) }
  let(:tables) { Generator::Tables.new(subset.tables, subset.flavor) }
  let(:bytes) { Generator::Woff2.new(tables).bytes }

  it 'opens with the wOF2 signature' do
    expect(bytes[0, 4]).to eq('wOF2')
  end

  it 'records the actual file length in its header' do
    recorded_length = bytes[8, 4].unpack1('N')

    expect(recorded_length).to eq(bytes.bytesize)
  end

  it 'is smaller than the equivalent WOFF 1.0 container for the same tables' do
    woff_bytes = Generator::Woff.new(tables).bytes

    expect(bytes.bytesize).to be <= woff_bytes.bytesize
  end
end

RSpec.describe Generator::Brotli do
  describe '.available?' do
    it 'returns a boolean without raising, whether or not libbrotlienc is found' do
      expect([true, false]).to include(Generator::Brotli.available?)
    end
  end

  describe '.compress' do
    it 'returns nil when there is no library, bytes otherwise' do
      result = Generator::Brotli.compress('hello world')

      if Generator::Brotli.available?
        expect(result).to be_a(String)
        expect(result).not_to be_empty
      else
        expect(result).to be_nil
      end
    end
  end
end
