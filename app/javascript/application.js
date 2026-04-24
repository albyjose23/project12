// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

const bindInteractiveUi = () => {
  document.querySelectorAll(".btn, .btn-ghost, .nav-link, .table-action, .interactive").forEach((element) => {
    if (element.dataset.uiBound === "true") return
    element.dataset.uiBound = "true"

    element.addEventListener("pointermove", (event) => {
      const rect = element.getBoundingClientRect()
      element.style.setProperty("--pointer-x", `${event.clientX - rect.left}px`)
      element.style.setProperty("--pointer-y", `${event.clientY - rect.top}px`)
    })
  })

  document.querySelectorAll("[data-toast-trigger]").forEach((trigger) => {
    if (trigger.dataset.toastBound === "true") return
    trigger.dataset.toastBound = "true"

    trigger.addEventListener("click", () => {
      const toast = document.getElementById(trigger.dataset.toastTrigger)
      if (!toast) return

      toast.classList.add("show")
      window.clearTimeout(toast.hideTimer)
      toast.hideTimer = window.setTimeout(() => {
        toast.classList.remove("show")
      }, 2600)
    })
  })

  document.querySelectorAll("form[data-demo-loading]").forEach((form) => {
    if (form.dataset.loadingBound === "true") return
    form.dataset.loadingBound = "true"

    form.addEventListener("submit", (event) => {
      event.preventDefault()

      const button = form.querySelector("[data-loading-button]")
      const label = button?.querySelector("[data-loading-label]")
      const defaultLabel = label?.textContent

      if (button) button.disabled = true
      if (label) label.textContent = form.dataset.loadingText || "Processing..."

      window.setTimeout(() => {
        const redirectUrl = form.dataset.redirectUrl
        if (redirectUrl) {
          window.location.href = redirectUrl
          return
        }

        if (button) button.disabled = false
        if (label && defaultLabel) label.textContent = defaultLabel
      }, Number(form.dataset.loadingDelay || 1400))
    })
  })
}

document.addEventListener("turbo:load", bindInteractiveUi)
