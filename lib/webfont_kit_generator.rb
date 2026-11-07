# frozen_string_literal: true

require 'gettext'

# Top-level namespace for the port, and where translation is bound.
#
# Upstream's gettext domain is `webfontkitgenerator` (`po/meson.build`'s
# `i18n.gettext('webfontkitgenerator', ...)`), kept byte-identical here so the
# 24 catalogues upstream ships under `po/` are found by the same name. Every
# file that calls `_()`/`n_()`/`p_()` includes `GetText` and binds this same
# domain and directory; see `lib/webfont_kit_generator/application.rb` and the
# other files under `lib/` that mark user-visible strings.
module WebfontKitGenerator
  DOMAIN = 'webfontkitgenerator'
  LOCALE_DIR = File.expand_path('../locale', __dir__)
end

require_relative 'webfont_kit_generator/application'
