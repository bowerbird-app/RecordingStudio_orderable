import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "movingInput", "positionInput", "notification", "status"]
  static values = { sendCustomEvent: Boolean }

  static customEventName = "recordingstudio:order:updated"

  connect() {
    this.previousRowIds = this.rowIds()
    this.saving = false
  }

  sync() {
    requestAnimationFrame(() => {
      if (this.saving) return

      const previousRowIds = [...this.previousRowIds]
      const currentRowIds = this.rowIds()
      const move = this.detectSingleMove(previousRowIds, currentRowIds)

      this.previousRowIds = currentRowIds

      if (!move || !this.hasFormTarget || !this.hasMovingInputTarget || !this.hasPositionInputTarget) return

      this.movingInputTarget.value = move.movingId
      this.positionInputTarget.value = String(move.targetPosition)
      this.updateDisplayedPositions(currentRowIds)
      this.hideNotification()
      this.hideStatus()
      this.saveMove(previousRowIds)
    })
  }

  async saveMove(previousRowIds) {
    this.setSaving(true)

    try {
      const response = await fetch(this.formTarget.action, {
        method: (this.formTarget.method || "post").toUpperCase(),
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: this.requestBody(),
        credentials: "same-origin"
      })

      if (!response.ok) {
        throw new Error(await this.errorMessage(response))
      }

      const payload = await response.json()

      if (this.sendCustomEventValue) {
        this.dispatchUpdateEvent(payload)
      } else {
        this.showNotification(payload.notice_html)
      }
    } catch (error) {
      this.restoreRowOrder(previousRowIds)
      this.previousRowIds = previousRowIds
      this.showStatus(error.message)
    } finally {
      this.setSaving(false)
    }
  }

  rowIds() {
    return Array.from(this.element.querySelectorAll("tbody tr[data-id]"))
      .map((row) => row.dataset.id)
      .filter(Boolean)
  }

  detectSingleMove(previousRowIds, currentRowIds) {
    if (previousRowIds.length !== currentRowIds.length) return null

    for (const [targetPosition, movingId] of currentRowIds.entries()) {
      const previousPosition = previousRowIds.indexOf(movingId)
      if (previousPosition === -1 || previousPosition === targetPosition) continue

      const previousWithout = previousRowIds.filter((id) => id !== movingId)
      const currentWithout = currentRowIds.filter((id) => id !== movingId)

      if (this.sameOrder(previousWithout, currentWithout)) {
        return { movingId, targetPosition }
      }
    }

    return null
  }

  sameOrder(left, right) {
    return left.length === right.length && left.every((value, index) => value === right[index])
  }

  restoreRowOrder(rowIds) {
    const tbody = this.element.querySelector("tbody")
    if (!tbody) return

    const rowsById = new Map(
      Array.from(tbody.querySelectorAll("tr[data-id]"))
        .map((row) => [row.dataset.id, row])
    )

    rowIds.forEach((rowId) => {
      const row = rowsById.get(rowId)
      if (row) tbody.appendChild(row)
    })

    this.updateDisplayedPositions(rowIds)
  }

  updateDisplayedPositions(rowIds) {
    const tbody = this.element.querySelector("tbody")
    if (!tbody) return

    rowIds.forEach((rowId, index) => {
      const row = tbody.querySelector(`tr[data-id="${rowId}"]`)
      const firstCell = row?.querySelector("td")

      if (firstCell) {
        firstCell.textContent = String(index + 1)
      }
    })
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  requestBody() {
    const body = new FormData(this.formTarget)

    if (this.sendCustomEventValue) {
      body.set("send_custom_event", "true")
    }

    return body
  }

  dispatchUpdateEvent(payload) {
    document.dispatchEvent(
      new CustomEvent(payload.event_name || this.constructor.customEventName, {
        detail: payload.event_detail,
        bubbles: true
      })
    )
  }

  async errorMessage(response) {
    const contentType = response.headers.get("content-type") || ""

    if (contentType.includes("application/json")) {
      const payload = await response.json()
      return payload.error || "Couldn't save page order."
    }

    return "Couldn't save page order."
  }

  setSaving(saving) {
    this.saving = saving
    this.element.classList.toggle("pointer-events-none", saving)
    this.element.classList.toggle("opacity-75", saving)
    this.element.setAttribute("aria-busy", saving ? "true" : "false")
  }

  showStatus(message) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.classList.remove("hidden")
  }

  hideStatus() {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = ""
    this.statusTarget.classList.add("hidden")
  }

  showNotification(html) {
    if (!this.hasNotificationTarget) return

    this.notificationTarget.innerHTML = html
    this.notificationTarget.classList.remove("hidden")
  }

  hideNotification() {
    if (!this.hasNotificationTarget) return

    this.notificationTarget.innerHTML = ""
    this.notificationTarget.classList.add("hidden")
  }
}
