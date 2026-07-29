# frozen_string_literal: true

# Windows + OneDrive workaround:
# Bun (inside tailwindcss-ruby) fails with EEXIST when creating/writing under an
# OneDrive-synced tree. Redirect the CLI -o path to a local directory outside
# OneDrive. Keep a symlink at app/assets/builds/tailwind.css → that file so
# Propshaft still finds the asset.
#
# Linux / CI / Docker: this block is a no-op. Production regenerates CSS via
# `assets:precompile` → `tailwindcss:build` (see Dockerfile) writing to the
# gem's default path app/assets/builds/tailwind.css. Never depends on C:\Temp.
#
# Note: tailwindcss-rails 4.6.0 hardcodes -o and does not honor
# TAILWINDCSS_RAILS_OUTPUT; this patch is intentional and Windows-only.

if Gem.win_platform?
  require "fileutils"

  module Tailwindcss
    module Commands
      class << self
        alias_method :__scats_compile_command_without_local_out, :compile_command

        def compile_command(**kwargs)
          command = __scats_compile_command_without_local_out(**kwargs)
          out = ENV.fetch("TAILWINDCSS_LOCAL_OUTPUT", "C:/Temp/scats-tw/tailwind.css")
          FileUtils.mkdir_p(File.dirname(out))
          idx = command.index("-o")
          command[idx + 1] = out if idx
          command
        end
      end
    end
  end
end
