import { Controller } from "@hotwired/stimulus"

// The rich text editor of a private document (Jodit 4, MIT, vendored as
// "jodit": loaded only here, when the page opens). It replaces the text
// area (input target), which stays the field the form sends.
//
// Variables (PrivateDocumentVariables) are <span data-variable="…">: a
// button of the side panel puts one where the cursor is (keepSelection on
// mousedown keeps the cursor in the text). In the text they are one piece,
// not editable letter by letter: deleting removes the whole variable.
//
// Every change reaches the form as an "input" event, so unsaved-changes
// asks before leaving with changes.
const VARIABLE = "span[data-variable]"

export default class extends Controller {
  static targets = ["input"]

  async connect() {
    await import("jodit")
    if (!this.element.isConnected || this.editor) return

    this.editor = window.Jodit.make(this.inputTarget, {
      language: "es",
      editorClassName: "document-body",
      minHeight: 640,
      height: "auto",
      toolbarAdaptive: false,
      toolbarSticky: true,
      toolbarStickyOffset: 72,
      buttons: [
        "undo", "redo", "|", "bold", "italic", "underline", "strikethrough", "|",
        "paragraph", "font", "fontsize", "lineHeight", "brush", "|",
        "align", "ul", "ol", "indent", "outdent", "|",
        "table", "hr", "symbols", "|", "eraser", "copyformat", "|", "source", "fullsize", "preview"
      ],
      // Only text: no images, files, videos or links in a legal document.
      disablePlugins: "image,image-processor,image-properties,file,video,media,iframe,link,drag-and-drop-element," +
        "drag-and-drop,ai-assistant,speech-recognize,powered-by-jodit,about,print",
      showCharsCounter: false,
      showWordsCounter: false,
      showXPathInStatusbar: false,
      // Pasting from Word keeps the formatting without asking.
      askBeforePasteHTML: false,
      askBeforePasteFromWord: false,
      defaultActionOnPasteFromWord: "insert_clear_html",
      // The HTML view is a plain text area: nothing loads from other sites.
      sourceEditor: "area",
      beautifyHTML: false,
      spellcheck: true,
      useSearch: true
    })

    this.lockVariables()
    this.saved = this.editor.value
    this.editor.events.on("change", () => this.changed())
    this.editor.events.on("afterSetMode afterPaste", () => this.lockVariables())
  }

  disconnect() {
    this.editor?.destruct()
    this.editor = null
  }

  // The text area carries the editor's latest text when the form goes.
  sync() {
    this.editor?.synchronizeValues()
  }

  // A click on a variable's button would take the cursor out of the text.
  keepSelection(event) {
    event.preventDefault()
  }

  insert(event) {
    if (!this.editor) return

    const { key, label } = event.params
    const variable = this.editor.createInside.element("span", { "data-variable": key, contenteditable: "false" })
    variable.textContent = `[${label}]`
    if (!this.editor.s.isFocused()) this.editor.s.focus()
    this.editor.s.insertNode(variable, false, false)
    this.editor.s.setCursorAfter(variable)
    this.editor.synchronizeValues()
    this.changed()
  }

  // Each variable is a single piece in the text.
  lockVariables() {
    this.editor?.editor.querySelectorAll(VARIABLE).forEach((node) => node.setAttribute("contenteditable", "false"))
  }

  changed() {
    this.lockVariables()
    if (this.editor.value === this.saved) return

    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
