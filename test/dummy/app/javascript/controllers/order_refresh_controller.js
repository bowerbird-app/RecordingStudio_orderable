import { Controller } from "@hotwired/stimulus"

// FlatPack saves the modal order. Reload so the list behind the modal matches.
export default class extends Controller {
  refresh() {
    if (window.Turbo) {
      window.Turbo.visit(window.location.href, { action: "replace" })
    } else {
      window.location.reload()
    }
  }
}
