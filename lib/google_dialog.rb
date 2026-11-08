# frozen_string_literal: true

require 'adwaita'
require 'cgi'
require 'fileutils'
require 'gio2'
require 'json'
require 'soup3'
require 'uri'
require_relative 'translatable'

# GoogleFont is one entry of the Google Fonts API's font list. Only `family`
# and `files` are read, but the whole record is kept so the cached database
# file on disk is the same shape as the API's response, as upstream's
# GoogleFont dataclass does.
GoogleFont = Data.define(
  :kind,
  :category,
  :family,
  :subsets,
  :variants,
  :version,
  :lastModified,
  :files,
) do
  def self.from_data(data)
    new(**members.to_h { |key| [key, data[key.to_s]] })
  end
end

# GoogleFontInfo is one family the user's url asked for, and the variants of
# it they asked for.
GoogleFontInfo = Data.define(:name, :variants)

# GoogleDialog imports fonts straight from Google Fonts: paste the
# fonts.googleapis.com url a site already uses and the dialog downloads the
# font files behind it and hands them to the window to load.
#
# Ported from upstream's webfontkitgenerator/google.py and google.blp.
#
# Upstream makes its requests with libsoup 3, through the `soup3` gem here.
# The two requests it makes — the font database, then each font file — go
# through `Soup::Session#send_and_read_async`, which (unlike a background
# thread) already calls back on the GLib main loop, so widgets are touched
# directly from the completion callbacks. The ETag round trip is the same:
# the saved ETag goes out as If-None-Match, and a 304 means the cached
# database on disk is still current.
class GoogleDialog
  include Translatable

  API_URL = 'https://www.googleapis.com/webfonts/v1/webfonts?key=%s'
  USER_AGENT = 'Webfont Bundler'

  # How often the pulsing progress bar is stepped, in milliseconds.
  PROGRESS_INTERVAL = 50

  def initialize(window)
    @window = window
    @settings = window.options.settings
    @cancellable = Gio::Cancellable.new
    @cancelled = false
    @running = false
    @errors = []
    @families = []
    @files = []
    @total = 0
    @pending = 0
  end

  def session
    @session ||= Soup::Session.new.tap { |s| s.user_agent = USER_AGENT }
  end

  def build
    dialog.tap do |dlg|
      dlg.child = handle
      handle.child = stack

      stack.tap do |pages|
        pages.add_named(main_view, 'main')
        pages.add_named(loading_page, 'loading')
      end

      build_main_view
      build_loading_view
    end
  end

  def present(parent)
    dialog.present(parent)
    dialog.focus_widget = url_entry
  end

  # --- Url parsing ---------------------------------------------------------

  # The CSS API v1: family=Name:400,700|Other:400
  def parse_api_v1(query)
    query_values(query, 'family').first.to_s.split('|').filter_map do |family|
      family.split(':').then do |fields|
        if fields.length == 2
          GoogleFontInfo.new(name: fields.first, variants: fields.last.split(','))
        end
      end
    end
  end

  # The CSS API v2: family=Name:ital,wght@0,400;1,700
  def parse_api_v2(query)
    query_values(query, 'family').filter_map { |family| parse_v2_family(family) }
  end

  # Every value of one query parameter, in order.
  #
  # Not CGI.parse: it treats ';' as a parameter separator, which would cut a
  # v2 url's axis tuple list ("…@0,400;1,700") in half. Python's parse_qs,
  # which upstream uses, separates on '&' alone.
  def query_values(query, key)
    query.to_s.split('&').filter_map do |pair|
      pair.split('=', 2).then do |name, value|
        if CGI.unescape(name.to_s) == key
          CGI.unescape(value.to_s)
        end
      end
    end
  end

  # --- Widgets -------------------------------------------------------------

  def dialog
    @dialog ||= Adwaita::Dialog.new.tap do |dlg|
      dlg.content_width = 500
    end
  end

  def handle = @handle ||= Gtk::WindowHandle.new

  def stack
    @stack ||= Gtk::Stack.new.tap do |pages|
      pages.transition_type = :crossfade
      pages.hexpand = true
    end
  end

  def main_view = @main_view ||= Adwaita::ToolbarView.new

  def main_header
    @main_header ||= Adwaita::HeaderBar.new.tap do |bar|
      bar.valign = :start
      bar.show_title = false
      bar.add_css_class('flat')
    end
  end

  def main_page
    @main_page ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = 'font-x-generic-symbolic'
      page.title = _('Import from Google Fonts')
      page.description = _('Download fonts from Google Fonts for self-hosting')
    end
  end

  def main_clamp = @main_clamp ||= Adwaita::Clamp.new

  def main_box
    @main_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
      box.valign = :center
    end
  end

  def entry_box
    @entry_box ||= Gtk::Box.new(:vertical, 3).tap do |box|
      box.valign = :center
    end
  end

  def url_entry
    @url_entry ||= Gtk::Entry.new.tap do |entry|
      entry.width_request = 300
      entry.halign = :center
      entry.placeholder_text = 'https://fonts.googleapis.com/css2?family=Roboto'
      entry.set_icon_from_icon_name(:secondary, 'edit-paste-symbolic')
    end
  end

  def error_revealer
    @error_revealer ||= Gtk::Revealer.new.tap do |revealer|
      revealer.reveal_child = false
    end
  end

  def error_label
    @error_label ||= Gtk::Label.new.tap do |label|
      label.add_css_class('error')
    end
  end

  def download_button
    @download_button ||= Gtk::Button.new(label: _('Download Fonts')).tap do |button|
      button.sensitive = false
      button.halign = :center
      button.add_css_class('suggested-action')
      button.add_css_class('pill')
    end
  end

  def loading_page = @loading_page ||= Adwaita::StatusPage.new

  def loading_clamp = @loading_clamp ||= Adwaita::Clamp.new

  def loading_box = @loading_box ||= Gtk::Box.new(:vertical, 36)

  def progressbar
    @progressbar ||= Gtk::ProgressBar.new.tap do |bar|
      bar.show_text = true
      bar.width_request = 300
      bar.halign = :center
    end
  end

  def cancel_button
    @cancel_button ||= Gtk::Button.new(label: _('Cancel')).tap do |button|
      button.halign = :center
      button.add_css_class('pill')
    end
  end

  private

    def build_main_view
      main_view.tap do |view|
        view.add_top_bar(main_header)
        view.content = main_page
      end

      main_page.child = main_clamp
      main_clamp.child = main_box

      main_box.tap do |box|
        box.append(entry_box)
        box.append(download_button)

        entry_box.tap do |entries|
          entries.append(url_entry)
          entries.append(error_revealer)
        end

        error_revealer.child = error_label

        url_entry.signal_connect('changed') { on_entry_changed }
        url_entry.signal_connect('icon-press') { |_, position| on_entry_icon(position) }
        download_button.signal_connect('clicked') { on_download_clicked }
      end
    end

    def build_loading_view
      loading_page.child = loading_clamp
      loading_clamp.child = loading_box

      loading_box.tap do |box|
        box.append(progressbar)
        box.append(cancel_button)

        cancel_button.signal_connect('clicked') { on_cancel_clicked }
      end
    end

  # --- Where the downloaded data lives ------------------------------------

    def data_dir
      File.join(
        ENV.fetch('XDG_DATA_HOME', File.join(Dir.home, '.local', 'share')),
        'webfont-kit-generator',
      )
    end

    def data_file = File.join(data_dir, 'google-fonts.json')

    def local_data_exists? = File.exist?(data_file)

    def local_data
      JSON.parse(File.read(data_file)).map { |entry| GoogleFont.from_data(entry) }
    rescue StandardError => e
      warn "Could not read #{data_file}: #{e.message}"
      nil
    end

    def save_local_data(items)
      FileUtils.mkdir_p(data_dir)
      File.write(data_file, JSON.pretty_generate(items))
    end

  # --- Entry handling -----------------------------------------------------

    def on_entry_changed
      url_entry.text.then do |url|
        if url.empty?
          url_entry.remove_css_class('error')
          error_revealer.reveal_child = false
          url_entry.set_icon_from_icon_name(:secondary, 'edit-paste-symbolic')
        else
          url_entry.set_icon_from_icon_name(:secondary, 'edit-clear-symbolic')
          check_url(url)
        end
      end
    end

    def check_url(url)
      parse_url(url).then do |parsed|
        if parsed && parsed.host == 'fonts.googleapis.com' && api_path?(parsed.path)
          valid_url
        else
          invalid_url
        end
      end
    end

    def api_path?(path) = ['/css', '/css2'].include?(path)

    def parse_url(url)
      URI.parse(url)
    rescue URI::InvalidURIError
      nil
    end

    def invalid_url
      url_entry.add_css_class('error')
      download_button.sensitive = false
      error_label.text = _('Please set a valid url')
      error_revealer.reveal_child = true
    end

    def valid_url
      url_entry.remove_css_class('error')
      error_revealer.reveal_child = false
      download_button.sensitive = true
    end

  # The secondary icon clears the entry when it has text, and pastes into it
  # when it does not.
    def on_entry_icon(position)
      if position == Gtk::EntryIconPosition::SECONDARY
        if url_entry.text.empty?
          paste_text
        else
          url_entry.text = ''
        end
      end
    end

    def paste_text
      Gdk::Display.default.then do |display|
        if display
          display.clipboard.read_text_async(nil) do |clipboard, result|
            clipboard.read_text_finish(result).then do |text|
              if text
                url_entry.text = text
              end
            end
          rescue GLib::Error => e
            warn "Could not read the clipboard: #{e.message}"
          end
        end
      end
    end

    def on_download_clicked
      parse_url(url_entry.text).then do |parsed|
        @families = families_for(parsed)
        if @families.any?
          load_fonts_data
        else
          invalid_url
        end
      end
    end

    def families_for(parsed)
      case parsed&.path
      when '/css' then parse_api_v1(parsed.query)
      when '/css2' then parse_api_v2(parsed.query)
      else []
      end
    end

    def parse_v2_family(family)
      family.split(/[:@]/).then do |fields|
        case fields.length
        when 1 then GoogleFontInfo.new(name: fields.first, variants: ['regular'])
        when 3 then v2_variants(fields)
        end
      end
    end

    def v2_variants(fields)
      fields.then do |family_name, axis_tags, axis_tuples|
        axis_tags.split(',').then do |tags|
          GoogleFontInfo.new(
            name:     family_name,
            variants: axis_tuples.split(';').filter_map { |tuple| variant_id(tags.zip(tuple.split(',')).to_h) },
          )
        end
      end
    end

  # A v2 axis tuple names a weight and optionally italics; the API's own file
  # keys call weight 400 "regular" and 400 italic "italic".
    def variant_id(properties)
      properties['wght'].then do |weight|
        if weight
          italicize(base_variant(weight), properties['ital'])
        end
      end
    end

    def base_variant(weight)
      if weight == '400'
        'regular'
      else
        weight
      end
    end

    def italicize(variant, ital)
      if ital != '1'
        variant
      elsif variant == 'regular'
        'italic'
      else
        "#{variant}italic"
      end
    end

  # --- Fetching -----------------------------------------------------------

    def load_fonts_data
      stack.visible_child_name = 'loading'
      progressbar.text = ''
      loading_page.title = _('Loading Google Fonts Database')
      @running = true
      GLib::Timeout.add(PROGRESS_INTERVAL) { step_progressbar }

      database_message.then do |message|
        session.send_and_read_async(message, 0, @cancellable) do |soup_session, result|
          on_database_response(message, soup_session, result)
        end
      end
    end

    def database_message
      Soup::Message.new('GET', format(API_URL, @settings.get_string('google-api-key'))).tap do |message|
        if message && local_data_exists?
          message.request_headers.append('If-None-Match', @settings.get_string('google-fonts-sha'))
        end
      end
    end

    def on_database_response(message, soup_session, result)
      bytes = soup_session.send_and_read_finish(result)
      warn "Google Fonts Response Status #{message.status_code} #{message.reason_phrase}"

      case message.status
      when Soup::Status::OK then store_database(bytes, message.response_headers)
      when Soup::Status::NOT_MODIFIED then use_local_or_fail
      else use_local_or_fail
      end
    rescue GLib::Error => e
      warn "Google Fonts request failed: #{e.message}"
      fail_with(_('Couldn’t download the Google Fonts data.'))
    end

    def store_database(bytes, response_headers)
      # GLib::Bytes has no `get_data` in this binding's version — `to_s`
      # (aliased `to_str`) returns the raw bytes directly. This was only
      # ever exercised by reading until this round's live network drive
      # (test/drive_google_fonts.rb) actually ran the response through it
      # and hit a real NoMethodError, caught silently by the `rescue
      # StandardError` below and masked as "use the local cache or fail".
      JSON.parse(bytes.to_s).then do |data|
        if data.key?('kind')
          save_local_data(data['items'])
          @settings.set_string('google-fonts-sha', response_headers.get_one('ETag').to_s)
          find_on_data(data['items'].map { |entry| GoogleFont.from_data(entry) })
        else
          use_local_or_fail
        end
      end
    rescue StandardError => e
      warn "Could not store the Google Fonts data: #{e.message}"
      use_local_or_fail
    end

    def use_local_or_fail
      if local_data_exists?
        find_on_data(nil)
      else
        fail_with(_('Couldn’t download the Google Fonts data.'))
      end
    end

    def fail_with(error)
      @errors << error
      terminate_dialog
    end

  # --- Matching the wanted families --------------------------------------

    def find_on_data(data)
      (data || local_data).then do |fonts|
        wanted_files(fonts || []).then do |files|
          if files.any?
            download_files(files)
          else
            @errors = [_('Couldn’t find any fonts for the given url.')]
            terminate_dialog
          end
        end
      end
    end

  # [[family name, variant name, url], …] for every wanted variant that is
  # actually available, collecting an error for each one that is not.
    def wanted_files(fonts)
      @families.flat_map do |family|
        fonts.find { |font| font.family == family.name }.then do |found|
          if found
            variant_files(family, found)
          else
            @errors << _('Couldn’t find the {family_name} font family.').sub('{family_name}', family.name)
            []
          end
        end
      end.tap { |files| @total = files.length }
    end

    def variant_files(family, found)
      family.variants.filter_map do |variant|
        found.files[variant].then do |url|
          if url
            [family.name, "#{family.name} #{variant}", url]
          else
            @errors << _('Couldn’t find the {variant} variant for {family_name}.')
              .sub('{variant}', variant).sub('{family_name}', family.name)
            nil
          end
        end
      end
    end

  # --- Downloading the font files ----------------------------------------

    def download_files(files)
      @pending = @total
      progressbar.text = nil

      files.each { |family, name, url| download_file(family, name, url) }
    end

    def download_file(family, name, url)
      unless @cancelled
        loading_page.title = _('Downloading {name}').sub('{name}', family)
        session.send_and_read_async(Soup::Message.new('GET', url), 0, @cancellable) do |soup_session, result|
          on_font_downloaded(soup_session, result, name)
        end
      end
    end

    def on_font_downloaded(soup_session, result, name)
      write_font(name, soup_session.send_and_read_finish(result))
    rescue GLib::Error => e
      warn "Could not download the font file for #{name}: #{e.message}"
      @errors << _('Couldn’t download the font file for {name}.').sub('{name}', name)
    ensure
      @pending -= 1
      if @pending.zero?
        terminate_dialog
      end
    end

    def write_font(name, bytes)
      Gio::File.new_tmp(nil).first.then do |file|
        File.binwrite(file.path, bytes.to_s)
        @files << file
      end
    rescue StandardError => e
      warn "Could not write the font file for #{name}: #{e.message}"
      @errors << _('Couldn’t write the font file for {name}.').sub('{name}', name)
    end

  # --- Finishing ----------------------------------------------------------

    def terminate_dialog(cancel: false)
      @running = false
      unless cancel
        if @files.any?
          @window.load_fonts(@files)
        end
        @errors.each { |error| @window.toasts.add_toast(Adwaita::Toast.new(error)) }
      end

      dialog.close
    end

    def on_cancel_clicked
      unless @cancelled
        @cancelled = true
        @cancellable.cancel
        terminate_dialog(cancel: true)
      end
    end

  # Determinate once there are files to count, pulsing until then. Returning
  # true keeps the timeout installed; it is dropped once the dialog is done.
    def step_progressbar
      if @total.positive? && @pending.positive?
        progressbar.fraction = (@total - @pending).fdiv(@total)
      else
        progressbar.pulse
      end
      @running
    end
end
