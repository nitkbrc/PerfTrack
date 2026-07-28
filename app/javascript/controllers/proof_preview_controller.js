import { Controller } from "@hotwired/stimulus"

// Shows removable thumbnail previews for newly selected proof PNG files.
export default class extends Controller {
  static targets = [ "input", "list" ]

  connect() {
    this.files = []
  }

  disconnect() {
    this.files.forEach(({ url }) => URL.revokeObjectURL(url))
  }

  preview() {
    this.files.forEach(({ url }) => URL.revokeObjectURL(url))

    this.files = Array.from(this.inputTarget.files || [])
      .filter((file) => file.type.startsWith("image/"))
      .map((file) => ({
        id: `${file.name}-${file.lastModified}-${file.size}-${crypto.randomUUID()}`,
        file,
        url: URL.createObjectURL(file)
      }))

    this.#syncInput()
    this.#render()
  }

  remove(event) {
    event.preventDefault()
    const id = event.currentTarget.dataset.proofPreviewId
    const removed = this.files.find((entry) => entry.id === id)
    if (!removed) return

    URL.revokeObjectURL(removed.url)
    this.files = this.files.filter((entry) => entry.id !== id)
    this.#syncInput()
    this.#render()
  }

  #syncInput() {
    const transfer = new DataTransfer()
    this.files.forEach(({ file }) => transfer.items.add(file))
    this.inputTarget.files = transfer.files
  }

  #render() {
    this.listTarget.replaceChildren()

    this.files.forEach(({ id, file, url }) => {
      const wrapper = document.createElement("div")
      wrapper.className = "group relative h-20 w-20 overflow-visible"

      const card = document.createElement("div")
      card.className = "relative h-full w-full overflow-hidden rounded-xl"

      const img = document.createElement("img")
      img.src = url
      img.alt = file.name
      img.className = "h-20 w-20 rounded-xl border border-slate-200 object-cover shadow-sm"

      const overlay = document.createElement("div")
      overlay.className = "pointer-events-none absolute inset-0 z-10 rounded-xl bg-black/0 transition duration-200 group-hover:bg-black/20"

      const button = document.createElement("button")
      button.type = "button"
      button.dataset.action = "click->proof-preview#remove"
      button.dataset.proofPreviewId = id
      button.setAttribute("aria-label", "Remove proof")
      button.className = "absolute -right-3 -top-3 z-30 flex h-8 w-8 scale-95 items-center justify-center rounded-full border border-white/30 bg-black/65 text-lg leading-none text-white opacity-0 shadow-lg backdrop-blur-sm transition duration-200 group-hover:scale-100 group-hover:opacity-100 hover:scale-110 hover:bg-black/80 focus:scale-100 focus:opacity-100 focus:outline-none focus:ring-2 focus:ring-white/80"
      button.innerHTML = "<svg aria-hidden='true' viewBox='0 0 20 20' class='h-4 w-4' fill='none' stroke='currentColor' stroke-width='2.2' stroke-linecap='round'><path d='M5 5 L15 15'></path><path d='M15 5 L5 15'></path></svg>"

      card.append(img, overlay)
      wrapper.append(card, button)
      this.listTarget.append(wrapper)
    })
  }
}
