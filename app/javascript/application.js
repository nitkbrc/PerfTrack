// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Show the thin Turbo progress bar immediately on nav.
if (typeof Turbo !== "undefined" && Turbo.config?.drive) {
  Turbo.config.drive.progressBarDelay = 0
}
