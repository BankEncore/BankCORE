import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    state: { type: String, default: "editing" }
  }

  connect() {
    this.applyState("editing")
  }

  handleRecalc(event) {
    if (this.isLockedState()) {
      return
    }

    const readyToPost = Boolean(event.detail?.readyToPost)
    this.applyState(readyToPost ? "ready_to_post" : "editing")
  }

  handleSubmitRequested() {
    if (this.isLockedState()) {
      return
    }

    this.applyState("validating")
  }

  handleApprovalRequired() {
    this.applyState("approval_required")
  }

  handleApprovalGranted() {
    this.applyState("ready_to_post")
  }

  handleApprovalError() {
    this.applyState("blocked")
  }

  handleApprovalCleared() {
    this.applyState("editing")
  }

  handlePostingStarted() {
    this.applyState("posting")
  }

  handlePostedSuccess() {
    this.applyState("posted")
  }

  handlePostedFailed() {
    this.applyState("blocked")
  }

  handleCancelRequested() {
    this.applyState("editing")
  }

  applyState(state) {
    this.stateValue = state
    this.element.dataset.txState = state
  }

  isLockedState() {
    return ["posting", "blocked"].includes(this.stateValue)
  }
}
