# frozen_string_literal: true

# Custom `rake gettext:pot:create` extractors for the two file formats the
# Ruby `gettext` gem's `GetText::Tools::XGetText` ships no parser for at all:
# the `.desktop.in` launcher file and the `.metainfo.xml.in` AppStream
# component file. Upstream's meson build reaches these through real GNU
# `xgettext --language=Desktop` and an ITS rule for AppStream; neither exists
# in the Ruby gettext gem (its built-in parsers are "ruby", "erb",
# "gtk_builder_ui_definitions" and "glade" — see
# `gettext/tools/xgettext.rb`'s `builtin_parser_info_list`), so without one of
# these, `data/*.desktop.in` and `data/*.metainfo.xml.in` can never
# contribute a msgid to the extracted `.pot` no matter what `po/POTFILES`
# lists, literal string or not.
#
# Each parser follows the same protocol `GetText::GladeParser` does (see that
# file for the shape this is modeled on): a class method `target?(path)` that
# says whether this parser handles the file, and `parse(path)` returning an
# array of `GetText::POEntry`.
require 'gettext/po'

module WebfontKitGenerator
  module Gettext
    # Extracts `Name=`, `Comment=` and `Keywords=` from a freedesktop
    # `.desktop.in` file — the same three keys `intltool-extract`/real
    # `xgettext --language=Desktop` mark translatable for this kind of file.
    # `Keywords=` carries the "do not translate the semicolons" translator
    # comment upstream's own `.desktop.in` ships on that line.
    class DesktopParser
      KEYS = %w[Name Comment Keywords].freeze
      KEYWORDS_COMMENT = 'Translators: Search terms to find this application. ' \
        'Do NOT translate or localize the semicolons! The list MUST also end with a semicolon!'

      def self.target?(path) = File.extname(path) == '.in' && File.basename(path).include?('.desktop.in')

      def self.parse(path)
        new(path).parse
      end

      def initialize(path)
        @path = path
      end

      def parse
        po = []
        File.readlines(@path).each_with_index do |line, index|
          KEYS.each { |key| add_entry(po, key, line, index + 1) }
        end
        po
      end

      private

        def add_entry(po, key, line, line_no)
          match = line.chomp.match(/\A#{key}=(.+)\z/)
          unless match.nil?
            entry = find_or_create(po, match[1])
            entry.references << "#{@path}:#{line_no}"
            if key == 'Keywords'
              entry.extracted_comment = KEYWORDS_COMMENT
            end
          end
        end

        def find_or_create(po, value)
          po.find { |entry| entry.msgid == value } || GetText::POEntry.new(:normal).tap do |entry|
            entry.msgid = value
            po << entry
          end
        end
    end

    # Extracts `<summary>` and every non-`translate="no"` `<p>` inside
    # `<description>` from an AppStream `.metainfo.xml.in` file — the two
    # elements real `appstream-util`/`itstool` mark translatable for this
    # component type. `<name>` is left alone: upstream's own name is carried
    # as a literal `_()` call in the app code already (same msgid, same
    # string), not re-marked here.
    class MetainfoParser
      def self.target?(path) = File.basename(path).include?('.metainfo.xml.in')

      def self.parse(path)
        new(path).parse
      end

      def initialize(path)
        @path = path
      end

      def parse
        po = []
        lines = File.readlines(@path)
        lines.each_with_index do |line, index|
          add_summary(po, line, index + 1)
        end
        add_description_paragraphs(po, lines)
        po
      end

      private

        def add_summary(po, line, line_no)
          match = line.match(%r{<summary>(.+)</summary>})
          unless match.nil?
            record(po, match[1].strip, line_no)
          end
        end

        # `<p>`s inside `<description>` that span one source line each,
        # skipping any `<release>`'s change-log paragraphs, which upstream
        # marks `translate="no"` and this does too.
        def add_description_paragraphs(po, lines)
          lines.each_with_index do |line, index|
            match = line.chomp.match(%r{\A\s*<p>\s*\z})
            unless match.nil? || lines[index + 1].nil?
              text = lines[index + 1].strip
              unless text.empty? || lines[index + 1].include?('translate="no"')
                record(po, text, index + 2)
              end
            end
          end
        end

        def record(po, value, line_no)
          entry = po.find { |candidate| candidate.msgid == value } || GetText::POEntry.new(:normal).tap do |candidate|
            candidate.msgid = value
            po << candidate
          end
          entry.references << "#{@path}:#{line_no}"
        end
    end
  end
end
