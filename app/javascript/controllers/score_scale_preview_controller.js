import { Controller } from "@hotwired/stimulus"

// Live preview of overall_score = 10 / (1 + e^(-net / k)) on the score-scale settings page.
// X = net points (auto-scaled to about ±3k), Y = overall score 0–10. Curve always through (0, 5).
export default class extends Controller {
  static targets = [
    "input",
    "curve",
    "xMin",
    "xMax",
    "rangeLabel",
    "sampleNeg",
    "sampleZero",
    "samplePos"
  ]

  static values = {
    samples: { type: Number, default: 160 },
    // Fixed wide net-points window (±halfRange), independent of k.
    halfRange: { type: Number, default: 750 }
  }

  // SVG viewBox plot area (matches markup coordinates).
  static PLOT = { left: 48, top: 16, right: 360, bottom: 168 }

  connect() {
    this.redraw()
  }

  redraw() {
    const k = this.currentK()
    const half = this.halfRangeValue
    const netMin = -half
    const netMax = half

    this.updateAxisLabels(netMin, netMax)
    this.drawCurve(netMin, netMax, k)
    this.updateSamples(k)
  }

  currentK() {
    if (!this.hasInputTarget) return 50
    const raw = Number.parseFloat(this.inputTarget.value)
    if (!Number.isFinite(raw) || raw <= 0) return 50
    return raw
  }

  score(net, k) {
    return 10 / (1 + Math.exp(-net / k))
  }

  xToSvg(net, netMin, netMax) {
    const { left, right } = this.constructor.PLOT
    const t = (net - netMin) / (netMax - netMin)
    return left + t * (right - left)
  }

  yToSvg(score) {
    const { top, bottom } = this.constructor.PLOT
    // score 10 at top, 0 at bottom
    return bottom - (score / 10) * (bottom - top)
  }

  drawCurve(netMin, netMax, k) {
    if (!this.hasCurveTarget) return

    const steps = this.samplesValue
    const parts = []

    for (let i = 0; i <= steps; i++) {
      const net = netMin + ((netMax - netMin) * i) / steps
      const x = this.xToSvg(net, netMin, netMax)
      const y = this.yToSvg(this.score(net, k))
      parts.push(`${i === 0 ? "M" : "L"}${x.toFixed(2)} ${y.toFixed(2)}`)
    }

    this.curveTarget.setAttribute("d", parts.join(" "))
  }

  updateAxisLabels(netMin, netMax) {
    if (this.hasXMinTarget) this.xMinTarget.textContent = String(netMin)
    if (this.hasXMaxTarget) this.xMaxTarget.textContent = `+${netMax}`
    if (this.hasRangeLabelTarget) {
      this.rangeLabelTarget.textContent = `Net points from ${netMin} to +${netMax}`
    }
  }

  updateSamples(k) {
    const negNet = -500
    const posNet = 500

    if (this.hasSampleNegTarget) {
      this.sampleNegTarget.textContent = `${this.score(negNet, k).toFixed(1)} at net ${negNet}`
    }
    if (this.hasSampleZeroTarget) {
      this.sampleZeroTarget.textContent = `${this.score(0, k).toFixed(1)} at net 0`
    }
    if (this.hasSamplePosTarget) {
      this.samplePosTarget.textContent = `${this.score(posNet, k).toFixed(1)} at net +${posNet}`
    }
  }
}
