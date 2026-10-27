import { Controller } from "@hotwired/stimulus"

// Flatpack's table save sends Number(id). A UUID becomes null, so this
// controller stores the string ids from the table:reordered event instead.
export default class extends Controller {
  static values = { url: String }

  save(event) {
    const orderedIds = event.detail && event.detail.orderedIds
    if (!orderedIds || orderedIds.length === 0 || !this.hasUrlValue) return

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
      },
      body: JSON.stringify({ ordered_recording_ids: orderedIds })
    }).then((response) => {
      if (!response.ok) return

      window.location.assign("/")
    })
  }
}
