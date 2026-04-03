let currentPanel = null;
let refuelState = {
    stationId: null,
    station: null,
    fuelTypes: [],
    selectedFuel: null,
    selectedPayment: 'cash',
    litresNeeded: 0,
    currentFuel: 0,
    tankCapacity: 0,
    pricePerLitre: 0,
};

let ownerState = {
    entityType: null,
    entityId: null,
    priceMultiplier: 1.0,
};

// ── NUI MESSAGE HANDLER ──
window.addEventListener('message', function(event) {
    const data = event.data;

    switch (data.action) {
        case 'openRefuel':
            openRefuelPanel(data);
            break;
        case 'openOwnerDashboard':
            openOwnerPanel(data);
            break;
        case 'openContracts':
            openContractsPanel(data);
            break;
        case 'updateProgress':
            updateProgress(data);
            break;
        case 'showProgress':
            showProgress(data);
            break;
        case 'hideProgress':
            hideProgress();
            break;
        case 'close':
            closePanel();
            break;
    }
});

// ── KEY HANDLER ──
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        closePanel();
    }
});

// ── PANEL MANAGEMENT ──
function showPanel(id) {
    hideAllPanels();
    document.getElementById('app').classList.remove('hidden');
    document.getElementById(id).classList.remove('hidden');
    currentPanel = id;
}

function hideAllPanels() {
    document.querySelectorAll('.panel').forEach(p => p.classList.add('hidden'));
}

function closePanel() {
    hideAllPanels();
    document.getElementById('app').classList.add('hidden');
    currentPanel = null;
    fetch('https://hbs-fuel/nuiClose', {
        method: 'POST',
        body: JSON.stringify({}),
    });
}

// ── REFUEL PANEL ──
function openRefuelPanel(data) {
    refuelState.stationId = data.stationId;
    refuelState.station = data.station;
    refuelState.fuelTypes = data.fuelTypes || [];
    refuelState.currentFuel = data.currentFuel || 0;
    refuelState.tankCapacity = data.tankCapacity || 65;
    refuelState.litresNeeded = Math.max(data.tankCapacity - data.currentFuel, 0);

    document.getElementById('refuel-station-name').textContent = data.stationLabel || 'Fuel Station';

    // Gauge
    updateGauge(refuelState.currentFuel, refuelState.tankCapacity);

    // Fuel type buttons
    const container = document.getElementById('fuel-type-options');
    container.innerHTML = '';
    refuelState.fuelTypes.forEach((ft, i) => {
        const btn = document.createElement('button');
        btn.className = 'option-btn' + (i === 0 ? ' selected' : '');
        btn.textContent = ft.label;
        btn.dataset.fuel = ft.value;
        btn.onclick = () => selectFuelType(ft.value);
        container.appendChild(btn);
    });

    if (refuelState.fuelTypes.length > 0) {
        selectFuelType(refuelState.fuelTypes[0].value);
    }

    // Slider
    const slider = document.getElementById('refuel-slider');
    slider.max = refuelState.litresNeeded;
    slider.value = refuelState.litresNeeded;
    slider.oninput = () => updateSlider();

    updateSlider();
    showPanel('refuel-panel');
}

function selectFuelType(fuelType) {
    refuelState.selectedFuel = fuelType;

    document.querySelectorAll('#fuel-type-options .option-btn').forEach(btn => {
        btn.classList.toggle('selected', btn.dataset.fuel === fuelType);
    });

    const ft = refuelState.fuelTypes.find(f => f.value === fuelType);
    refuelState.pricePerLitre = ft ? ft.price : 0;
    document.getElementById('price-per-litre').textContent = '$' + refuelState.pricePerLitre.toFixed(2);
    updateSlider();
}

function selectPayment(method) {
    refuelState.selectedPayment = method;
    document.querySelectorAll('[data-payment]').forEach(btn => {
        btn.classList.toggle('selected', btn.dataset.payment === method);
    });
}

function updateSlider() {
    const slider = document.getElementById('refuel-slider');
    const litres = parseFloat(slider.value) || 0;
    const cost = litres * refuelState.pricePerLitre;

    document.getElementById('slider-litres').textContent = litres.toFixed(1) + ' L';
    document.getElementById('slider-cost').textContent = '$' + cost.toFixed(2);
    document.getElementById('price-total').textContent = '$' + cost.toFixed(2);
}

