import { Controller } from "@hotwired/stimulus"

// Fingerprint (passkeys, WebAuthn). In Mi configuración, register() lets the
// device create a key for this user (WebauthnCredentialsController); on the
// sign-in page, signIn() lets the device pick one and sign in with it
// (PasskeySessionsController). The server sends the options as JSON with
// base64url strings; the browser's API wants bytes, and back.
export default class extends Controller {
  static targets = ["button", "nickname", "error", "form"]
  static values = { optionsUrl: String, url: String, unsupported: String, failed: String }

  connect() {
    if (window.PublicKeyCredential) return

    // A browser without passkeys: in the settings say so; on the sign-in
    // page the button just isn't there.
    if (this.hasFormTarget) {
      this.formTarget.hidden = true
      this.fail(this.unsupportedValue)
    } else {
      this.element.hidden = true
    }
  }

  async register() {
    await this.run(async () => {
      const options = await this.post(this.optionsUrlValue)
      const credential = await navigator.credentials.create({ publicKey: this.creationOptions(options) })
      await this.post(this.urlValue, { credential: this.attestation(credential), nickname: this.nicknameTarget.value })
      const frame = this.element.closest("turbo-frame[src]")
      frame ? frame.reload() : window.Turbo.visit(window.location.href, { action: "replace" })
    })
  }

  async signIn() {
    await this.run(async () => {
      const options = await this.post(this.optionsUrlValue)
      const credential = await navigator.credentials.get({ publicKey: this.requestOptions(options) })
      const { redirect } = await this.post(this.urlValue, { credential: this.assertion(credential) })
      window.location.assign(redirect)
    })
  }

  async run(ceremony) {
    this.errorTarget.hidden = true
    this.buttonTarget.disabled = true
    try {
      await ceremony()
    } catch (error) {
      // The user closed the device's prompt: nothing to say.
      if (error?.name !== "NotAllowedError" && error?.name !== "AbortError") this.fail(error?.serverMessage || this.failedValue)
    } finally {
      this.buttonTarget.disabled = false
    }
  }

  fail(message) {
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }

  async post(url, body = {}) {
    const response = await fetch(url, {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content },
      body: JSON.stringify(body)
    })
    const data = await response.json().catch(() => ({}))
    if (!response.ok) throw Object.assign(new Error("request failed"), { serverMessage: data.error })
    return data
  }

  creationOptions(options) {
    return {
      ...options,
      challenge: bytes(options.challenge),
      user: { ...options.user, id: bytes(options.user.id) },
      excludeCredentials: (options.excludeCredentials || []).map((credential) => ({ ...credential, id: bytes(credential.id) }))
    }
  }

  requestOptions(options) {
    return {
      ...options,
      challenge: bytes(options.challenge),
      allowCredentials: (options.allowCredentials || []).map((credential) => ({ ...credential, id: bytes(credential.id) }))
    }
  }

  attestation(credential) {
    return {
      type: credential.type,
      id: credential.id,
      rawId: text(credential.rawId),
      clientExtensionResults: credential.getClientExtensionResults(),
      response: {
        attestationObject: text(credential.response.attestationObject),
        clientDataJSON: text(credential.response.clientDataJSON),
        transports: credential.response.getTransports?.() || []
      }
    }
  }

  assertion(credential) {
    return {
      type: credential.type,
      id: credential.id,
      rawId: text(credential.rawId),
      clientExtensionResults: credential.getClientExtensionResults(),
      response: {
        authenticatorData: text(credential.response.authenticatorData),
        clientDataJSON: text(credential.response.clientDataJSON),
        signature: text(credential.response.signature),
        userHandle: credential.response.userHandle ? text(credential.response.userHandle) : null
      }
    }
  }
}

// base64url text ⇄ bytes.
function bytes(value) {
  const base64 = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(value.length / 4) * 4, "=")
  return Uint8Array.from(atob(base64), (char) => char.charCodeAt(0)).buffer
}

function text(buffer) {
  return btoa(String.fromCharCode(...new Uint8Array(buffer))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}
