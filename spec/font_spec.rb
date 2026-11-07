# frozen_string_literal: true

require 'spec_helper'

# Unit coverage for lib/font.rb — the FontData value object and the Font
# GObject wrapper. Neither drive_window.rb nor drive_generator.rb isolates
# these: they only ever see a Font as a row already in the window's list
# store, never construct one directly and check its slugs or descriptors.
RSpec.describe FontData do
  describe '#initialize' do
    it 'defaults style, weight, width and local for a static font' do
      data = FontData.new(name: 'Fira Sans', family: 'Fira Sans', version: '1.0')

      expect(data.style).to eq('normal')
      expect(data.weight).to eq('400')
      expect(data.width).to eq('100%')
      expect(data.is_variable).to eq(false)
      expect(data.local).to eq([])
    end

    it 'accepts a nil local and stores an empty array instead' do
      data = FontData.new(name: 'X', family: 'X', version: '1.0', local: nil)

      expect(data.local).to eq([])
    end

    it 'keeps whatever local sources it is given' do
      data = FontData.new(name: 'X', family: 'X', version: '1.0', local: ['local("Fira Sans")'])

      expect(data.local).to eq(['local("Fira Sans")'])
    end
  end

  describe '#variable?' do
    it 'is true only when is_variable is exactly true' do
      expect(FontData.new(name: 'X', family: 'X', version: '1.0', is_variable: true).variable?).to be(true)
      expect(FontData.new(name: 'X', family: 'X', version: '1.0', is_variable: false).variable?).to be(false)
    end
  end

  describe '#name_slug and #family_slug' do
    it 'lowercases and hyphenates the name, independent of the family' do
      data = FontData.new(name: 'Fira Sans Bold', family: 'Fira Sans', version: '1.0')

      expect(data.name_slug).to eq('fira-sans-bold')
      expect(data.family_slug).to eq('fira-sans')
    end

    it 'collapses runs of whitespace the same way String#split does' do
      data = FontData.new(name: "Fira  Sans\tBold", family: 'Fira Sans', version: '1.0')

      expect(data.name_slug).to eq('fira-sans-bold')
    end
  end

  describe '#descriptors' do
    it 'turns spaces in weight and width into hyphens, leaving style alone' do
      data = FontData.new(
        name: 'X',
        family: 'Fira Sans',
        version: '1.0',
        style: 'italic',
        weight: 'extra bold',
        width: 'semi expanded',
      )

      expect(data.descriptors).to eq(['Fira Sans', 'italic', 'extra-bold', 'semi-expanded'])
    end
  end
end

RSpec.describe Font do
  it 'is a GLib::Object carrying a path and its parsed FontData' do
    data = FontData.new(name: 'X', family: 'X', version: '1.0')
    font = Font.new('/tmp/x.ttf', data)

    expect(font).to be_a(GLib::Object)
    expect(font.path).to eq('/tmp/x.ttf')
    expect(font.data).to equal(data)
  end

  it 'lets path and data be reassigned' do
    font = Font.new('/tmp/x.ttf', FontData.new(name: 'X', family: 'X', version: '1.0'))
    other = FontData.new(name: 'Y', family: 'Y', version: '2.0')

    font.path = '/tmp/y.ttf'
    font.data = other

    expect(font.path).to eq('/tmp/y.ttf')
    expect(font.data).to equal(other)
  end
end
