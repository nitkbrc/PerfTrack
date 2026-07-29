# frozen_string_literal: true

# Windows + OneDrive fallback for tailwindcss:build.
# CLI writes to C:/Temp/scats-tw (see config/initializers/tailwindcss.rb), then
# we copy the real file into app/assets/builds/tailwind.css (gitignored).
# No symlink is left in the tree. Linux/CI/Docker skip this entirely.

if Gem.win_platform?
  LOCAL_TW_OUT = ENV.fetch("TAILWINDCSS_LOCAL_OUTPUT", "C:/Temp/scats-tw/tailwind.css").freeze
  APP_TW_OUT   = File.expand_path("app/assets/builds/tailwind.css", __dir__ + "/../..").freeze

  namespace :tailwindcss do
    desc "Copy local Tailwind output into app/assets/builds (Windows/OneDrive workaround)"
    task :copy_to_builds do
      require "fileutils"
      if File.exist?(LOCAL_TW_OUT)
        FileUtils.mkdir_p(File.dirname(APP_TW_OUT))
        FileUtils.cp(LOCAL_TW_OUT, APP_TW_OUT)
        puts "Copied Tailwind CSS → app/assets/builds/tailwind.css"
      else
        warn "tailwindcss:copy_to_builds: missing #{LOCAL_TW_OUT}"
      end
    end
  end

  # Action blocks passed to enhance run AFTER the task's own actions.
  if Rake::Task.task_defined?("tailwindcss:build")
    Rake::Task["tailwindcss:build"].enhance do
      Rake::Task["tailwindcss:copy_to_builds"].invoke
    end
  end
end
