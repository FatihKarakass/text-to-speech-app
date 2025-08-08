import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tts"
export default class extends Controller {
  static targets = [
    "text",
    "voice",
    "rate",
    "pitch",
    "lang",
    "rateLabel",
    "pitchLabel",
    "support"
  ]

  connect() {
    this.utterance = null
    this.populateVoices()

    if (typeof window.speechSynthesis === "undefined") {
      this.supportTarget.textContent = "Bu tarayıcıda Web Speech Synthesis API desteklenmiyor. Lütfen modern bir tarayıcı kullanın."
      return
    }

    // Bazı tarayıcılarda sesler async yüklenir
    window.speechSynthesis.onvoiceschanged = () => this.populateVoices()
  }

  populateVoices() {
    if (typeof window.speechSynthesis === "undefined") return
    const voices = window.speechSynthesis.getVoices() || []

    // mevcut seçimi korumaya çalış
    const previous = this.voiceTarget.value
    this.voiceTarget.innerHTML = ""

    voices.forEach((v) => {
      const option = document.createElement("option")
      option.value = v.name
      option.textContent = `${v.name} (${v.lang})${v.default ? " - varsayılan" : ""}`
      option.dataset.lang = v.lang
      option.dataset.name = v.name
      this.voiceTarget.appendChild(option)
    })

    // varsayılan dil tercihine göre seçim yap
    const desiredLang = this.hasLangTarget ? this.langTarget.value : ""
    const matchByLang = Array.from(this.voiceTarget.options).find(o => o.dataset.lang === desiredLang)
    if (previous) {
      this.voiceTarget.value = previous
    } else if (matchByLang) {
      this.voiceTarget.value = matchByLang.value
    }
  }

  updateRateLabel() {
    this.rateLabelTarget.textContent = this.rateTarget.value
  }

  updatePitchLabel() {
    this.pitchLabelTarget.textContent = this.pitchTarget.value
  }

  speak() {
    if (typeof window.speechSynthesis === "undefined") return
    const text = this.textTarget.value?.trim()
    if (!text) return

    // Önce varsa mevcut konuşmayı temizle
    window.speechSynthesis.cancel()

    const utter = new SpeechSynthesisUtterance(text)
    utter.rate = parseFloat(this.rateTarget.value || 1)
    utter.pitch = parseFloat(this.pitchTarget.value || 1)

    const lang = this.hasLangTarget ? (this.langTarget.value || "").trim() : ""
    if (lang) utter.lang = lang

    const selected = this.voiceTarget.value
    const match = window.speechSynthesis.getVoices().find(v => v.name === selected)
    if (match) utter.voice = match

    utter.onstart = () => this.onStatus("Konuşma başladı")
    utter.onend = () => this.onStatus("Konuşma bitti")
    utter.onerror = (e) => this.onStatus(`Hata: ${e.error || "bilinmeyen"}`)

    this.utterance = utter
    window.speechSynthesis.speak(utter)
  }

  pause() {
    if (typeof window.speechSynthesis === "undefined") return
    if (window.speechSynthesis.speaking && !window.speechSynthesis.paused) {
      window.speechSynthesis.pause()
      this.onStatus("Duraklatıldı")
    }
  }

  resume() {
    if (typeof window.speechSynthesis === "undefined") return
    if (window.speechSynthesis.paused) {
      window.speechSynthesis.resume()
      this.onStatus("Sürdürülüyor")
    }
  }

  cancel() {
    if (typeof window.speechSynthesis === "undefined") return
    window.speechSynthesis.cancel()
    this.onStatus("Durduruldu")
  }

  onStatus(message) {
    if (this.hasSupportTarget) {
      const alert = this.supportTarget
      const icon = alert.querySelector('i')
      const span = alert.querySelector('span')
      
      // Update message
      if (span) span.textContent = message
      
      // Update alert style based on message
      alert.className = "alert d-flex align-items-center"
      if (message.includes("Hata")) {
        alert.classList.add("alert-danger")
        if (icon) icon.className = "fas fa-exclamation-triangle me-2"
      } else if (message.includes("başladı") || message.includes("Sürdürülüyor")) {
        alert.classList.add("alert-success")
        if (icon) icon.className = "fas fa-play-circle me-2"
      } else if (message.includes("Duraklatıldı")) {
        alert.classList.add("alert-warning")
        if (icon) icon.className = "fas fa-pause-circle me-2"
      } else if (message.includes("Durduruldu") || message.includes("bitti")) {
        alert.classList.add("alert-secondary")
        if (icon) icon.className = "fas fa-stop-circle me-2"
      } else {
        alert.classList.add("alert-info")
        if (icon) icon.className = "fas fa-info-circle me-2"
      }
    }
  }
}


