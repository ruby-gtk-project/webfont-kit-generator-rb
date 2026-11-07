# frozen_string_literal: true

require 'gettext'

# Shared mixin for every class in `lib/` that shows a user-visible string.
#
# `GetText#bindtextdomain` binds to the class it is called on, not to the
# process (see `.claude/skills/translation-parity/references/ruby-gettext.md`),
# so each translating class includes this module instead of repeating the
# bind call. The domain name and catalogue layout are upstream's own
# (`po/meson.build`'s `i18n.gettext('webfontkitgenerator', ...)`), kept
# byte-identical so the 24 languages upstream ships under `po/` are found by
# the same name.
module Translatable
  DOMAIN = 'webfontkitgenerator'
  LOCALE_DIR = File.expand_path('../locale', __dir__)

  def self.included(base)
    base.include(GetText)
    base.bindtextdomain(DOMAIN, path: LOCALE_DIR)
  end
end
