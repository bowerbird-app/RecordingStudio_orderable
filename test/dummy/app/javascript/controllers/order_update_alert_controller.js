import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.handleUpdate = this.handleUpdate.bind(this)
    document.addEventListener("recordingstudio:order:updated", this.handleUpdate)
  }

  disconnect() {
    document.removeEventListener("recordingstudio:order:updated", this.handleUpdate)
  }

  handleUpdate(event) {
    const message = event.detail?.message || "Saved page order."
    console.log(message)
  }
}