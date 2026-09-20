const robberyHud = document.getElementById('robberyHud')
const robberyPrompt = document.getElementById('robberyPrompt')
const robberyPromptLabel = document.getElementById('robberyPromptLabel')
const robberyFingerprint = document.getElementById('robberyFingerprint')
const robberyFpTitle = document.getElementById('robberyFpTitle')
const robberyFpRings = document.getElementById('robberyFpRings')
const robberyFpStatus = document.getElementById('robberyFpStatus')
const robberyProgress = document.getElementById('robberyProgress')
const robberyProgressLabel = document.getElementById('robberyProgressLabel')
const robberyProgressFill = document.getElementById('robberyProgressFill')

let fpTotalRings = 0
let fpMaxMistakes = 0
let fpRingEls = []

function fpTranslate(key, fallback) {
    if (typeof activeLocale === 'object' && activeLocale && activeLocale[key]) return activeLocale[key]
    return fallback
}

function showRobberyHud() {
    robberyHud.hidden = false
}

function hideRobberyHudIfIdle() {
    if (robberyFingerprint.hidden && robberyProgress.hidden) {
        robberyHud.hidden = true
    }
}

function showPrompt(label) {
    robberyPromptLabel.textContent = label || ''
    robberyPrompt.hidden = false
}

function hidePrompt() {
    robberyPrompt.hidden = true
}

function buildFingerprintRings(totalRings) {
    fpRingEls = []
    robberyFpRings.innerHTML = ''

    const outerSize = 220
    const step = totalRings > 1 ? (outerSize - 64) / (totalRings - 1) : 0

    for (let i = 1; i <= totalRings; i++) {
        const size = Math.max(64, outerSize - (i - 1) * step)
        const ring = document.createElement('div')
        ring.className = 'robbery-ring'
        ring.style.width = `${size}px`
        ring.style.height = `${size}px`
        robberyFpRings.appendChild(ring)
        fpRingEls[i] = ring
    }
}

function setRingActive(ring, speedDegPerSec, zoneStartDeg, zoneDegrees) {
    for (let i = 1; i < ring; i++) {
        const prior = fpRingEls[i]
        if (prior) {
            prior.classList.remove('robbery-ring--active', 'robbery-ring--miss')
            prior.classList.add('robbery-ring--cleared')
            prior.innerHTML = ''
        }
    }

    const el = fpRingEls[ring]
    if (!el) return
    el.classList.remove('robbery-ring--cleared', 'robbery-ring--miss')
    el.classList.add('robbery-ring--active')
    el.innerHTML = ''

    const zone = document.createElement('div')
    zone.className = 'robbery-ring__zone'
    const start = zoneStartDeg
    const end = (zoneStartDeg + zoneDegrees) % 360
    let gradient
    if (start <= end) {
        gradient = `conic-gradient(from 0deg, transparent 0deg, transparent ${start}deg, var(--red-bright, #ff3b46) ${start}deg, var(--red-bright, #ff3b46) ${end}deg, transparent ${end}deg, transparent 360deg)`
    } else {
        gradient = `conic-gradient(from 0deg, var(--red-bright, #ff3b46) 0deg, var(--red-bright, #ff3b46) ${end}deg, transparent ${end}deg, transparent ${start}deg, var(--red-bright, #ff3b46) ${start}deg, var(--red-bright, #ff3b46) 360deg)`
    }
    zone.style.background = gradient
    el.appendChild(zone)

    const needle = document.createElement('div')
    needle.className = 'robbery-ring__needle'
    needle.style.animationDuration = `${360 / Math.max(1, speedDegPerSec)}s`
    el.appendChild(needle)
}

function updateFpStatus(ring, mistakesLeft) {
    const ringLabel = fpTranslate('robbery_hack_ring_status', 'Ring %s / %s')
        .replace('%s', ring).replace('%s', fpTotalRings)
    const mistakesLabel = fpTranslate('robbery_hack_mistakes_status', 'Mistakes left: %s')
        .replace('%s', mistakesLeft)
    robberyFpStatus.textContent = `${ringLabel}  •  ${mistakesLabel}`
}

function openFingerprint(data) {
    fpTotalRings = data.totalRings || 1
    fpMaxMistakes = data.maxMistakes || 0
    robberyFpTitle.textContent = data.label || ''
    buildFingerprintRings(fpTotalRings)
    updateFpStatus(1, fpMaxMistakes)
    robberyFingerprint.hidden = false
    showRobberyHud()
}

function closeFingerprint() {
    robberyFingerprint.hidden = true
    robberyFpRings.innerHTML = ''
    fpRingEls = []
    hideRobberyHudIfIdle()
}

let progressTimer = null

function openProgress(data) {
    robberyProgressLabel.textContent = data.label || ''
    robberyProgressFill.style.transition = 'none'
    robberyProgressFill.style.width = '0%'
    robberyProgressFill.offsetWidth
    robberyProgressFill.style.transition = `width linear ${Math.max(0, data.durationMs || 0)}ms`
    robberyProgress.hidden = false
    showRobberyHud()

    if (progressTimer) window.clearTimeout(progressTimer)
    progressTimer = window.setTimeout(() => {
        robberyProgressFill.style.width = '100%'
    }, 30)
}

function closeProgress() {
    robberyProgress.hidden = true
    robberyProgressFill.style.transition = 'none'
    robberyProgressFill.style.width = '0%'
    hideRobberyHudIfIdle()
}

window.addEventListener('message', event => {
    const data = event.data
    if (!data || typeof data !== 'object') return

    switch (data.action) {
        case 'robberyPromptShow':
            showPrompt(data.label)
            break
        case 'robberyPromptHide':
            hidePrompt()
            break
        case 'robberyFingerprintOpen':
            openFingerprint(data)
            break
        case 'robberyFingerprintRing':
            setRingActive(data.ring, data.speedDegPerSec, data.zoneStartDeg, data.zoneDegrees)
            updateFpStatus(data.ring, fpMaxMistakes)
            break
        case 'robberyFingerprintHit': {
            const el = fpRingEls[data.ring]
            if (el) {
                el.classList.remove('robbery-ring--active')
                el.classList.add('robbery-ring--cleared')
                el.innerHTML = ''
            }
            break
        }
        case 'robberyFingerprintMiss': {
            const activeEl = robberyFpRings.querySelector('.robbery-ring--active')
            if (activeEl) {
                activeEl.classList.add('robbery-ring--miss')
                window.setTimeout(() => activeEl.classList.remove('robbery-ring--miss'), 220)
            }
            const mistakesLabel = fpTranslate('robbery_hack_mistakes_status', 'Mistakes left: %s')
                .replace('%s', data.mistakesLeft)
            robberyFpStatus.textContent = robberyFpStatus.textContent.split('•')[0] + '•  ' + mistakesLabel
            break
        }
        case 'robberyFingerprintClose':
            closeFingerprint()
            break
        case 'robberyProgressOpen':
            openProgress(data)
            break
        case 'robberyProgressClose':
            closeProgress()
            break
        default:
            break
    }
})
