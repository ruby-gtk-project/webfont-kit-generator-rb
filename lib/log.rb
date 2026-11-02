# frozen_string_literal: true

require 'adwaita'

# Log is the scrollback the generator writes its progress into: one line per
# file written, bold for section headings, italic for skipped work.
#
# A direct port of upstream's webfontkitgenerator/log.py. The lines arrive as
# Pango markup, so the <i>…</i> the generator wraps around filenames is
# rendered rather than shown literally.
class Log < Gtk::TextView
  type_register

  def initialize
    super()
    self.editable = false
    self.monospace = true
    self.wrap_mode = :word_char
    self.hexpand = true
    add_css_class('log')
  end

  # Appends one line. `bold` and `italic` wrap the text in Pango markup in the
  # same order upstream does, so both together give <i><b>text</b></i>.
  def append(text, bold: false, italic: false)
    markup(text, bold: bold, italic: italic).then do |line|
      buffer.insert_markup(buffer.end_iter, "#{line}\n", -1)
    end
  end

  def reset
    buffer.delete(buffer.start_iter, buffer.end_iter)
  end

  private

    def markup(text, bold:, italic:)
      [['b', bold], ['i', italic]].inject(text.to_s) do |marked, (tag, wanted)|
        if wanted
          "<#{tag}>#{marked}</#{tag}>"
        else
          marked
        end
      end
    end
end