function setFillPercent(pct) {
    const slider = document.getElementById('refuel-slider');
    slider.value = (refuelState.litresNeeded * pct / 100).toFixed(1);
    updateSlider();
}

function updateGauge(current, max) {
    const pct = max > 0 ? Math.min(current / max, 1) : 0;
    const totalLength = 141.37;
    const offset = totalLength * (1 - pct);
    const fill = document.getElementById('gauge-fill');
    fill.style.strokeDashoffset = offset;

    if (pct <= 0.15) fill.style.stroke = '#ef4444';
    else if (pct <= 0.35) fill.style.stroke = '#f59e0b';
    else fill.style.stroke = '#10b981';

    document.getElementById('gauge-current').textContent = Math.round(current);
    document.getElementById('gauge-max').textContent = Math.round(max);
}

function confirmRefuel() {
    const litres = parseFloat(document.getElementById('refuel-slider').value) || 0;
    if (litres <= 0) return;

    fetch('https://hbs-fuel/nuiConfirmRefuel', {
        method: 'POST',
        body: JSON.stringify({
            fuelType: refuelState.selectedFuel,
            litres: litres,
            paymentMethod: refuelState.selectedPayment,
        }),
    });

    closePanel();
}

// ── PROGRESS ──
function showProgress(data) {
    document.getElementById('progress-label').textContent = data.label || 'Refueling...';
    document.getElementById('progress-litres').textContent = '0.0 / ' + (data.totalLitres || 0).toFixed(1) + ' L';
    document.getElementById('progress-bar-fill').style.width = '0%';
    document.getElementById('refuel-progress').classList.remove('hidden');
    document.getElementById('app').classList.remove('hidden');
}

function updateProgress(data) {
    const pct = data.percent || 0;
    document.getElementById('progress-bar-fill').style.width = pct + '%';
    document.getElementById('progress-litres').textContent =
        (data.delivered || 0).toFixed(1) + ' / ' + (data.total || 0).toFixed(1) + ' L';
}

function hideProgress() {
    document.getElementById('refuel-progress').classList.add('hidden');
    if (!currentPanel) {
        document.getElementById('app').classList.add('hidden');
    }
}

// ── OWNER DASHBOARD ──
function openOwnerPanel(data) {
    ownerState.entityType = data.entityType;
    ownerState.entityId = data.entityId;
    ownerState.priceMultiplier = data.priceMultiplier || 1.0;

    document.getElementById('owner-station-name').textContent = data.label || 'Station Dashboard';
    document.getElementById('dash-revenue-available').textContent = Math.floor(data.revenueAvailable || 0);
    document.getElementById('dash-revenue-total').textContent = Math.floor(data.revenueTotal || 0);
    document.getElementById('dash-price-mult').textContent = ownerState.priceMultiplier.toFixed(2);

    const priceSlider = document.getElementById('price-slider');
    priceSlider.value = ownerState.priceMultiplier;
    priceSlider.min = data.minMult || 0.5;
    priceSlider.max = data.maxMult || 2.0;

    // Show/hide pricing card based on entity type
    const pricingCard = document.querySelector('.pricing-card');
    if (data.entityType === 'refinery') {
        pricingCard.style.display = 'none';
    } else {
        pricingCard.style.display = '';
    }

    // Stock bars
    const stockContainer = document.getElementById('stock-bars');
    stockContainer.innerHTML = '';
    const stock = data.stock || {};
    for (const [fuelType, info] of Object.entries(stock)) {
        const pct = info.max > 0 ? Math.round((info.current / info.max) * 100) : 0;
        let barClass = 'high';
        if (pct <= 15) barClass = 'low';
        else if (pct <= 40) barClass = 'mid';

        stockContainer.innerHTML += `
            <div class="stock-item">
                <div class="stock-item-header">
                    <span class="stock-item-label">${capitalize(fuelType)}</span>
                    <span class="stock-item-value">${Math.round(info.current)}L / ${Math.round(info.max)}L (${pct}%)</span>
                </div>
                <div class="stock-bar-track">
                    <div class="stock-bar-fill ${barClass}" style="width: ${pct}%"></div>
                </div>
            </div>`;
    }

    // Orders and order form (stations only)
    const ordersSection = document.getElementById('owner-orders-section');
    const orderForm = document.getElementById('owner-order-form');
    if (data.entityType === 'station') {
        ordersSection.style.display = '';
        orderForm.style.display = '';
        renderOrders(data.orders || []);
        renderOrderForm(data.fuelTypes || []);
    } else {
        ordersSection.style.display = 'none';
        orderForm.style.display = 'none';
    }

    showPanel('owner-panel');
}

