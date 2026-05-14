import { Controller } from "@hotwired/stimulus"

const BYDAY = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]

export default class extends Controller {
  static targets = [
    "recurrenceInput", "chip", "chipHint",
    "weeklyDayField", "oneDateField", "daySelect", "dateInput",
    "monthlySubpicker", "monthlyTypeRadio", "monthlyNthSelects",
    "monthlyWeekdaySelect", "monthlyOrdinalSelect",
    "customBuilder", "customFreq", "customInterval", "customWeekday", "customDateHint",
  ]

  connect() {
    this.activeChip = this.#detectActiveChip()
    this.#applyChipUI()
    if (this.activeChip === "custom") this.#populateCustomBuilder()
  }

  selectChip(event) {
    this.activeChip = event.currentTarget.dataset.chipId
    this.#applyChipUI()
    this.updateRule()
  }

  updateRule() {
    if (this.activeChip === "monthly") this.#syncMonthlyNthVisibility()
    this.recurrenceInputTarget.value = this.#buildRule()
  }

  // ── Private ──────────────────────────────────────────────────────────────

  #detectActiveChip() {
    const rule = this.recurrenceInputTarget.value
    if (!rule) return "one_time"
    if (rule.includes("FREQ=WEEKLY")) {
      const intervalMatch = rule.match(/INTERVAL=(\d+)/)
      const interval = intervalMatch ? parseInt(intervalMatch[1]) : 1
      if (interval === 2) return "biweekly"
      if (interval === 1) return "weekly"
      return "custom"
    }
    if (rule.includes("FREQ=MONTHLY")) return "monthly"
    return "custom"
  }

  #applyChipUI() {
    const chip = this.activeChip
    const active   = ["bg-ink", "text-white", "border-ink"]
    const inactive = ["bg-white", "text-ink", "border-stone/30"]

    this.chipTargets.forEach(btn => {
      const isActive = btn.dataset.chipId === chip
      btn.classList.toggle("bg-ink",          isActive)
      btn.classList.toggle("text-white",       isActive)
      btn.classList.toggle("border-ink",       isActive)
      btn.classList.toggle("bg-white",        !isActive)
      btn.classList.toggle("text-ink",        !isActive)
      btn.classList.toggle("border-stone/30", !isActive)
    })

    const showWeeklyDay   = chip === "weekly"  || chip === "biweekly"
    const showDateInput   = chip === "one_time" || chip === "monthly" || chip === "custom"
    const showMonthly     = chip === "monthly"
    const showCustom      = chip === "custom"

    this.weeklyDayFieldTarget.classList.toggle("hidden", !showWeeklyDay)
    this.oneDateFieldTarget.classList.toggle("hidden", !showDateInput)
    this.monthlySubpickerTarget.classList.toggle("hidden", !showMonthly)
    this.customBuilderTarget.classList.toggle("hidden", !showCustom)

    if (this.hasCustomDateHintTarget) {
      this.customDateHintTarget.classList.toggle("hidden", chip !== "custom")
    }

    const dateEl = this.oneDateFieldTarget.querySelector("input[type='date']")
    if (dateEl) dateEl.required = chip === "one_time" || chip === "custom"
  }

  #buildRule() {
    switch (this.activeChip) {
      case "one_time":  return ""
      case "weekly":    return `FREQ=WEEKLY;BYDAY=${this.#selectedByday()}`
      case "biweekly":  return `FREQ=WEEKLY;INTERVAL=2;BYDAY=${this.#selectedByday()}`
      case "monthly":   return this.#buildMonthlyRule()
      case "custom":    return this.#buildCustomRule()
      default:          return ""
    }
  }

  #selectedByday() {
    const select = this.hasDaySelectTarget ? this.daySelectTarget : null
    const idx = parseInt(select?.value ?? 0)
    return BYDAY[idx] ?? "SU"
  }

  #buildMonthlyRule() {
    const radios = this.monthlyTypeRadioTargets
    const subtype = radios.find(r => r.checked)?.value ?? "same_day"

    if (subtype === "same_day") {
      const dateInput = this.hasDateInputTarget ? this.dateInputTarget : null
      const dayOfMonth = dateInput?.value ? new Date(dateInput.value + "T12:00:00").getDate() : 1
      return `FREQ=MONTHLY;BYMONTHDAY=${dayOfMonth}`
    }

    const weekday = this.hasMonthlyWeekdaySelectTarget ? this.monthlyWeekdaySelectTarget.value : "MO"
    const ordinal = this.hasMonthlyOrdinalSelectTarget ? this.monthlyOrdinalSelectTarget.value : "1"
    return `FREQ=MONTHLY;BYDAY=${ordinal}${weekday}`
  }

  #buildCustomRule() {
    const freq     = this.hasCustomFreqTarget     ? this.customFreqTarget.value     : "WEEKLY"
    const interval = this.hasCustomIntervalTarget ? this.customIntervalTarget.value : "1"
    const checked  = this.customWeekdayTargets.filter(cb => cb.checked).map(cb => cb.value)

    let rule = `FREQ=${freq};INTERVAL=${interval}`
    if (freq === "WEEKLY" && checked.length > 0) rule += `;BYDAY=${checked.join(",")}`
    return rule
  }

  #syncMonthlyNthVisibility() {
    const radios  = this.monthlyTypeRadioTargets
    const subtype = radios.find(r => r.checked)?.value ?? "same_day"
    this.monthlyNthSelectsTarget.classList.toggle("hidden", subtype !== "nth_weekday")
  }

  #populateCustomBuilder() {
    const rule = this.recurrenceInputTarget.value
    if (!rule) return

    const freqMatch     = rule.match(/FREQ=(\w+)/)
    const intervalMatch = rule.match(/INTERVAL=(\d+)/)
    const bydayMatch    = rule.match(/BYDAY=([\w,]+)/)

    if (freqMatch && this.hasCustomFreqTarget) {
      this.customFreqTarget.value = freqMatch[1]
    }
    if (intervalMatch && this.hasCustomIntervalTarget) {
      this.customIntervalTarget.value = intervalMatch[1]
    }
    if (bydayMatch && this.customWeekdayTargets.length) {
      const days = bydayMatch[1].split(",")
      this.customWeekdayTargets.forEach(cb => {
        cb.checked = days.includes(cb.value)
      })
    }
  }
}
