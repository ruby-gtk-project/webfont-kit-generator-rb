# frozen_string_literal: true

require 'adwaita'
require_relative 'font'
require_relative 'font_row'
require_relative 'generator'
require_relative 'google_dialog'
require_relative 'loader'
require_relative 'log'
require_relative 'options'
require_relative 'settings'
require_relative 'shortcuts_window'
require_relative 'source_view'

# Window is the application window: the list of loaded fonts with the options
# sidebar beside it, the progress page the generator drives, and the finished
# page with the snippets to paste and the log of what was written.
#
# Ported from upstream's webfontkitgenerator/window.py and window.blp,
# including the blueprint's `app-menu`.
#
# Upstream's window is an Adw.ApplicationWindow; Adwaita::ApplicationWindow is
# broken in the Ruby bindings, so this is a Gtk::ApplicationWindow holding the
# same widget tree. The one practical difference is that the stack goes in
# `child` rather than Adw's `content`.
class Window
  TITLE = 'Webfont Bundler'

  # Window actions, in the order upstream's setup_actions creates them, minus
  # the parameterised `remove-font` which is built on its own. The
  # accelerators are installed by the application, which is where upstream
  # binds them.
  ACTIONS = ['set-dir', 'open', 'google', 'generate', 'back', 'show-help-overlay'].freeze

  # The actions that open a file chooser, disabled while the window is showing
  # anything other than the font list.
  FILE_CHOOSER_ACTIONS = ['open', 'set-dir'].freeze

  attr_accessor :processing
  attr_reader :settings, :options

  def initialize(app, settings: Settings.new)
    @app = app
    @settings = settings
    @processing = false
    @out_dir = nil
    @options = Options.new(settings)
  end

  def build
    window.tap do |win|
      win.child = appstack

      appstack.tap do |stack|
        stack.add_named(toasts, 'main')
        stack.add_named(progress_handle, 'progress')
        stack.add_named(finished_view, 'finished')

        stack.signal_connect('notify::visible-child-name') { update_file_chooser_actions }
      end

      toasts.child = toolbar_view

      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = split
        view.add_bottom_bar(action_bar)
      end

      header_bar.tap do |bar|
        bar.pack_start(add_fonts_button)
        bar.pack_end(menu_button)
      end

      build_fonts_view
      build_progress_view
      build_finished_view
      build_action_bar

      setup_actions
      win.add_controller(drop_target)

      fonts_list.bind_model(model) { |font| FontRow.new(font.data).build }
      model.signal_connect('items-changed') { check_ready_state }

      check_ready_state
      update_file_chooser_actions
    end
  end

  def present = window.present

  # Entry point for the application's `open` handler, the file chooser, the
  # drop target and the Google Fonts importer alike.
  def load_fonts(files) = loader.load(files)

  # The directory the kit is written into. The file chooser sets it through
  # here once the user has picked one, and so does test/drive_generator.rb.
  def select_out_dir(selected)
    selected.then do |chosen|
      if chosen && File.writable?(chosen.path.to_s)
        @out_dir = chosen
        directory.label = File.basename(chosen.path.to_s)
        check_ready_state
      elsif chosen
        toasts.add_toast(Adwaita::Toast.new('You don’t have write access to the selected directory.'))
      end
    end
  end

  def loader = @loader ||= Loader.new(self, model)

  # The fonts the window has loaded. A Gio::ListStore because Gtk::ListBox
  # binds to a list model, which is also why Font is a GObject.
  def model = @model ||= Gio::ListStore.new(Font)

  # --- Window and main stack ----------------------------------------------

  def window
    @window ||= Gtk::ApplicationWindow.new(@app).tap do |win|
      win.title = TITLE
      win.set_default_size(1000, 600)
    end
  end

  def appstack
    @appstack ||= Gtk::Stack.new.tap do |stack|
      stack.transition_type = :crossfade
    end
  end

  # Named `toasts` because that is what the loader and the Google importer
  # reach for when they have an error to report.
  def toasts
    @toasts ||= Adwaita::ToastOverlay.new.tap do |overlay|
      overlay.vexpand = true
    end
  end

  def toolbar_view
    @toolbar_view ||= Adwaita::ToolbarView.new.tap do |view|
      view.bottom_bar_style = :raised
      view.reveal_bottom_bars = false
    end
  end

  def header_bar = @header_bar ||= Adwaita::HeaderBar.new

  def add_fonts_button
    @add_fonts_button ||= Gtk::Button.new.tap do |button|
      button.tooltip_text = 'Open Fonts'
      button.action_name = 'win.open'
      button.icon_name = 'list-add-symbolic'
    end
  end

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.tooltip_text = 'Main Menu'
      button.menu_model = app_menu
      button.focus_on_click = false
      button.direction = :none
    end
  end

  # The blueprint's `menu app-menu`: the importers section, then the help
  # section.
  def app_menu
    @app_menu ||= Gio::Menu.new.tap do |menu|
      menu.append_section(nil, importers_section)
      menu.append_section(nil, help_section)
    end
  end

  def importers_section
    @importers_section ||= Gio::Menu.new.tap do |section|
      section.append('Import from Google Fonts', 'win.google')
    end
  end

  def help_section
    @help_section ||= Gio::Menu.new.tap do |section|
      section.append('_Keyboard Shortcuts', 'win.show-help-overlay')
      section.append("_About #{TITLE}", 'app.about')
    end
  end

  # --- Fonts list and options sidebar -------------------------------------

  def split
    @split ||= Adwaita::OverlaySplitView.new.tap do |view|
      view.show_sidebar = false
      view.sidebar_position = :end
      view.max_sidebar_width = 600
      view.min_sidebar_width = 350
    end
  end

  def fonts_stack
    @fonts_stack ||= Gtk::Stack.new.tap do |stack|
      stack.transition_type = :crossfade
      stack.hexpand = true
    end
  end

  def empty_page
    @empty_page ||= Gtk::Box.new(:vertical, 48).tap do |box|
      box.valign = :center
    end
  end

  def empty_title
    @empty_title ||= Gtk::Label.new('Add some fonts').tap do |label|
      label.add_css_class('title-1')
    end
  end

  def splash_box
    @splash_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.halign = :center
    end
  end

  def splash_a = @splash_a ||= splash_image('splash-a-symbolic')
  def splash_b = @splash_b ||= splash_image('splash-b-symbolic')

  def empty_open_button
    @empty_open_button ||= Gtk::Button.new(label: 'Open Fonts').tap do |button|
      button.halign = :center
      button.action_name = 'win.open'
      button.add_css_class('suggested-action')
      button.add_css_class('pill')
    end
  end

  def fonts_page = @fonts_page ||= Gtk::Box.new(:vertical, 0)

  def fonts_scroller
    @fonts_scroller ||= Gtk::ScrolledWindow.new.tap do |scroller|
      scroller.vexpand = true
    end
  end

  def fonts_viewport = @fonts_viewport ||= Gtk::Viewport.new(nil, nil)

  def fonts_clamp
    @fonts_clamp ||= Adwaita::Clamp.new.tap do |clamp|
      clamp.margin_start = 24
      clamp.margin_end = 24
    end
  end

  def fonts_box
    @fonts_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.margin_top = 48
      box.margin_bottom = 48
    end
  end

  def fonts_list
    @fonts_list ||= Gtk::ListBox.new.tap do |list|
      list.selection_mode = :none
      list.add_css_class('content')
    end
  end

  # --- Bottom bar ---------------------------------------------------------

  def action_bar
    @action_bar ||= Gtk::ActionBar.new.tap do |bar|
      bar.add_css_class('bottom-box')
    end
  end

  def directory_box
    @directory_box ||= Gtk::Box.new(:horizontal, 12).tap do |box|
      box.valign = :center
      box.hexpand = true
    end
  end

  def directory_label_box = @directory_label_box ||= Gtk::Box.new(:horizontal, 6)

  def directory_icon
    @directory_icon ||= Gtk::Image.new.tap do |image|
      image.icon_name = 'folder-open-symbolic'
    end
  end

  def directory
    @directory ||= Gtk::Label.new('Select Output Directory').tap do |label|
      label.valign = :center
      label.ellipsize = :end
      label.add_css_class('heading')
    end
  end

  def browse_button
    @browse_button ||= Gtk::Button.new(label: 'Browse…').tap do |button|
      button.action_name = 'win.set-dir'
    end
  end

  def generate_button
    @generate_button ||= Gtk::Button.new(label: 'Generate').tap do |button|
      button.action_name = 'win.generate'
      button.add_css_class('suggested-action')
    end
  end

  # --- Progress page ------------------------------------------------------

  def progress_handle = @progress_handle ||= Gtk::WindowHandle.new

  def progress = @progress ||= Adwaita::StatusPage.new

  def progress_clamp = @progress_clamp ||= Adwaita::Clamp.new

  def progress_box = @progress_box ||= Gtk::Box.new(:vertical, 36)

  def progressbar
    @progressbar ||= Gtk::ProgressBar.new.tap do |bar|
      bar.show_text = true
    end
  end

  def cancel
    @cancel ||= Gtk::Button.new(label: 'Cancel').tap do |button|
      button.halign = :center
      button.add_css_class('pill')
    end
  end

  # --- Finished page -----------------------------------------------------

  def finished_view = @finished_view ||= Adwaita::ToolbarView.new

  def finished_header = @finished_header ||= Gtk::HeaderBar.new

  def view_switcher
    @view_switcher ||= Adwaita::ViewSwitcher.new.tap do |switcher|
      switcher.stack = finished_stack
      switcher.policy = :wide
    end
  end

  def back_button
    @back_button ||= Gtk::Button.new.tap do |button|
      button.action_name = 'win.back'
      button.icon_name = 'go-previous-symbolic'
      button.tooltip_text = 'Back'
    end
  end

  def finished_stack = @finished_stack ||= Adwaita::ViewStack.new

  def info_scroller
    @info_scroller ||= Gtk::ScrolledWindow.new.tap do |scroller|
      scroller.vexpand = true
    end
  end

  def info_viewport = @info_viewport ||= Gtk::Viewport.new(nil, nil)

  def info_page
    @info_page ||= Adwaita::StatusPage.new.tap do |page|
      page.title = 'Generation finished!'
      page.icon_name = 'completed-symbolic'
    end
  end

  def info_clamp = @info_clamp ||= Adwaita::Clamp.new

  def info_box
    @info_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
      box.valign = :center
    end
  end

  def html_label
    @html_label ||= Gtk::Label.new(
      'To link your fonts, copy the code below into the head of your HTML:',
    ).tap do |label|
      label.halign = :start
    end
  end

  def css_label
    @css_label ||= Gtk::Label.new('Or import it directly to your CSS:').tap do |label|
      label.halign = :start
    end
  end

  def src_html = @src_html ||= source_view('html')
  def src_css = @src_css ||= source_view('css')

  def open_dir_button
    @open_dir_button ||= Gtk::Button.new(label: 'Open in Files').tap do |button|
      button.halign = :center
      button.margin_top = 20
      button.add_css_class('pill')
    end
  end

  def log_page = @log_page ||= Gtk::Box.new(:vertical, 6)

  def log_scroller
    @log_scroller ||= Gtk::ScrolledWindow.new.tap do |scroller|
      scroller.vexpand = true
    end
  end

  def log_viewport = @log_viewport ||= Gtk::Viewport.new(nil, nil)

  def log_clamp
    @log_clamp ||= Adwaita::Clamp.new.tap do |clamp|
      clamp.margin_top = 20
    end
  end

  def log = @log ||= Log.new

  # --- Dialogs and controllers -------------------------------------------

  def out_dir_chooser
    @out_dir_chooser ||= Gtk::FileDialog.new.tap do |chooser|
      chooser.title = 'Select Output Directory'
    end
  end

  def fonts_chooser
    @fonts_chooser ||= Gtk::FileDialog.new.tap do |chooser|
      chooser.title = 'Open Font Files'
      chooser.filters = fonts_filters
    end
  end

  def fonts_filters
    @fonts_filters ||= Gio::ListStore.new(Gtk::FileFilter).tap do |filters|
      filters.append(
        Gtk::FileFilter.new.tap do |filter|
                  filter.name = 'OTF & TTF'
                  filter.add_mime_type('font/otf')
                  filter.add_pattern('*.otf')
                  filter.add_mime_type('font/ttf')
                  filter.add_pattern('*.ttf')
                end,
      )
    end
  end

  def drop_target
    @drop_target ||= Gtk::DropTarget.new(Gdk::FileList.gtype, :copy).tap do |target|
      target.signal_connect('drop') { |_, value, _x, _y| on_drop(value) }
    end
  end

  private

  # --- Assembly -----------------------------------------------------------

    def build_fonts_view
      split.tap do |view|
        view.content = fonts_stack
        view.sidebar = options.build
      end

      fonts_stack.tap do |stack|
        stack.add_named(empty_page, 'empty')
        stack.add_named(fonts_page, 'fonts')
      end

      empty_page.tap do |page|
        page.append(empty_title)
        page.append(splash_box)
        page.append(empty_open_button)

        splash_box.tap do |box|
          box.append(splash_a)
          box.append(splash_b)
        end
      end

      fonts_page.append(fonts_scroller)
      fonts_scroller.child = fonts_viewport
      fonts_viewport.child = fonts_clamp
      fonts_clamp.child = fonts_box
      fonts_box.append(fonts_list)
    end

    def build_progress_view
      progress_handle.child = progress
      progress.child = progress_clamp
      progress_clamp.child = progress_box

      progress_box.tap do |box|
        box.append(progressbar)
        box.append(cancel)

        # Upstream reconnects this on every generation, so its handlers pile
        # up; connecting once and asking the window for the generation that
        # is actually running does the same job without the pile.
        cancel.signal_connect('clicked') { @generator&.stop }
      end
    end

    def build_finished_view
      finished_view.tap do |view|
        view.add_top_bar(finished_header)
        view.content = finished_stack
      end

      finished_header.tap do |bar|
        bar.title_widget = view_switcher
        bar.pack_start(back_button)
      end

      finished_stack.tap do |stack|
        stack.add_titled_with_icon(
          info_scroller,
          'info',
          'Information',
          'completed-symbolic',
        )
        stack.add_titled_with_icon(
          log_page,
          'log',
          'Logs',
          'view-list-bullet-symbolic',
        )
      end

      build_info_page
      build_log_page
    end

    def build_info_page
      info_scroller.child = info_viewport
      info_viewport.child = info_page
      info_page.child = info_clamp
      info_clamp.child = info_box

      info_box.tap do |box|
        box.append(html_label)
        box.append(src_html)
        box.append(css_label)
        box.append(src_css)
        box.append(open_dir_button)

        open_dir_button.signal_connect('clicked') { open_generation_dir }
      end
    end

    def build_log_page
      log_page.append(log_scroller)
      log_scroller.child = log_viewport
      log_viewport.child = log_clamp
      log_clamp.child = log
    end

    def build_action_bar
      action_bar.pack_start(directory_box)
      action_bar.pack_end(generate_button)

      directory_box.tap do |box|
        box.append(directory_label_box)
        box.append(browse_button)

        directory_label_box.tap do |labels|
          labels.append(directory_icon)
          labels.append(directory)
        end
      end
    end

  # --- Actions ------------------------------------------------------------

  # The actions are kept in `actions` as well as handed to the window: a
  # Gio::SimpleAction whose only Ruby reference is the one `add_action`
  # consumed gets collected, and its `activate` handler goes with it.
    def setup_actions
      actions['remove-font'] = remove_font_action
      ACTIONS.each { |name| actions[name] = simple_action(name) }
      actions.each_value { |action| window.add_action(action) }
    end

    def actions = @actions ||= {}

  # The only action carrying a parameter: the index of the row whose remove
  # button was clicked.
    def remove_font_action
      Gio::SimpleAction.new('remove-font', GLib::VariantType.new('u')).tap do |action|
        # ruby-gnome hands the parameter over already unwrapped, so this is a
        # Ruby Integer rather than a GLib::Variant.
        action.signal_connect('activate') { |_, position| model.remove(position) }
      end
    end

    def simple_action(name)
      Gio::SimpleAction.new(name, nil).tap do |action|
        action.signal_connect('activate') { send(:"action_#{name.tr('-', '_')}") }
      end
    end

    def action_open
      fonts_chooser.open_multiple(window, nil) do |chooser, result|
        load_fonts(to_array(chooser.open_multiple_finish(result)))
      rescue GLib::Error => e
        report_dismissable(e)
      end
    end

    def action_set_dir
      out_dir_chooser.select_folder(window, nil) do |chooser, result|
        select_out_dir(chooser.select_folder_finish(result))
      rescue GLib::Error => e
        report_dismissable(e)
      end
    end

  # Held in an ivar for the same reason the actions are: the dialog's signal
  # handlers live as long as the Ruby object does.
    def action_google
      GoogleDialog.new(self).tap do |dialog|
        @google_dialog = dialog
        dialog.build
        dialog.present(window)
      end
    end

  # Held in an ivar because the generation runs on a thread the generator
  # owns, and because the cancel button asks the window for it.
    def action_generate
      out_dir_path.then do |path|
        unless path.nil?
          @generator = new_generator(path)
          @generator.run
        end
      end
    end

    def out_dir_path
      @out_dir&.path.then do |path|
        unless path.nil? || path.to_s.empty?
          path.to_s
        end
      end
    end

    def new_generator(path)
      Generator.new(
        self,
        path:         path,
        fonts:        to_array(model),
        formats:      options.formats,
        ranges:       options.subsetting,
        base64:       options.base64?,
        font_display: options.font_display,
      )
    end

    def action_back
      unless @processing
        appstack.visible_child_name = 'main'
      end
    end

    def action_show_help_overlay
      ShortcutsWindow.new.tap do |dialog|
        @shortcuts_window = dialog
        dialog.build
        dialog.present(window)
      end
    end

  # --- Behaviour ----------------------------------------------------------

  # The list is empty until fonts are loaded: no sidebar, no bottom bar, and
  # the splash page instead of the list.
    def check_ready_state
      model.n_items.positive?.then do |has_items|
        window.lookup_action('generate')&.set_enabled(has_items && !@out_dir.nil?)
        split.show_sidebar = has_items
        toolbar_view.reveal_bottom_bars = has_items
        if has_items
          fonts_stack.visible_child_name = 'fonts'
          toolbar_view.top_bar_style = :raised
        else
          fonts_stack.visible_child_name = 'empty'
          toolbar_view.top_bar_style = :flat
        end
      end
    end

    def update_file_chooser_actions
      (appstack.visible_child_name == 'main').then do |file_choosers|
        FILE_CHOOSER_ACTIONS.each { |name| window.lookup_action(name)&.set_enabled(file_choosers) }
      end
    end

    def open_generation_dir
      Gtk::FileLauncher.new.tap do |launcher|
        launcher.file = @out_dir
        launcher.launch(window, nil) { |handle, result| handle.launch_finish(result) }
      end
    end

  # The drop is only taken on the font list page, and the handler's return
  # value is what tells GTK whether it was accepted.
    def on_drop(value)
      (value.is_a?(Gdk::FileList) && appstack.visible_child_name == 'main').then do |accepted|
        if accepted
          load_fonts(value.files)
        end
        accepted
      end
    end

    def to_array(list)
      if list.respond_to?(:n_items)
        (0...list.n_items).map { |index| list.get_item(index) }
      else
        Array(list)
      end
    end

  # The file dialogs raise on cancellation too, which is not worth a toast.
    def report_dismissable(error)
      unless error.message.to_s.match?(/dismiss|cancel/i)
        toasts.add_toast(Adwaita::Toast.new("Error: #{error.message}."))
      end
    end

    def splash_image(icon_name)
      Gtk::Image.new.tap do |image|
        image.icon_name = icon_name
        image.pixel_size = 192
      end
    end

    def source_view(language)
      SourceView.new.tap do |view|
        view.build
        view.language = language
      end
    end
end
