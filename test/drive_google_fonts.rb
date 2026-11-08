#!/usr/bin/env ruby
# frozen_string_literal: true

# Drives GoogleDialog's actual network path: a real GET against
# https://www.googleapis.com/webfonts/v1/webfonts (the Google Fonts
# database) through Soup::Session#send_and_read_async, followed by a real
# per-file font download, exactly as a person pasting a Google Fonts CSS
# url into the importer would trigger.
#
# test/drive_window.rb deliberately stops short of this: its header says
# plainly that the live download "needs live network access this sandbox
# does not have". This script is for the environment where that access
# *is* available, and it does not fake the response or stub the session —
# it drives the real GoogleDialog class, with the real API key the app
# ships (lib/settings.rb's 'google-api-key' default), against the real
# Google Fonts API, and then asserts against bytes that actually came back
# over the wire: a real font family name, a real font-table signature read
# out of the real downloaded font file.
#
# Run it from the dev shell:
#
#   nix develop --command xvfb-run -a ruby test/drive_google_fonts.rb
#
# It is skipped (exit 0, clearly labelled) rather than failed when there is
# no network, so it is safe to leave wired into CI that may run offline:
# the one thing this script must never do is claim success without having
# actually made the request.

require 'fileutils'
require 'resolv'
require 'tmpdir'

require 'webfont_kit_generator'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('webfont-google-drive-config')
ENV['XDG_DATA_HOME'] = Dir.mktmpdir('webfont-google-drive-data')

def network_available?
  Resolv.getaddress('www.googleapis.com')
  true
rescue Resolv::ResolvError, SocketError
  false
end

unless network_available?
  puts 'SKIPPED: no network access to www.googleapis.com in this environment'
  exit(0)
end

checks = 0
failed = []

def check(checks, failed, description)
  checks += 1
  ok = yield
  puts(ok ? "    ok   #{description}" : "    FAIL #{description}")
  failed << description unless ok
  [checks, failed]
rescue StandardError => e
  puts "    FAIL #{description} (#{e.class}: #{e.message})"
  failed << description
  [checks, failed]
end

application = WebfontKitGenerator::Application.new(
  settings: Settings.new(path: File.join(Dir.mktmpdir, 'settings.json')),
)

application.build.tap do |app|
  app.signal_connect('activate') do
    window = application.window
    window.build
    window.present

    google = GoogleDialog.new(window)
    google.build
    google.present(window.window)

    # A real, currently-published Google Fonts family. Its CSS2 url shape
    # is exactly what GoogleDialog#on_download_clicked parses before it
    # ever touches the network.
    google.url_entry.text = 'https://fonts.googleapis.com/css2?family=Roboto:wght@400'

    puts '[0] win.google is open and the url is valid'
    checks, failed = check(checks, failed, 'download button is enabled by a valid url') do
      google.download_button.sensitive?
    end

    puts '[1] clicking Download Fonts makes the real request'
    google.download_button.signal_emit('clicked')

    # GoogleDialog#terminate_dialog (the real completion path: database
    # fetched, every font file downloaded or failed) is the only place
    # that flips @running back to false, so that is the real signal to
    # poll for — there is nothing to stub here, only time to allow for.
    deadline = Time.now + 60
    context = GLib::MainContext.default
    until google.instance_variable_get(:@running) == false || Time.now > deadline
      context.iteration(true)
    end

    puts '[2] the import finished'
    checks, failed = check(checks, failed, 'the import actually finished within the deadline (terminate_dialog ran)') do
      google.instance_variable_get(:@running) == false
    end
    checks, failed = check(checks, failed, 'no errors were reported by the real request') do
      google.instance_variable_get(:@errors).empty?
    end
    checks, failed = check(checks, failed, 'at least one real font file was downloaded') do
      google.instance_variable_get(:@files).any?
    end
    checks, failed = check(checks, failed, 'the downloaded bytes are a real sfnt font (OTTO/\\x00\\x01\\x00\\x00 header)') do
      files = google.instance_variable_get(:@files)
      files.any? && files.all? do |file|
        header = File.binread(file.path, 4)
        header == "OTTO" || header == "\x00\x01\x00\x00".b || header == "true".b
      end
    end
    checks, failed = check(checks, failed, 'window.model gained a real font parsed from the downloaded bytes') do
      window.model.n_items.positive?
    end
    checks, failed = check(checks, failed, 'the parsed font is really named Roboto, read out of the downloaded file') do
      (0...window.model.n_items).any? { |i| window.model.get_item(i).data.family == 'Roboto' }
    end
    checks, failed = check(checks, failed, 'the local Google Fonts database cache was actually written to disk') do
      File.exist?(File.join(ENV.fetch('XDG_DATA_HOME'), 'webfont-kit-generator', 'google-fonts.json'))
    end

    puts
    puts "#{checks - failed.length} of #{checks} checks passed"
    failed.each { |c| puts "  failed check: #{c}" }
    application.app.quit
  end

  app.run([])
end

exit(failed.empty? ? 0 : 1)
