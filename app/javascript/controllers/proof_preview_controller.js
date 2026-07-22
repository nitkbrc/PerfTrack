import { Controller } from "@hotwired/stimulus"

// Shows thumbnail previews for newly selected proof PNG files before submit.
export default class extends Controller {
  static targets = [ "input", "list" ]

  connect() {
    this.objectUrls = []
  }

  disconnect() {
    this.#revokeUrls()
  }

  preview() {
    this.#revokeUrls()
    this.listTarget.replaceChildren()

    const files = Array.from(this.inputTarget.files || [])
    files.forEach((file) => {
      if (!file.type.startsWith("image/")) return

      const url = URL.createObjectURL(file)
      this.objectUrls.push(url)

      const wrapper = document.createElement("div")
      wrapper.className = "w-20"

      const img = document.createElement("img")
      img.src = url
      img.alt = file.name
      img.className = "h-20 w-20 rounded-lg border border-slate-200 object-cover"

      const caption = document.createElement("p")
      caption.className = "mt-1 truncate text-xs text-slate-500"
      caption.title = file.name
      caption.textContent = file.name

      wrapper.append(img, caption)
      this.listTarget.append(wrapper)
    })
  }

  #revokeUrls() {
    this.objectUrls.forEach((url) => URL.revokeObjectURL(url))
    this.objectUrls = []
  }
}
