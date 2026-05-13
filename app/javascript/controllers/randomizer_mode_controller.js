import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["manualPanel", "normalPanel", "unitCheckbox", "unitPanel"]

  connect() {
    this.handleWheel = this.handleWheel.bind(this)
    this.element.addEventListener("wheel", this.handleWheel, { passive: false })
    this.toggle()
  }

  disconnect() {
    this.element.removeEventListener("wheel", this.handleWheel)
  }

  toggle() {
    const manualMode = this.selectedMode === "manual"

    this.manualPanelTarget.classList.toggle("hidden", !manualMode)
    this.normalPanelTarget.classList.toggle("hidden", manualMode)
    this.setInputsDisabled(this.normalPanelTarget, manualMode)
    this.toggleUnitPanels()
  }

  toggleUnitPanels() {
    const manualMode = this.selectedMode === "manual"
    const selectedUnits = new Set(
      this.unitCheckboxTargets
        .filter((checkbox) => checkbox.checked)
        .map((checkbox) => checkbox.value)
    )

    this.unitPanelTargets.forEach((panel) => {
      const shouldShow = manualMode && selectedUnits.has(panel.dataset.unit)
      panel.classList.toggle("hidden", !shouldShow)
      this.setInputsDisabled(panel, !shouldShow)
    })
  }

  get selectedMode() {
    return this.element.querySelector('input[name="generator_mode"]:checked')?.value || "normal"
  }

  handleWheel(event) {
    const numberInput = event.target.closest('input[type="number"]')

    if (numberInput && document.activeElement === numberInput) {
      event.preventDefault()
      numberInput.blur()
    }
  }

  setInputsDisabled(container, disabled) {
    container.querySelectorAll("input, select, textarea").forEach((field) => {
      if (field.name === "generator_mode") return
      if (field.name === "unit_filter_present") return
      if (field.name === "units[]") return

      field.disabled = disabled
    })
  }
}
