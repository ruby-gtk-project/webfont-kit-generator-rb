# frozen_string_literal: true

require 'adwaita'

# Style carries the application stylesheet.
#
# Ported from upstream's webfontkitgenerator/style.css, which meson bakes into
# the gresource bundle and Adw.Application loads for you. This port has no
# gresource, so the same rules live in a Ruby string and are installed on the
# default display at application priority — the same priority the gresource
# route uses, so a user stylesheet still wins.
module Style
  CSS = <<~STYLESHEET
    .sub-box row:not(:last-child) {
      border-bottom: 1px solid @borders;
    }

    .sub-left-box {
      border-right: 1px solid @borders;
    }

    .expander revealer list row {
      padding: 0;
    }

    .sourceview {
      border: 1px solid @borders;
      border-radius: 12px;
      padding: 12px 0;
    }

    .log text {
      background: @theme_bg_color;
    }

    .bottom-box > revealer > box {
      padding: 12px;
    }
  STYLESHEET

  # Installs the stylesheet on a display. Called once, from the application's
  # startup, before the first window is built.
  def self.apply(display = Gdk::Display.default)
    display.then do |target|
      if target
        Gtk::StyleContext.add_provider_for_display(
          target,
          provider,
          Gtk::StyleProvider::PRIORITY_APPLICATION,
        )
      end
    end
  end

  def self.provider
    @provider ||= Gtk::CssProvider.new.tap { |css| css.load(data: CSS) }
  end
end
