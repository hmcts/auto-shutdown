// Overview page functionality - includes calendar and recent requests

const MAX_VISIBLE_REQUESTS_PER_DAY = 3;
const MAX_VISIBLE_SPANNING_LANES = 3;

// Initialize overview when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    initializeOverview();
});

async function initializeOverview() {
    showLoading();
    try {
        await fetchIssues();
        renderOverview();
        setupOverviewEventListeners();
    } catch (error) {
        console.error('Error initializing overview:', error);
        showError();
    }
}

function renderOverview() {
    renderCalendar();
    renderRequestsList();
    hideLoading();
}

function renderCalendar() {
    const calendarGrid = document.getElementById('calendar-grid');
    const currentMonthEl = document.getElementById('current-month');

    if (!calendarGrid || !currentMonthEl) return;

    // Clear calendar
    calendarGrid.innerHTML = '';

    // Set month header
    currentMonthEl.textContent = currentDate.toLocaleDateString('en-GB', {
        month: 'long',
        year: 'numeric'
    });

    // Create calendar grid
    const firstDay = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1);
    const startDate = new Date(firstDay);
    startDate.setDate(startDate.getDate() - firstDay.getDay());

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // Create day headers
    const dayHeaders = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    dayHeaders.forEach(day => {
        const headerEl = document.createElement('div');
        headerEl.className = 'calendar-header-day';
        headerEl.textContent = day;
        calendarGrid.appendChild(headerEl);
    });

    // Create calendar structure with days array for easier manipulation
    const calendarDays = [];

    // Create calendar days (6 weeks = 42 days)
    for (let i = 0; i < 42; i++) {
        const date = new Date(startDate);
        date.setDate(startDate.getDate() + i);

        const dayElement = document.createElement('div');
        dayElement.className = 'calendar-day';
        dayElement.style.gridColumn = (i % 7) + 1;
        dayElement.style.gridRow = Math.floor(i / 7) + 2; // +2 because row 1 is headers

        if (date.getMonth() !== currentDate.getMonth()) {
            dayElement.classList.add('other-month');
        }

        if (date.toDateString() === today.toDateString()) {
            dayElement.classList.add('today');
        }

        // Day number
        const dayNumber = document.createElement('div');
        dayNumber.className = 'day-number';
        dayNumber.textContent = date.getDate();
        dayElement.appendChild(dayNumber);

        // Requests for this day (single-day only)
        const dayRequests = document.createElement('div');
        dayRequests.className = 'day-requests';
        dayElement.appendChild(dayRequests);

        calendarDays.push({
            element: dayElement,
            date: new Date(date),
            index: i,
            requestsContainer: dayRequests,
            singleDayRequests: [],
            allRequests: [],
            hiddenCount: 0
        });

        calendarGrid.appendChild(dayElement);
    }

    // startDate is midnight on the grid's first visible day, so any visible
    // date's index can be derived directly instead of searching calendarDays.
    const dayIndexFromDate = (date) => Math.round((date.getTime() - startDate.getTime()) / 86400000);

    // Process requests: bucket single-day (and any multi-day request that
    // isn't fully within this month's grid) as day chips, and full-view
    // multi-day requests as spanning bars rendered in a second pass.
    const processedRequests = new Set();
    const multiDayRequests = [];
    const spanningLanesByRow = new Map();

    filteredIssues.forEach(issue => {
        if (!issue.start_date || processedRequests.has(issue.id)) return;
        processedRequests.add(issue.id);

        const endDate = issue.end_date || issue.start_date;
        const issueStart = new Date(issue.start_date.getFullYear(), issue.start_date.getMonth(), issue.start_date.getDate());
        const issueEnd = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate());

        const isMultiDay = issueStart.getTime() !== issueEnd.getTime();
        const startIdx = dayIndexFromDate(issueStart);
        const endIdx = dayIndexFromDate(issueEnd);
        const fullyInView = startIdx >= 0 && startIdx < 42 && endIdx >= 0 && endIdx < 42;

        // Track every visible day this request touches, for the "+N more" detail view
        calendarDays.forEach(dayInfo => {
            if (dayInfo.date >= issueStart && dayInfo.date <= issueEnd) {
                dayInfo.allRequests.push(issue);
            }
        });

        if (isMultiDay && fullyInView) {
            multiDayRequests.push({ issue, issueStart, issueEnd });
        } else {
            calendarDays.forEach(dayInfo => {
                if (dayInfo.date >= issueStart && dayInfo.date <= issueEnd) {
                    dayInfo.singleDayRequests.push(issue);
                }
            });
        }
    });

    // Compute spanning-bar lane assignment first, as pure data (no DOM), so
    // each week row's lane count is known before single-day chips are placed.
    // Previously bars were positioned with a fixed top offset regardless of
    // how many single-day chips a day already had, so a multi-day bar (e.g.
    // a 2-week PCS request) could render directly on top of a same-day
    // single-day chip (e.g. an ET request) instead of stacking below it.
    const sortedMultiDay = multiDayRequests.sort((a, b) => {
        const startDiff = a.issueStart.getTime() - b.issueStart.getTime();
        if (startDiff !== 0) return startDiff;

        const aDuration = a.issueEnd.getTime() - a.issueStart.getTime();
        const bDuration = b.issueEnd.getTime() - b.issueStart.getTime();
        if (aDuration !== bDuration) return bDuration - aDuration;

        return Number(a.issue.id || 0) - Number(b.issue.id || 0);
    });

    const spanningSegments = [];

    sortedMultiDay.forEach(({ issue, issueStart, issueEnd }) => {
        const startIndex = dayIndexFromDate(issueStart);
        const endIndex = dayIndexFromDate(issueEnd);
        let currentIndex = startIndex;

        while (currentIndex <= endIndex) {
            const startRow = Math.floor(currentIndex / 7) + 2; // +2 for header row
            const startCol = (currentIndex % 7) + 1;

            const rowEnd = Math.floor(currentIndex / 7) * 7 + 6; // Last day of current week
            const segmentEnd = Math.min(endIndex, rowEnd);
            const endCol = (segmentEnd % 7) + 1;

            // Assign a lane for this week row so overlapping multi-day requests remain visible
            const rowLanes = spanningLanesByRow.get(startRow) || [];
            let laneIndex = rowLanes.findIndex(lastUsedIndex => lastUsedIndex < currentIndex);
            if (laneIndex === -1) {
                laneIndex = rowLanes.length;
            }
            rowLanes[laneIndex] = segmentEnd;
            spanningLanesByRow.set(startRow, rowLanes);

            if (laneIndex >= MAX_VISIBLE_SPANNING_LANES) {
                // Too many overlapping multi-day requests for this week row - fold this
                // segment into each covered day's "+N more" count instead of a new lane.
                for (let i = currentIndex; i <= segmentEnd; i++) {
                    calendarDays[i].hiddenCount += 1;
                }
            } else {
                spanningSegments.push({ issue, startRow, startCol, endCol, laneIndex });
            }

            currentIndex = segmentEnd + 1;
        }
    });

    // Reserve vertical space in each day cell for however many spanning-bar
    // lanes its week row actually uses, so single-day chips render below the
    // bars instead of the bars drawing over them.
    const laneCountByRow = new Map();
    spanningLanesByRow.forEach((lanes, row) => {
        laneCountByRow.set(row, Math.min(lanes.length, MAX_VISIBLE_SPANNING_LANES));
    });

    // Render single-day chips, capped per day
    calendarDays.forEach(dayInfo => {
        const row = Math.floor(dayInfo.index / 7) + 2;
        const lanesUsed = laneCountByRow.get(row) || 0;
        if (lanesUsed > 0) {
            dayInfo.requestsContainer.style.marginTop = `${lanesUsed * 20}px`;
        }

        const visible = dayInfo.singleDayRequests.slice(0, MAX_VISIBLE_REQUESTS_PER_DAY);
        visible.forEach(issue => {
            dayInfo.requestsContainer.appendChild(createRequestIndicator(issue));
        });
        dayInfo.hiddenCount += Math.max(0, dayInfo.singleDayRequests.length - MAX_VISIBLE_REQUESTS_PER_DAY);
    });

    // Draw the spanning bars now that lane assignment is finalised
    spanningSegments.forEach(segment => renderSpanningSegment(segment, calendarGrid));

    // Add a "+N more" affordance to any day that has hidden chips or lanes
    calendarDays.forEach(dayInfo => {
        if (dayInfo.hiddenCount <= 0) return;
        const moreBtn = document.createElement('button');
        moreBtn.type = 'button';
        moreBtn.className = 'day-more-indicator';
        moreBtn.textContent = `+${dayInfo.hiddenCount} more`;
        moreBtn.onclick = () => showDayDetails(dayInfo.date, dayInfo.allRequests);
        dayInfo.requestsContainer.appendChild(moreBtn);
    });
}

