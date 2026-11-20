import { Controller } from "@hotwired/stimulus"

// «Copiar permisos de otro usuario» (Fernando, 2026-11-18): marks every box
// of the permission table as the chosen user has it (and clears the rest);
// the module rows follow (permission-matrix). Nothing is saved until the
// form is.
export default class extends Controller {
  static values = { users: Object }

  copy(event) {
    const permissions = this.usersValue[event.target.value]
    if (!permissions) return

    this.element.querySelectorAll("input[type=checkbox][data-permission-key]").forEach((box) => {
      const marked = (permissions[box.dataset.permissionKey] || []).includes(box.dataset.permissionAction)
      if (box.checked === marked) return
      box.checked = marked
      box.dispatchEvent(new Event("input", { bubbles: true }))
      box.dispatchEvent(new Event("change", { bubbles: true }))
    })
  }
}