function onPriceSlider(val) {
    ownerState.priceMultiplier = parseFloat(val);
    document.getElementById('dash-price-mult').textContent = ownerState.priceMultiplier.toFixed(2);
}

function adjustPrice(delta) {
    const slider = document.getElementById('price-slider');
    let newVal = parseFloat(slider.value) + delta;
    newVal = Math.max(parseFloat(slider.min), Math.min(parseFloat(slider.max), newVal));
    slider.value = newVal.toFixed(2);
    onPriceSlider(newVal);
}

function savePrice() {
    fetch('https://hbs-fuel/nuiSetPrice', {
        method: 'POST',
        body: JSON.stringify({
            entityId: ownerState.entityId,
            priceMultiplier: ownerState.priceMultiplier,
        }),
    });
}

function withdrawRevenue() {
    fetch('https://hbs-fuel/nuiWithdrawRevenue', {
        method: 'POST',
        body: JSON.stringify({
            entityType: ownerState.entityType,
            entityId: ownerState.entityId,
        }),
    });
}

// ── OWNER ORDERS ──
let orderState = {
    selectedFuel: null,
    selectedUrgency: 'normal',
};

function renderOrders(orders) {
    const container = document.getElementById('owner-orders-list');
    if (!orders || orders.length === 0) {
        container.innerHTML = '<div style="font-size:12px;color:#555;padding:8px 0;">No active orders.</div>';
        return;
    }
    container.innerHTML = '';
    orders.forEach(o => {
        const pct = o.litresRequired > 0 ? Math.round((o.litresDelivered / o.litresRequired) * 100) : 0;
        container.innerHTML += `
            <div class="order-card">
                <div class="order-card-header">
                    <span class="order-card-title">${capitalize(o.product)} — ${(o.litresRequired || 0).toFixed(0)}L</span>
                    <span class="order-status ${o.status}">${o.status}</span>
                </div>
                <div class="order-card-details">
                    <span>Delivered: ${(o.litresDelivered || 0).toFixed(0)}L (${pct}%)</span>
                    <span>Payout: $${o.payout || 0}</span>
                </div>
                <div class="order-progress">
                    <div class="stock-bar-track"><div class="stock-bar-fill ${pct > 60 ? 'high' : pct > 30 ? 'mid' : 'low'}" style="width:${pct}%"></div></div>
                </div>
            </div>`;
    });
}

function renderOrderForm(fuelTypes) {
    const container = document.getElementById('order-fuel-options');
    container.innerHTML = '';
    const types = fuelTypes || [];
    types.forEach((ft, i) => {
        const btn = document.createElement('button');
        btn.className = 'option-btn' + (i === 0 ? ' selected' : '');
        btn.textContent = ft;
        btn.dataset.fuel = ft;
        btn.onclick = () => selectOrderFuel(ft);
        container.appendChild(btn);
    });
    if (types.length > 0) {
        orderState.selectedFuel = types[0];
    }
    updateOrderSlider();
}

function selectOrderFuel(fuelType) {
    orderState.selectedFuel = fuelType;
    document.querySelectorAll('#order-fuel-options .option-btn').forEach(btn => {
        btn.classList.toggle('selected', btn.dataset.fuel === fuelType);
    });
}

function selectUrgency(urgency) {
    orderState.selectedUrgency = urgency;
    document.querySelectorAll('[data-urgency]').forEach(btn => {
        btn.classList.toggle('selected', btn.dataset.urgency === urgency);
    });
}

function updateOrderSlider() {
    const val = document.getElementById('order-litres-slider').value;
    document.getElementById('order-litres-value').textContent = val + ' L';
}

function submitFuelOrder() {
    const litres = parseInt(document.getElementById('order-litres-slider').value) || 0;
    if (!orderState.selectedFuel || litres <= 0) return;

    fetch('https://hbs-fuel/nuiOrderFuel', {
        method: 'POST',
        body: JSON.stringify({
            entityId: ownerState.entityId,
            fuelType: orderState.selectedFuel,
            litres: litres,
            urgency: orderState.selectedUrgency,
        }),
    });
}

