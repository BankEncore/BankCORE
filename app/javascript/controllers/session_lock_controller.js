import { Controller } from "@hotwired/stimulus"

const LOCK_CHANNEL = "bankcore:session-lock"
const RETURN_TO_KEY = "sessionLockReturnTo"

export default class extends Controller {
  static values = {
    inactivityMinutes: { type: Number, default: 5 },
    skip: { type: Boolean, default: false }
  }

  connect() {
    this.setupBroadcastChannel()
    if (window.location.pathname === "/lock") {
      this.broadcastLock()
      return
    }
    if (this.skipValue) return

    this.resetTimer()
    this.throttleMs = 10_000
    this.lastActivityAt = Date.now()

    this.boundReset = this.resetTimer.bind(this)
    this.events = ["mousemove", "mousedown", "keydown", "scroll", "touchstart", "click"]
    this.events.forEach((name) => document.addEventListener(name, this.boundReset))
  }

  disconnect() {
    this.clearTimer()
    this.events?.forEach((name) => document.removeEventListener(name, this.boundReset))
    this.channel?.close()
  }

  setupBroadcastChannel() {
    if (typeof BroadcastChannel === "undefined") return
    this.channel = new BroadcastChannel(LOCK_CHANNEL)
    this.channel.onmessage = (e) => {
      const msg = e.data
      if (msg === "locked" && window.location.pathname !== "/lock") {
        try {
          sessionStorage.setItem(RETURN_TO_KEY, window.location.href)
        } catch (_) {}
        window.location.href = "/lock"
      } else if (msg === "unlocked") {
        try {
          const returnTo = sessionStorage.getItem(RETURN_TO_KEY)
          sessionStorage.removeItem(RETURN_TO_KEY)
          if (returnTo && window.location.pathname === "/lock") {
            window.location.href = returnTo
          }
        } catch (_) {}
      }
    }
  }

  broadcastLock() {
    if (typeof BroadcastChannel === "undefined") return
    const ch = new BroadcastChannel(LOCK_CHANNEL)
    ch.postMessage("locked")
    ch.close()
  }

  broadcastUnlock() {
    if (typeof BroadcastChannel === "undefined") return
    const ch = new BroadcastChannel(LOCK_CHANNEL)
    ch.postMessage("unlocked")
    ch.close()
  }

  resetTimer() {
    const now = Date.now()
    if (now - this.lastActivityAt < this.throttleMs) return
    this.lastActivityAt = now

    this.clearTimer()
    const ms = (this.inactivityMinutesValue || 5) * 60 * 1000
    this.timerId = setTimeout(() => this.lock(), ms)
  }

  clearTimer() {
    if (this.timerId) {
      clearTimeout(this.timerId)
      this.timerId = null
    }
  }

  async lock() {
    this.clearTimer()
    if (window.location.pathname === "/lock") return

    document.dispatchEvent(new CustomEvent("tx:session-locked", { bubbles: true }))

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    const formData = new FormData()
    formData.set("trigger", "auto")

    try {
      const response = await fetch("/lock", {
        method: "POST",
        headers: {
          "Accept": "text/html",
          "X-CSRF-Token": csrfToken || "",
          "X-Requested-With": "XMLHttpRequest"
        },
        body: formData
      })
      if (response.redirected) {
        window.location.href = response.url
      } else {
        window.location.href = "/lock"
      }
    } catch {
      window.location.href = "/lock"
    }
  }

  async unlockWithFetch(event) {
    const form = event.target
    if (form?.action?.includes("/lock") && form?.method?.toLowerCase() === "patch") {
      event.preventDefault()
      const formData = new FormData(form)
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
      try {
        const response = await fetch(form.action, {
          method: "PATCH",
          headers: {
            "Accept": "text/html",
            "X-CSRF-Token": csrfToken || "",
            "X-Requested-With": "XMLHttpRequest"
          },
          body: formData
        })
        if (response.redirected) {
          this.broadcastUnlock()
          window.location.href = response.url
        } else {
          window.location.reload()
        }
      } catch {
        window.location.reload()
      }
    }
  }
}