function renderSpanningSegment({ issue: request, startRow, startCol, endCol, laneIndex }, calendarGrid) {
    const spanningIndicator = document.createElement('div');
    spanningIndicator.className = `spanning-request-indicator ${request.status}`;

    // Include cost information if available
    let displayText = `${request.team_name || 'Unknown'} - ${parseEnvironment(request) || 'Unknown'}`;
    if (request.cost) {
        displayText += ` (${request.cost})`;
    }
    spanningIndicator.textContent = displayText;

    let tooltip = `${request.title}\nTeam: ${request.team_name}\nEnvironment: ${parseEnvironment(request)}\nStatus: ${request.status}`;
    if (request.cost) {
        tooltip += `\nCost: ${request.cost}`;
    }
    spanningIndicator.title = tooltip;

    spanningIndicator.onclick = () => showRequestDetails(request);
    spanningIndicator.style.setProperty('--lane-index', laneIndex.toString());

    spanningIndicator.style.gridColumn = `${startCol} / ${endCol + 1}`;
    spanningIndicator.style.gridRow = startRow;
    spanningIndicator.style.zIndex = '10';

    calendarGrid.appendChild(spanningIndicator);
}

function createRequestIndicator(request) {
    const indicator = document.createElement('div');
    indicator.className = `request-indicator ${request.status}`;

    // Full detail (cost, status, justification) is in the tooltip and modal;
    // the chip itself shows team + environment since that's what's needed
    // to tell same-day requests apart at a glance.
    indicator.textContent = `${request.team_name || 'Unknown'} - ${parseEnvironment(request) || 'Unknown'}`;

    let tooltip = `${request.title}\nTeam: ${request.team_name}\nEnvironment: ${parseEnvironment(request)}\nStatus: ${request.status}`;
    if (request.cost) {
        tooltip += `\nCost: ${request.cost}`;
    }
    indicator.title = tooltip;

    indicator.onclick = () => showRequestDetails(request);

    return indicator;
}

