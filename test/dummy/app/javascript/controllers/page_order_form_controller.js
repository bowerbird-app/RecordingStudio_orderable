import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "movingInput", "positionInput"]

  connect() {
    this.previousRowIds = this.rowIds()
  }

  sync() {
    requestAnimationFrame(() => {
      const currentRowIds = this.rowIds()
      const move = this.detectSingleMove(this.previousRowIds, currentRowIds)

      this.previousRowIds = currentRowIds

      if (!move || !this.hasFormTarget || !this.hasMovingInputTarget || !this.hasPositionInputTarget) return

      this.movingInputTarget.value = move.movingId
      this.positionInputTarget.value = String(move.targetPosition)
      this.formTarget.requestSubmit()
    })
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
}
