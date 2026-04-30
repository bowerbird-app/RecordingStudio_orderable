import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.sync()
  }

  sync() {
    if (!this.hasInputTarget) return

    this.inputTarget.value = this.rowIds().join(",")
  }

  rowIds() {
    return Array.from(this.element.querySelectorAll("tbody tr[data-id]"))
      .map((row) => row.dataset.id)
      .filter(Boolean)
  }
}
