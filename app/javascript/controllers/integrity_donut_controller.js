import { Controller } from "@hotwired/stimulus"

// Draws an animated filled pie chart for the Integrity Index.
// Two slices: Achievement (integrity%) and Conduct (remainder).
// Hovering a slice shows a tooltip near the cursor; no text inside the chart.

export default class extends Controller {
  static targets = ["svg", "tooltip"]
  static values  = {
    integrity:    Number,
    conduct:      Number,
    achieveColor: String,
    conductColor: String
  }

  connect() {
    this.animatePie()
  }

  animatePie() {
    const svg          = this.svgTarget
    const cx = 60, cy = 60, r = 56
    const totalDeg     = 360
    const achievePct   = this.integrityValue   // 0-100
    const conductPct   = this.conductValue     // 0-100
    const achieveColor = this.achieveColorValue
    const conductColor = this.conductColorValue

    // Edge case: full circle (no conduct or no achievement)
    if (achievePct <= 0 || conductPct <= 0) {
      const color = achievePct > 0 ? achieveColor : conductColor
      const label = achievePct > 0 ? `Achievement: ${achievePct}%` : `Conduct: ${conductPct}%`
      const circle = document.createElementNS("http://www.w3.org/2000/svg", "circle")
      circle.setAttribute("cx", cx); circle.setAttribute("cy", cy)
      circle.setAttribute("r", r);   circle.setAttribute("fill", color)
      circle.style.cursor = "pointer"
      circle.addEventListener("mouseenter", (e) => this.showTip(e, label))
      circle.addEventListener("mousemove",  (e) => this.moveTip(e))
      circle.addEventListener("mouseleave", ()  => this.hideTip())
      svg.appendChild(circle)
      return
    }

    const dur    = 900  // ms
    const easeOut = t => 1 - Math.pow(1 - t, 3)
    const start  = Date.now()

    const slices = [
      { pct: achievePct, color: achieveColor, label: `Achievement: ${achievePct}%`, startAt: 0 },
      { pct: conductPct, color: conductColor, label: `Conduct: ${conductPct}%`,     startAt: achievePct }
    ]

    // Pre-create path elements
    const paths = slices.map((s) => {
      const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
      path.setAttribute("fill", s.color)
      path.dataset.baseFill = s.color
      path.style.cursor = "pointer"
      path.style.transition = "fill 0.18s, stroke 0.18s, opacity 0.18s, filter 0.18s"
      path.addEventListener("mouseenter", (e) => { this.showTip(e, s.label); this.dimOthers(path, paths) })
      path.addEventListener("mousemove",  (e) => this.moveTip(e))
      path.addEventListener("mouseleave", ()  => { this.hideTip(); this.undim(paths) })
      svg.appendChild(path)
      return path
    })

    const tick = () => {
      const elapsed = Date.now() - start
      const t       = Math.min(elapsed / dur, 1)
      const progress = easeOut(t)   // 0 → 1

      slices.forEach((s, i) => {
        // Animate each slice from 0 up to its final angle
        const animatedPct = s.pct * progress
        const startAngle  = (s.startAt / 100) * totalDeg
        const sweepAngle  = (animatedPct   / 100) * totalDeg

        if (sweepAngle < 0.1) { paths[i].setAttribute("d", ""); return }
        if (sweepAngle >= 359.9) {
          // Full circle — use <circle> instead of path
          paths[i].setAttribute("d",
            `M ${cx} ${cy} m -${r} 0 a ${r} ${r} 0 1 1 ${r * 2} 0 a ${r} ${r} 0 1 1 -${r * 2} 0`)
          return
        }

        const toRad = (deg) => (deg - 90) * (Math.PI / 180)
        const x1 = cx + r * Math.cos(toRad(startAngle))
        const y1 = cy + r * Math.sin(toRad(startAngle))
        const x2 = cx + r * Math.cos(toRad(startAngle + sweepAngle))
        const y2 = cy + r * Math.sin(toRad(startAngle + sweepAngle))
        const large = sweepAngle > 180 ? 1 : 0

        paths[i].setAttribute("d",
          `M ${cx} ${cy} L ${x1.toFixed(3)} ${y1.toFixed(3)} A ${r} ${r} 0 ${large} 1 ${x2.toFixed(3)} ${y2.toFixed(3)} Z`)
      })

      if (t < 1) requestAnimationFrame(tick)
    }

    requestAnimationFrame(tick)
  }

  showTip(event, label) {
    this.tooltipTarget.textContent = label
    this.tooltipTarget.classList.remove("opacity-0")
    this.tooltipTarget.classList.add("opacity-100")
    this.moveTip(event)
  }

  moveTip(event) {
    const tip = this.tooltipTarget
    tip.style.left = `${event.clientX + 14}px`
    tip.style.top  = `${event.clientY - 10}px`
  }

  hideTip() {
    this.tooltipTarget.classList.remove("opacity-100")
    this.tooltipTarget.classList.add("opacity-0")
  }

  dimOthers(active, all) {
    all.forEach(p => {
      const base = p.dataset.baseFill
      if (p === active) {
        p.setAttribute("fill", this.emphasizeFill(base))
        p.setAttribute("stroke", "#ffffff")
        p.setAttribute("stroke-width", "2.5")
        p.style.opacity = "1"
        p.style.filter = "drop-shadow(0 1px 2px rgb(0 0 0 / 0.18))"
      } else {
        p.setAttribute("fill", base)
        p.removeAttribute("stroke")
        p.removeAttribute("stroke-width")
        p.style.opacity = "0.32"
        p.style.filter = "none"
      }
    })
  }

  undim(all) {
    all.forEach(p => {
      p.setAttribute("fill", p.dataset.baseFill)
      p.removeAttribute("stroke")
      p.removeAttribute("stroke-width")
      p.style.opacity = "1"
      p.style.filter = "none"
    })
  }

  // Slightly darken the active slice so it reads clearly against the dimmed peer.
  emphasizeFill(hex) {
    const rgb = this.parseHex(hex)
    if (!rgb) return hex
    const factor = 0.88
    const channel = (c) => Math.round(c * factor)
    return `#${[channel(rgb.r), channel(rgb.g), channel(rgb.b)]
      .map(v => v.toString(16).padStart(2, "0")).join("")}`
  }

  parseHex(hex) {
    const m = hex.match(/^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i)
    if (!m) return null
    return { r: parseInt(m[1], 16), g: parseInt(m[2], 16), b: parseInt(m[3], 16) }
  }
}
