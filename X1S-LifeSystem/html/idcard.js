const idCardOverlay = document.getElementById('idCardOverlay')
const idCard = document.getElementById('idCard')
const idCardPhoto = document.getElementById('idCardPhoto')
const idCardState = document.getElementById('idCardState')
const idCardDocType = document.getElementById('idCardDocType')
const idCardDlField = document.getElementById('idCardDlField')
const idCardDl = document.getElementById('idCardDl')
const idCardExpField = document.getElementById('idCardExpField')
const idCardExp = document.getElementById('idCardExp')
const idCardLastName = document.getElementById('idCardLastName')
const idCardFirstName = document.getElementById('idCardFirstName')
const idCardAddressField = document.getElementById('idCardAddressField')
const idCardAddress = document.getElementById('idCardAddress')
const idCardDob = document.getElementById('idCardDob')
const idCardSex = document.getElementById('idCardSex')
const idCardHgt = document.getElementById('idCardHgt')
const idCardWgtField = document.getElementById('idCardWgtField')
const idCardWgt = document.getElementById('idCardWgt')
const idCardClassRow = document.getElementById('idCardClassRow')
const idCardClass = document.getElementById('idCardClass')
const idCardEnd = document.getElementById('idCardEnd')
const idCardRstr = document.getElementById('idCardRstr')
const idCardStateId = document.getElementById('idCardStateId')

function idTranslate(key, fallback) {
    if (typeof activeLocale === 'object' && activeLocale && activeLocale[key]) return activeLocale[key]
    return fallback
}

function setIdCardVisible(visible) {
    idCardOverlay.hidden = !visible
    if (typeof postNui === 'function') {
        postNui('idCardVisibility', { visible: !!visible }).catch(() => {})
    }
}

function renderIdCard(card, silhouette) {
    if (!card || typeof card !== 'object') return

    if (card.color && card.color.a && card.color.b) {
        idCard.style.setProperty('--idcard-bg-a', card.color.a)
        idCard.style.setProperty('--idcard-bg-b', card.color.b)
    } else {
        idCard.style.removeProperty('--idcard-bg-a')
        idCard.style.removeProperty('--idcard-bg-b')
    }

    idCardState.textContent = card.stateName || ''
    idCardDocType.textContent = card.cardTitle || ''

    idCardPhoto.src = silhouette || ''
    idCardPhoto.alt = card.cardTitle || 'ID'

    idCardDlField.querySelector('.idcard__label').textContent =
        card.isLicense ? idTranslate('idcard_dl', 'DL') : idTranslate('idcard_id', 'ID')
    idCardDl.textContent = card.dlNumber || ''

    if (card.expirationDate) {
        idCardExpField.hidden = false
        idCardExp.textContent = card.expirationDate
    } else {
        idCardExpField.hidden = true
    }

    idCardLastName.textContent = card.lastName || ''
    idCardFirstName.textContent = card.firstName || ''

    if (card.address) {
        idCardAddressField.hidden = false
        idCardAddress.textContent = card.address
    } else {
        idCardAddressField.hidden = true
    }

    idCardDob.textContent = card.dob || ''
    idCardSex.textContent = card.sex || ''
    idCardHgt.textContent = card.height || ''

    if (card.weight) {
        idCardWgtField.hidden = false
        idCardWgt.textContent = card.weight
    } else {
        idCardWgtField.hidden = true
    }

    if (card.class) {
        idCardClassRow.hidden = false
        idCardClass.textContent = card.class
        idCardEnd.textContent = card.endorsement || 'NONE'
    } else {
        idCardClassRow.hidden = true
    }

    idCardRstr.textContent = card.restrictions || 'NONE'
    idCardStateId.textContent = card.stateId || ''
}

window.addEventListener('message', event => {
    const data = event.data
    if (!data || typeof data !== 'object') return

    if (data.action === 'showIdCard') {
        renderIdCard(data.card, data.silhouette)
        setIdCardVisible(true)
    }

    if (data.action === 'hideIdCard') {
        setIdCardVisible(false)
    }
})
