#!/usr/bin/env ruby
# frozen_string_literal: true

# Drives a whole generation the way a user does it: open the app, set the
# options in the sidebar, load a font, pick an output directory, press
# Generate, and then pull the files it wrote apart again.
#
# The containers are checked by rebuilding the sfnt a browser would rebuild
# and adding up its checksums: an sfnt is valid only when every uint32 in it
# sums to 0xB1B0AFBA, so that one number covers the WOFF header, the
# directory, each table's stored length, the Deflate and Brotli streams, and
# the checkSumAdjustment the generator wrote into `head`.
#
# Run it from the dev shell:
#
#   nix develop --command xvfb-run -a ruby test/drive_generator.rb

require 'fiddle'
require 'fileutils'
require 'tmpdir'
require 'zlib'

require 'webfont_kit_generator'

# Drive is the script itself: `run` is the whole thing.
class Drive
  MAGIC = 0xB1B0_AFBA

  # The font to convert. The dev shell exports it; the glob is for a shell
  # that predates that.
  SAMPLE = ENV.fetch('WEBFONT_SAMPLE_FONT', nil)

  # How long the generation may take before the script gives up, in tenths of
  # a second.
  TICKS = 600

  # The sidebar settings this run uses, so the result does not depend on
  # whatever the user last chose.
  SUBSET = 'latin'
  FORMATS = ['woff2', 'woff'].freeze

  def run
    tap do
      puts "font: #{font}"
      puts "out:  #{out_dir}"
      application.build
      application.app.signal_connect('activate') { start }
      application.app.run([])
      unless @ok
        abort 'DRIVE FAILED'
      end
      puts "DRIVE OK — #{Dir.glob(File.join(out_dir, '**', '*')).length} files in #{out_dir}"
    end
  end

  private

    def application
      @application ||= WebfontKitGenerator::Application.new(settings: settings)
    end

    def settings = @settings ||= Settings.new(path: File.join(work_dir, 'settings.json'))

    def window = application.window

    def work_dir = @work_dir ||= Dir.mktmpdir('webfont-drive')

    def out_dir
      @out_dir ||= File.join(work_dir, 'kit').tap { |path| FileUtils.mkdir_p(path) }
    end

    def font
      SAMPLE || Dir.glob('/nix/store/*dejavu*/share/fonts/truetype/DejaVuSans.ttf').first ||
        abort('no sample font: set WEBFONT_SAMPLE_FONT to a .ttf')
    end

    # --- Driving the window -------------------------------------------------

    def start
      drive
    rescue StandardError => e
      fail_with(e.message)
    end

    # Raised checks land in `fail_with` rather than unwinding through a GLib
    # callback, which would swallow them and leave the loop running.
    def fail_with(message)
      warn "DRIVE FAILED — #{message}"
      warn "the app's log said:\n#{window.log.buffer.text}"
      warn "it wrote:\n#{Dir.glob(File.join(out_dir, '**', '*')).join("\n")}"
      application.app.quit
    end

    def drive
      choose_options
      window.load_fonts([Gio::File.new_for_path(font)])
      window.select_out_dir(Gio::File.new_for_path(out_dir))
      check(window.model.n_items == 1, "loaded #{window.model.n_items} fonts, wanted 1")
      check(generate_action.enabled?, 'the generate action stayed disabled')
      generate_action.activate(nil)
      wait_for_finish
    end

    def choose_options
      window.options.woff2_switch.active = true
      window.options.woff_switch.active = true
      window.options.base64_row.active = false
      window.options.font_display_row.selected = 3
      window.options.subsetting_row.enable_expansion = true
      window.options.subset_checks.each { |name, button| button.active = name == SUBSET }
    end

    def generate_action = window.window.lookup_action('generate')

    def wait_for_finish
      @ticks = 0
      GLib::Timeout.add(100) do
        @ticks += 1
        if window.appstack.visible_child_name == 'finished'
          check_result
          false
        elsif @ticks >= TICKS
          fail_with('the generation never finished')
          false
        else
          true
        end
      end
    end

    # --- Checking what it wrote ---------------------------------------------

    def check_result
      verify
      @ok = true
      application.app.quit
    rescue StandardError => e
      fail_with(e.message)
    end

    def verify
      check(window.processing == false, 'the window stayed in its processing state')
      verify_stylesheet
      FORMATS.each { |extension| verify_font(extension) }
      verify_snippets
    end

    # The snippets on the finished page are what the user copies into their
    # page, so they have to name the stylesheet that was actually written.
    def verify_snippets
      File.join(family, "#{family}.css").then do |sheet|
        check(window.src_html.buffer.text.include?(%(href="#{sheet}")), 'the HTML snippet links no stylesheet')
        check(window.src_css.buffer.text.include?(%(url("#{sheet}"))), 'the CSS snippet imports no stylesheet')
      end
    end

    # The family's directory and stylesheet name, and the face's file name:
    # DejaVu Sans' full name is "DejaVu Sans Book", and the generator names
    # each file after the face rather than the family.
    def family = 'dejavu-sans'

    def face = 'dejavu-sans-book'

    def stylesheet = File.join(out_dir, family, "#{family}.css")

    def verify_stylesheet
      check(File.exist?(stylesheet), "no stylesheet at #{stylesheet}")
      File.read(stylesheet).then do |css|
        check(css.include?('@font-face {'), 'the stylesheet declares no @font-face')
        check(css.include?('font-family: "DejaVu Sans";'), 'the stylesheet names no family')
        check(css.include?('unicode-range: U+0000-00FF'), 'the stylesheet carries no unicode-range')
        check(css.include?('font-display: swap;'), 'the stylesheet carries no font-display')
        FORMATS.each do |extension|
          check(css.include?(%(format("#{extension}"))), "the stylesheet links no #{extension}")
        end
      end
    end

    def verify_font(extension)
      File.join(out_dir, family, "#{face}-#{SUBSET}.#{extension}").then do |path|
        check(File.exist?(path), "no #{extension} at #{path}")
        File.binread(path).then do |bytes|
          tables = unwrap(extension, bytes)
          check_sfnt(tables, bytes.bytesize, extension)
          report(extension, path, tables)
        end
      end
    end

    def report(extension, path, tables)
      puts format(
        '%-5s %7d bytes, %2d tables, glyf %6d (was %6d)',
        extension,
        File.size(path),
        tables.length,
        tables.fetch('glyf').bytesize,
        original_glyf,
      )
      check(tables.fetch('glyf').bytesize < original_glyf / 2, "#{extension} kept its whole glyf table")
    end

    def original_glyf
      @original_glyf ||= Loader::Sfnt.new(File.binread(font)).tables.fetch('glyf').bytesize
    end

    # --- The containers -----------------------------------------------------

    def unwrap(extension, bytes)
      if extension == 'woff'
        unwrap_woff(bytes)
      else
        unwrap_woff2(bytes)
      end
    end

    # WOFF 1.0: a 44-byte header, a 20-byte entry per table, then one Deflate
    # stream per table.
    def unwrap_woff(bytes)
      check(bytes[0, 4] == 'wOFF', 'the woff has the wrong signature')
      check(bytes[8, 4].unpack1('N') == bytes.bytesize, 'the woff header has the wrong length')
      bytes[12, 2].unpack1('n').then do |count|
        (0...count).to_h { |index| woff_table(bytes, 44 + (index * 20)) }
      end
    end

    def woff_table(bytes, at)
      bytes[at, 20].unpack('a4N4').then do |tag, offset, stored, original, checksum|
        bytes[offset, stored].then do |data|
          inflated(data, stored, original).then do |table|
            check(table.bytesize == original, "#{tag} inflated to #{table.bytesize}, wanted #{original}")
            check(checksum == checksum_of(tag, table), "#{tag} has the wrong checksum in the woff directory")
            [tag, table]
          end
        end
      end
    end

    def inflated(data, stored, original)
      if stored == original
        data
      else
        Zlib::Inflate.inflate(data)
      end
    end

    # WOFF 2.0: a 48-byte header, a variable-length entry per table, then one
    # Brotli stream over all of them.
    def unwrap_woff2(bytes)
      check(bytes[0, 4] == 'wOF2', 'the woff2 has the wrong signature')
      check(bytes[8, 4].unpack1('N') == bytes.bytesize, 'the woff2 header has the wrong length')
      check((bytes.bytesize % 4).zero?, 'the woff2 does not end on a four-byte boundary')
      woff2_directory(bytes).then do |lengths, at|
        check(bytes[20, 4].unpack1('N') == bytes.bytesize - at, 'the woff2 stream length is wrong')
        split(brotli_decompress(bytes[at..]), lengths)
      end
    end

    def woff2_directory(bytes)
      bytes[12, 2].unpack1('n').then do |count|
        (0...count).inject([[], 48]) do |(found, at), _|
          woff2_entry(bytes, at).then do |tag, length, after|
            [found + [[tag, length]], after]
          end
        end
      end
    end

    def woff2_entry(bytes, at)
      bytes.getbyte(at).then do |flags|
        tag_of(bytes, at, flags).then do |tag, after|
          base128(bytes, after).then do |length, finish|
            check(transform_ok?(tag, flags), "#{tag} claims a transform this port never writes")
            [tag, length, finish]
          end
        end
      end
    end

    def tag_of(bytes, at, flags)
      if (flags & 0x3F) == 63
        [bytes[at + 1, 4], at + 5]
      else
        [Generator::Woff2::KNOWN_TAGS.fetch(flags & 0x3F), at + 1]
      end
    end

    def transform_ok?(tag, flags)
      if ['glyf', 'loca'].include?(tag)
        (flags >> 6) == 3
      else
        (flags >> 6).zero?
      end
    end

    def base128(bytes, at)
      value = 0
      position = at
      more = true
      while more
        bytes.getbyte(position).then do |byte|
          value = (value << 7) | (byte & 0x7F)
          position += 1
          more = !(byte & 0x80).zero?
        end
      end
      [value, position]
    end

    def split(stream, lengths)
      lengths.inject([{}, 0]) do |(found, at), (tag, length)|
        [found.merge(tag => stream[at, length]), at + length]
      end.first.tap do |tables|
        check(tables.values.all? { |data| !data.nil? }, 'the woff2 stream is shorter than its directory')
      end
    end

    def brotli_decompress(stream)
      Fiddle::Pointer.malloc(64 * 1024 * 1024, Fiddle::RUBY_FREE).then do |buffer|
        [buffer.size].pack('J').then do |size|
          decompress(stream, size, buffer).then do |result|
            check(result == 1, "Brotli could not decompress the woff2 stream (#{result})")
            buffer.to_str(size.unpack1('J'))
          end
        end
      end
    end

    def decompress(stream, size, buffer)
      decoder.call(
        stream.bytesize,
        stream,
        size,
        buffer,
      )
    end

    def decoder
      @decoder ||= Fiddle::Function.new(
        Fiddle.dlopen(decoder_library)['BrotliDecoderDecompress'],
        [Fiddle::TYPE_SIZE_T, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
        Fiddle::TYPE_INT,
      )
    end

    def decoder_library
      ENV.fetch('WEBFONT_BROTLI_LIB', 'libbrotlienc.so.1').sub('brotlienc', 'brotlidec')
    end

    # --- The sfnt a browser rebuilds ----------------------------------------

    # Every uint32 in a valid sfnt sums to 0xB1B0AFBA. Rebuilding the file the
    # container describes and adding it up checks the whole chain at once.
    def check_sfnt(tables, packed_size, extension)
      rebuild(tables).then do |sfnt|
        check(sum(sfnt) == MAGIC, "the sfnt rebuilt from the #{extension} does not checksum")
        check(sfnt.bytesize > packed_size, "the #{extension} is no smaller than the sfnt it holds")
        check(tables.key?('glyf'), "the #{extension} dropped the glyf table")
      end
    end

    def rebuild(tables)
      tables.sort.to_h.then do |sorted|
        [offset_table(sorted), directory(sorted), body(sorted)].join
      end
    end

    def offset_table(sorted)
      Math.log2(sorted.length).floor.then do |selector|
        [
          sfnt_version(sorted),
          [sorted.length, 16 * (2**selector), selector, (sorted.length * 16) - (16 * (2**selector))].pack('n4'),
        ].join
      end
    end

    # Only the two flavours this app writes: TrueType outlines and CFF ones.
    def sfnt_version(sorted)
      if sorted.key?('CFF ')
        'OTTO'.b
      else
        [0x0001_0000].pack('N')
      end
    end

    def directory(sorted)
      sorted.inject([12 + (16 * sorted.length), +''.b]) do |(at, found), (tag, data)|
        [
          at + padded(data.bytesize),
          found + tag.b + [checksum_of(tag, data), at, data.bytesize].pack('N3'),
        ]
      end.last
    end

    def body(sorted)
      sorted.values.map { |data| data + ("\x00".b * ((-data.bytesize) % 4)) }.join
    end

    def padded(length) = length + ((-length) % 4)

    # `head`'s own directory checksum is the one taken with its
    # checkSumAdjustment zeroed; the adjustment itself is counted once, in the
    # whole-file sum.
    def checksum_of(tag, data)
      if tag == 'head'
        sum(data.dup.tap { |head| head[8, 4] = [0].pack('N') })
      else
        sum(data)
      end
    end

    def sum(bytes)
      (bytes.b + ("\x00".b * ((-bytes.bytesize) % 4))).unpack('N*').sum & 0xFFFF_FFFF
    end

    def check(condition, message)
      unless condition
        raise message
      end
    end
end

Drive.new.run
