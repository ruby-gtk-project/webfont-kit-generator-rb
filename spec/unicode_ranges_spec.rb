# frozen_string_literal: true

require 'spec_helper'

# Unit coverage for lib/options.rb's UnicodeRanges module — the custom
# subsetting entry's parser/validator. Neither drive script types an invalid
# custom range into the entry and checks the parser's rejection; this
# exercises the parsing logic itself, in isolation from the GTK entry widget.
RSpec.describe UnicodeRanges do
  describe '.tokenize' do
    it 'splits on commas and the U+ prefix' do
      expect(UnicodeRanges.tokenize('U+0041,U+0042-0043')).to eq(['0041', '0042-0043'])
    end

    it 'treats a bare 0x-prefixed value the same as a U+-prefixed one' do
      expect(UnicodeRanges.tokenize('0x41,U+0042')).to eq(['41', '0042'])
    end

    it 'is empty for an empty string' do
      expect(UnicodeRanges.tokenize('')).to eq([])
    end
  end

  describe '.hex' do
    it 'parses a bare hex string' do
      expect(UnicodeRanges.hex('41')).to eq(0x41)
    end

    it 'raises UnicodeRanges::Error for a non-hex string' do
      expect { UnicodeRanges.hex('zz') }.to raise_error(UnicodeRanges::Error, /Not a hex value/)
    end
  end

  describe '.codepoints' do
    it 'returns one codepoint for a single value' do
      expect(UnicodeRanges.codepoints('41')).to eq([0x41])
    end

    it 'expands a hyphenated range inclusively' do
      expect(UnicodeRanges.codepoints('41-43')).to eq([0x41, 0x42, 0x43])
    end

    it 'raises for a token with more than one hyphen' do
      expect { UnicodeRanges.codepoints('41-42-43') }.to raise_error(UnicodeRanges::Error, /Not a unicode range/)
    end
  end

  describe '.parse' do
    it 'flattens several comma-separated tokens into one array of codepoints' do
      expect(UnicodeRanges.parse('U+0041,U+0043-0045')).to eq([0x41, 0x43, 0x44, 0x45])
    end

    it 'returns an empty array for an empty string' do
      expect(UnicodeRanges.parse('')).to eq([])
    end
  end

  describe '.valid?' do
    it 'is true for an empty entry' do
      expect(UnicodeRanges.valid?('')).to be(true)
    end

    it 'is true for a well-formed entry' do
      expect(UnicodeRanges.valid?('U+0021-007E,U+00E7')).to be(true)
    end

    it 'is false for a malformed entry, without raising' do
      expect(UnicodeRanges.valid?('U+ZZZZ')).to be(false)
    end

    it 'is false for a triple-hyphenated token' do
      expect(UnicodeRanges.valid?('41-42-43')).to be(false)
    end
  end
end

# Unit coverage for Options' subsetting tables and the literal-per-name
# translation lookup that replaced the non-literal `_(SUBSET_TITLES.fetch
# (name))` call (see translation-parity.md) — neither drive script asserts
# on the title text a subset checkbox shows.
RSpec.describe Options do
  describe '.translated_subset_title' do
    it 'has a title for every name in LEFT_SUBSETS and RIGHT_SUBSETS' do
      (Options::LEFT_SUBSETS + Options::RIGHT_SUBSETS).each do |name|
        expect(Options.translated_subset_title(name)).to be_a(String)
        expect(Options.translated_subset_title(name)).not_to be_empty
      end
    end

    it 'raises for a name that is not a known subset' do
      expect { Options.translated_subset_title('klingon') }.to raise_error(ArgumentError, /Unknown subset/)
    end
  end

  describe 'PRESET_RANGES' do
    it 'has a preset range for every subsetting checkbox' do
      (Options::LEFT_SUBSETS + Options::RIGHT_SUBSETS).each do |name|
        expect(Options::PRESET_RANGES).to have_key(name)
      end
    end

    it 'is parseable by UnicodeRanges, since the generator parses it the same way' do
      Options::PRESET_RANGES.each_value do |ranges|
        expect(UnicodeRanges.valid?(ranges)).to be(true)
      end
    end
  end

  describe 'LEFT_SUBSETS and RIGHT_SUBSETS' do
    it 'together cover every preset range exactly once' do
      combined = Options::LEFT_SUBSETS + Options::RIGHT_SUBSETS
      expect(combined.sort).to eq(Options::PRESET_RANGES.keys.sort)
      expect(combined.uniq.length).to eq(combined.length)
    end
  end
end
