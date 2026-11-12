import { Controller } from "@hotwired/stimulus"

// The permissions of one module (Administración → Usuarios): a box per
// action marks or clears that action in every submodule of the module, and
// shows whether all, some or none of them have it.
export default class extends Controller {
  static targets = ["all", "flag"]

  connect() {
    this.update()
  }

  toggle(event) {
    const action = event.target.dataset.permissionAction
    this.flags(action).forEach((box) => { box.checked = event.target.checked })
    this.update()
  }

  update() {
    this.allTargets.forEach((all) => {
      const boxes = this.flags(all.dataset.permissionAction)
      const marked = boxes.filter((box) => box.checked).length
      all.checked = marked > 0 && marked === boxes.length
      all.indeterminate = marked > 0 && marked < boxes.length
    })
  }

  flags(action) {
    return this.flagTargets.filter((box) => box.dataset.permissionAction === action)
  }
}