function showDayDetails(date, requests) {
    const dateLabel = date.toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });

    let details = `<h3>${dateLabel}</h3>`;
    details += `<p><strong>Total Requests:</strong> ${requests.length}</p>`;
    details += '<div class="request-list">';

    requests.forEach(request => {
        details += `<div class="request-item">
            <strong>${request.title}</strong> <span class="request-status ${request.status}">${request.status}</span>
            <br><small>Team: ${request.team_name || 'Unknown'} - Environment: ${parseEnvironment(request) || 'Unknown'}</small>
            ${request.cost ? `<br><small>Cost: ${request.cost}</small>` : ''}
        </div>`;
    });

    details += '</div>';
    showModal('Requests', details);
}

function renderRequestsList() {
    const container = document.getElementById('requests-container');
    if (!container) return;
    
    container.innerHTML = '';
    
    // Sort by most recent first and limit to last 10
    const recentRequests = [...filteredIssues]
        .sort((a, b) => b.created_at - a.created_at)
        .slice(0, 10);
    
    if (recentRequests.length === 0) {
        container.innerHTML = '<p class="no-requests">No recent requests found.</p>';
        return;
    }
    
    recentRequests.forEach(request => {
        const card = document.createElement('div');
        card.className = 'request-card';
        
        card.innerHTML = `
            <div class="request-header">
                <h4>${request.title}</h4>
                <span class="request-status ${request.status}">${request.status}</span>
            </div>
            <div class="request-details">
                <div class="detail-item">
                    <span class="detail-label">Team</span>
                    <span>${request.team_name || 'Not specified'}</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">Environment</span>
                    <span>${parseEnvironment(request) || 'Not specified'}</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">Created</span>
                    <span>${formatDate(request.created_at)}</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">Duration</span>
                    <span>${request.start_date && request.end_date ? 
                        `${formatDate(request.start_date)} - ${formatDate(request.end_date)}` : 
                        'Not specified'}</span>
                </div>
                ${request.cost ? `
                <div class="detail-item">
                    <span class="detail-label">Cost</span>
                    <span style="font-weight: 600; color: #d4351c;">${request.cost}</span>
                </div>
                ` : ''}
            </div>
        `;
        
        card.onclick = () => showRequestDetails(request);
        container.appendChild(card);
    });
}

function setupOverviewEventListeners() {
    // Calendar navigation
    const prevMonth = document.getElementById('prev-month');
    const nextMonth = document.getElementById('next-month');
    
    if (prevMonth) {
        prevMonth.addEventListener('click', () => {
            currentDate.setMonth(currentDate.getMonth() - 1);
            renderCalendar();
        });
    }
    
    if (nextMonth) {
        nextMonth.addEventListener('click', () => {
            currentDate.setMonth(currentDate.getMonth() + 1);
            renderCalendar();
        });
    }
}