// ── CONTRACTS ──
function openContractsPanel(data) {
    // Active contract
    const activeDiv = document.getElementById('active-contract');
    const activeContent = document.getElementById('active-contract-content');

    if (data.active) {
        const c = data.active;
        const pct = c.litresRequired > 0 ? Math.round((c.litresDelivered / c.litresRequired) * 100) : 0;

        activeContent.innerHTML = `
            <div class="contract-card urgency-${c.urgency}">
                <div class="contract-card-header">
                    <span class="contract-type">${c.type === 'crude' ? 'Crude Haul' : 'Fuel Delivery'} - ${capitalize(c.product)}</span>
                    <span class="contract-urgency ${c.urgency}">${c.urgency}</span>
                </div>
                <div class="contract-details">
                    <span><span class="label">Progress:</span> ${(c.litresDelivered || 0).toFixed(0)}/${(c.litresRequired || 0).toFixed(0)}L (${pct}%)</span>
                    <span><span class="label">Payout:</span> $${c.payout || 0}</span>
                </div>
                <div class="contract-progress-bar">
                    <div class="stock-bar-track"><div class="stock-bar-fill ${pct > 60 ? 'high' : pct > 30 ? 'mid' : 'low'}" style="width:${pct}%"></div></div>
                </div>
                <div class="contract-actions">
                    <button onclick="contractWaypoint('pickup')">Waypoint: Pickup</button>
                    <button onclick="contractWaypoint('dropoff')">Waypoint: Dropoff</button>
                    <button class="cancel-btn" onclick="cancelContract()">Cancel</button>
                </div>
            </div>`;
        activeDiv.classList.remove('hidden');
    } else {
        activeDiv.classList.add('hidden');
    }

    // Available contracts
    const listDiv = document.getElementById('contracts-list');
    const available = data.available || [];

    if (available.length === 0) {
        listDiv.innerHTML = `
            <div class="empty-state">
                <svg viewBox="0 0 24 24" fill="currentColor"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8l-6-6zm-1 2l5 5h-5V4zM8 13h8v2H8v-2zm0 4h5v2H8v-2z"/></svg>
                <p>No contracts available right now.<br>Check back shortly.</p>
            </div>`;
    } else {
        listDiv.innerHTML = '';
        available.forEach(c => {
            const card = document.createElement('div');
            card.className = 'contract-card urgency-' + (c.urgency || 'normal');
            card.innerHTML = `
                <div class="contract-card-header">
                    <span class="contract-type">${c.type === 'crude' ? 'Crude Haul' : 'Fuel Delivery'} - ${capitalize(c.product)}</span>
                    <span class="contract-urgency ${c.urgency || 'normal'}">${c.urgency || 'normal'}</span>
                </div>
                <div class="contract-details">
                    <span><span class="label">Required:</span> ${(c.litresRequired || 0).toFixed(0)}L</span>
                    <span><span class="label">Pickup:</span> ${c.pickupLabel || c.pickupId || '?'}</span>
                    <span><span class="label">Dropoff:</span> ${c.dropoffLabel || c.dropoffId || '?'}</span>
                    <span><span class="label">Expires:</span> ${c.expiresIn || '?'}</span>
                </div>
                <div class="contract-payout">$${c.payout || 0}</div>
                <div class="contract-actions">
                    <button class="accept-btn" onclick="acceptContract('${c.id}')">Accept Contract</button>
                </div>`;
            listDiv.appendChild(card);
        });
    }

    showPanel('contracts-panel');
}

function acceptContract(contractId) {
    fetch('https://hbs-fuel/nuiAcceptContract', {
        method: 'POST',
        body: JSON.stringify({ contractId: contractId }),
    });
    closePanel();
}

function cancelContract() {
    fetch('https://hbs-fuel/nuiCancelContract', {
        method: 'POST',
        body: JSON.stringify({}),
    });
    closePanel();
}

function contractWaypoint(type) {
    fetch('https://hbs-fuel/nuiContractWaypoint', {
        method: 'POST',
        body: JSON.stringify({ type: type }),
    });
}

function refreshContracts() {
    fetch('https://hbs-fuel/nuiRefreshContracts', {
        method: 'POST',
        body: JSON.stringify({}),
    });
}

// ── UTIL ──
function capitalize(str) {
    if (!str) return '';
    return str.charAt(0).toUpperCase() + str.slice(1);
}
