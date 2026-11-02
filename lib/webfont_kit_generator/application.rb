# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative '../settings'
require_relative '../style'
require_relative '../window'

module WebfontKitGenerator
  # The port's application object.
  #
  # Ported from upstream's webfontkitgenerator/main.py: one window, the `about`
  # action, and the accelerators for the window's actions. Upstream's
  # HANDLES_OPEN flag lets the desktop file open font files with the app; the
  # same handling lives in `open_files`, called from the launcher with whatever
  # paths it was given.
  #
  # Adwaita::Application is broken in the Ruby bindings, so the application
  # object comes from Gtk and only the widgets inside the window are Adwaita.
  #
  # House style (see .claude/skills/ruby-gtk): every widget is a memoized
  # method, all configuration lives in its `tap`, assembly happens only in
  # `build`, and the launcher is one expression.
  class Application
    APP_ID = 'org.rubygtkproject.WebfontKitGenerator'

    # Upstream's name for the app, which is what GLib.set_application_name sets
    # and the window title shows.
    APP_NAME = 'Webfont Bundler'

    VERSION = '0.1.0'

    # Window action => accelerators, as main.py's setup_actions binds them.
    # Upstream writes "<Ctl>o" and "<Ctl>g" and so on, which is not a modifier
    # GTK knows; this port binds the modifier upstream meant.
    WINDOW_ACCELS = {
      'open'              => ['<Control>o'],
      'google'            => ['<Control>g'],
      'set-dir'           => ['<Control>d'],
      'back'              => ['Escape'],
      'show-help-overlay' => ['<Control>question'],
    }.freeze

    # Upstream's custom icons are compiled into its gresource bundle, where
    # GTK finds them by the resource path alone. There is no gresource here, so
    # the same icons ship in data/icons and the directory is added to the icon
    # theme's search path. A search path is scanned as
    # <path>/<theme>/<size>/<context>, which is why they sit under hicolor/.
    ICONS_DIR = File.expand_path('../../data/icons', __dir__)

    def initialize(settings: nil)
      @settings = settings
      @pending_files = []
    end

    def build
      app.tap do
        GLib.application_name = APP_NAME

        app.signal_connect('activate') do
          register_icons
          Style.apply

          Gtk::Window.set_default_icon_name(APP_ID)
          app.add_action(about_action)
          WINDOW_ACCELS.each { |name, accels| app.set_accels_for_action("win.#{name}", accels) }

          window.build
          window.present
          flush_pending_files
        end
      end
    end

    # Files named on the command line, which upstream handles through
    # Gio.Application's `open`. They are kept until the window exists, then
    # loaded into it.
    def open_files(paths)
      @pending_files.concat(paths.map { |path| Gio::File.new_for_path(File.expand_path(path)) })
      self
    end

    def window = @window ||= Window.new(app, settings: settings)

    def settings = @settings ||= Settings.new

    def app = @app ||= Gtk::Application.new(APP_ID, :default_flags)

    def about_action
      @about_action ||= Gio::SimpleAction.new('about', nil).tap do |action|
        action.signal_connect('activate') { show_about }
      end
    end

    private

      def register_icons
        Gtk::IconTheme.get_for_display(Gdk::Display.default).add_search_path(ICONS_DIR)
      end

      def flush_pending_files
        if @pending_files.any?
          window.load_fonts(@pending_files)
          @pending_files = []
        end
      end

    # Upstream builds this from its appdata; the port has no appdata in a
    # resource bundle, so the same fields are set directly.
      def show_about
        Adwaita::AboutDialog.new.tap do |dialog|
          dialog.application_name = APP_NAME
          dialog.application_icon = APP_ID
          dialog.version = VERSION
          dialog.developer_name = 'Rafael Mardojai CM'
          dialog.license_type = Gtk::License::GPL_3_0
          dialog.website = 'https://github.com/rafaelmardojai/webfont-kit-generator'
          dialog.issue_url = 'https://github.com/ruby-gtk-project/webfont-kit-generator-rb/issues'
          dialog.comments = 'Generate woff2 and woff webfont kits from otf and ttf fonts.'
          dialog.present(window.window)
        end
      end
  end
end
