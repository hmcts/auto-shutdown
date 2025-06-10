// Insights page functionality - includes filters, statistics, and charts

// Initialize insights when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    initializeInsights();
});

async function initializeInsights() {
    showLoading();
    try {
        await fetchIssues();
        renderInsights();
        setupInsightsEventListeners();
    } catch (error) {
        console.error('Error initializing insights:', error);
        showError();
    }
}

function renderInsights() {
    populateTeamDropdown();
    populateCalendarMonthDropdown();
    renderSummary();
    renderAnalytics();
    renderCharts();
    hideLoading();
}

function populateTeamDropdown() {
    const teamFilter = document.getElementById('team-filter');
    if (!teamFilter) return;
    
    const teams = [...new Set(allIssues.map(issue => issue.team_name).filter(team => team && team.trim() !== ''))];
    teams.sort();
    
    // Clear existing options except "All"
    teamFilter.innerHTML = '<option value="">All</option>';
    
    teams.forEach(team => {
        const option = document.createElement('option');
        option.value = team;
        option.textContent = team;
        teamFilter.appendChild(option);
    });
}

function populateCalendarMonthDropdown() {
    const monthFilter = document.getElementById('calendar-month-filter');
    if (!monthFilter) return;
    
    // Generate months from actual issue data, including created_at, start_date, and end_date ranges
    const monthsSet = new Set();
    
    allIssues.forEach(issue => {
        // Add month from created_at date
        if (issue.created_at) {
            const monthKey = `${issue.created_at.getFullYear()}-${String(issue.created_at.getMonth() + 1).padStart(2, '0')}`;
            monthsSet.add(monthKey);
        }
        
        // Add months from start_date and end_date range
        if (issue.start_date && issue.end_date) {
            const startDate = new Date(issue.start_date);
            const endDate = new Date(issue.end_date);
            
            // Add each month between start_date and end_date (inclusive)
            const currentDate = new Date(startDate.getFullYear(), startDate.getMonth(), 1);
            const lastDate = new Date(endDate.getFullYear(), endDate.getMonth(), 1);
            
            while (currentDate <= lastDate) {
                const monthKey = `${currentDate.getFullYear()}-${String(currentDate.getMonth() + 1).padStart(2, '0')}`;
                monthsSet.add(monthKey);
                currentDate.setMonth(currentDate.getMonth() + 1);
            }
        }
    });
    
    // Convert to array and create month objects with labels
    const months = Array.from(monthsSet).map(monthKey => {
        const [year, month] = monthKey.split('-');
        const date = new Date(parseInt(year), parseInt(month) - 1, 1);
        const monthLabel = date.toLocaleDateString('en-GB', { month: 'long', year: 'numeric' });
        return { key: monthKey, label: monthLabel };
    });
    
    // Sort newest first
    const sortedMonths = months.sort((a, b) => b.key.localeCompare(a.key));
    
    // Clear existing options except "All Months"
    monthFilter.innerHTML = '<option value="">All Months</option>';
    
    sortedMonths.forEach(month => {
        const option = document.createElement('option');
        option.value = month.key;
        option.textContent = month.label;
        monthFilter.appendChild(option);
    });
}

function renderSummary() {
    const now = new Date();
    const stats = {
        active: 0,
        cancelled: 0,
        pending: 0,
        total: filteredIssues.length
    };

    filteredIssues.forEach(issue => {
        if (issue.status === 'cancelled') {
            stats.cancelled++;
        } else if (issue.status === 'pending') {
            stats.pending++;
        } else if (issue.status === 'approved' || issue.status === 'auto-approved') {
            // Check if the request is still active (end date hasn't passed)
            if (issue.end_date && issue.end_date >= now) {
                stats.active++;
            }
        }
    });

    const activeCount = document.getElementById('active-count');
    const cancelledCount = document.getElementById('cancelled-count');
    const pendingCount = document.getElementById('pending-count');
    const totalCount = document.getElementById('total-count');
    
    if (activeCount) activeCount.textContent = stats.active;
    if (cancelledCount) cancelledCount.textContent = stats.cancelled;
    if (pendingCount) pendingCount.textContent = stats.pending;
    if (totalCount) totalCount.textContent = stats.total;
}

function renderAnalytics() {
    // Calculate total cost
    let totalCost = 0;
    filteredIssues.forEach(issue => {
        if (issue.cost) {
            const costMatch = issue.cost.match(/£?([\d,]+\.?\d*)/);
            if (costMatch) {
                totalCost += parseFloat(costMatch[1].replace(',', ''));
            }
        }
    });
    
    // Calculate average duration
    let totalDuration = 0;
    let durationCount = 0;
    filteredIssues.forEach(issue => {
        if (issue.start_date && issue.end_date) {
            const duration = Math.ceil((issue.end_date - issue.start_date) / (1000 * 60 * 60 * 24));
            totalDuration += duration;
            durationCount++;
        }
    });
    const avgDuration = durationCount > 0 ? Math.round(totalDuration / durationCount) : 0;
    
    // Calculate approval rate
    const approvedCount = filteredIssues.filter(issue => 
        issue.status === 'approved' || issue.status === 'auto-approved'
    ).length;
    const approvalRate = filteredIssues.length > 0 
        ? Math.round((approvedCount / filteredIssues.length) * 100)
        : 0;
    
    // Find most active team
    const teamCounts = {};
    filteredIssues.forEach(issue => {
        if (issue.team_name && issue.team_name.trim() !== '') {
            teamCounts[issue.team_name] = (teamCounts[issue.team_name] || 0) + 1;
        }
    });
    
    const topTeam = Object.keys(teamCounts).length > 0 
        ? Object.keys(teamCounts).reduce((a, b) => teamCounts[a] > teamCounts[b] ? a : b)
        : 'None';
    
    // Update the UI
    const totalCostEl = document.getElementById('total-cost');
    const avgDurationEl = document.getElementById('avg-duration');
    const approvalRateEl = document.getElementById('approval-rate');
    const topTeamEl = document.getElementById('top-team');
    const costBreakdownEl = document.getElementById('cost-breakdown');
    
    if (totalCostEl) totalCostEl.textContent = totalCost > 0 ? `£${totalCost.toFixed(2)}` : 'No data';
    if (avgDurationEl) avgDurationEl.textContent = avgDuration > 0 ? `${avgDuration}` : 'No data';
    if (approvalRateEl) approvalRateEl.textContent = `${approvalRate}%`;
    if (topTeamEl) topTeamEl.textContent = topTeam;
    
    // Calculate cost breakdown by team/environment
    if (costBreakdownEl) {
        const costBreakdown = {};
        filteredIssues.forEach(issue => {
            if (issue.cost) {
                const costMatch = issue.cost.match(/£?([\d,]+\.?\d*)/);
                if (costMatch) {
                    const cost = parseFloat(costMatch[1].replace(',', ''));
                    const normalizedBusinessArea = normalizeBusinessArea(issue.business_area);
                    const key = `${issue.team_name || 'Unknown'} (${issue.environment || 'Unknown'})`;
                    costBreakdown[key] = (costBreakdown[key] || 0) + cost;
                }
            }
        });
        
        const topCostEntries = Object.entries(costBreakdown)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 3);
        
        if (topCostEntries.length > 0) {
            const breakdown = topCostEntries
                .map(([key, cost]) => `${key}: £${cost.toFixed(2)}`)
                .join('<br>');
            costBreakdownEl.innerHTML = breakdown;
        } else {
            costBreakdownEl.textContent = 'No cost data';
        }
    }
}

function renderCharts() {
    renderStatusChart();
    renderEnvironmentChart();
    renderCostChart();
    renderTrendChart();
}

function renderStatusChart() {
    const ctx = document.getElementById('statusChart');
    if (!ctx) return;
    
    // Destroy existing chart if it exists
    if (window.statusChartInstance) {
        window.statusChartInstance.destroy();
    }
    
    const statusCounts = {
        'approved': 0,
        'auto-approved': 0,
        'pending': 0,
        'denied': 0,
        'cancelled': 0
    };
    
    filteredIssues.forEach(issue => {
        if (statusCounts.hasOwnProperty(issue.status)) {
            statusCounts[issue.status]++;
        }
    });
    
    window.statusChartInstance = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ['Approved', 'Auto-Approved', 'Pending', 'Denied', 'Cancelled'],
            datasets: [{
                data: Object.values(statusCounts),
                backgroundColor: [
                    '#10b981',
                    '#34d399',
                    '#f59e0b',
                    '#ef4444',
                    '#6b7280'
                ]
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'bottom'
                }
            },
            onClick: (event, elements) => {
                if (elements.length > 0) {
                    const index = elements[0].index;
                    const statusKeys = Object.keys(statusCounts);
                    const status = statusKeys[index];
                    const count = Object.values(statusCounts)[index];
                    showStatusDetails(status, count);
                }
            }
        }
    });
}

function renderEnvironmentChart() {
    const ctx = document.getElementById('environmentChart');
    if (!ctx) return;
    
    // Destroy existing chart if it exists
    if (window.environmentChartInstance) {
        window.environmentChartInstance.destroy();
    }
    
    const envCounts = {};
    filteredIssues.forEach(issue => {
        const env = issue.environment || 'Unknown';
        envCounts[env] = (envCounts[env] || 0) + 1;
    });
    
    window.environmentChartInstance = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: Object.keys(envCounts),
            datasets: [{
                label: 'Requests',
                data: Object.values(envCounts),
                backgroundColor: '#667eea'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false
                }
            },
            scales: {
                x: {
                    display: true,
                    ticks: {
                        maxRotation: 45,
                        minRotation: 0
                    }
                },
                y: {
                    beginAtZero: true
                }
            },
            onClick: (event, elements) => {
                if (elements.length > 0) {
                    const index = elements[0].index;
                    const environment = Object.keys(envCounts)[index];
                    const count = Object.values(envCounts)[index];
                    showEnvironmentDetails(environment, count);
                }
            }
        }
    });
}

function renderCostChart() {
    const ctx = document.getElementById('costChart');
    if (!ctx) return;
    
    // Destroy existing chart if it exists
    if (window.costChartInstance) {
        window.costChartInstance.destroy();
    }
    
    const costData = filteredIssues
        .filter(issue => issue.cost)
        .map(issue => {
            const costMatch = issue.cost.match(/£?([\d,]+\.?\d*)/);
            return costMatch ? parseFloat(costMatch[1].replace(',', '')) : 0;
        })
        .filter(cost => cost > 0);
    
    if (costData.length === 0) {
        ctx.getContext('2d').fillText('No cost data available', 10, 50);
        return;
    }
    
    // Group costs into ranges
    const ranges = [
        { label: '£0-50', min: 0, max: 50 },
        { label: '£50-100', min: 50, max: 100 },
        { label: '£100-250', min: 100, max: 250 },
        { label: '£250+', min: 250, max: Infinity }
    ];
    
    const rangeCounts = ranges.map(range => 
        costData.filter(cost => cost > range.min && cost <= range.max).length
    );
    
    window.costChartInstance = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: ranges.map(r => r.label),
            datasets: [{
                label: 'Number of Requests',
                data: rangeCounts,
                backgroundColor: '#f59e0b'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false
                }
            },
            scales: {
                y: {
                    beginAtZero: true
                }
            },
            onClick: (event, elements) => {
                if (elements.length > 0) {
                    const index = elements[0].index;
                    const range = ranges[index];
                    const count = rangeCounts[index];
                    showCostRangeDetails(range, count);
                }
            }
        }
    });
}

function renderTrendChart() {
    const ctx = document.getElementById('trendChart');
    if (!ctx) return;
    
    // Destroy existing chart if it exists
    if (window.trendChartInstance) {
        window.trendChartInstance.destroy();
    }
    
    const last30Days = [];
    const today = new Date();
    for (let i = 29; i >= 0; i--) {
        const date = new Date(today);
        date.setDate(date.getDate() - i);
        last30Days.push(date);
    }
    
    const dailyCounts = last30Days.map(date => {
        return filteredIssues.filter(issue => 
            issue.created_at.toDateString() === date.toDateString()
        ).length;
    });
    
    window.trendChartInstance = new Chart(ctx, {
        type: 'line',
        data: {
            labels: last30Days.map(date => date.toLocaleDateString('en-GB', { month: 'short', day: 'numeric' })),
            datasets: [{
                label: 'New Requests',
                data: dailyCounts,
                borderColor: '#667eea',
                backgroundColor: 'rgba(102, 126, 234, 0.1)',
                fill: true
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false
                }
            },
            scales: {
                y: {
                    beginAtZero: true
                }
            }
        }
    });
}

function setupInsightsEventListeners() {
    // Filter event listeners
    const datePresetFilter = document.getElementById('date-preset-filter');
    const calendarMonthFilter = document.getElementById('calendar-month-filter');
    const businessAreaFilter = document.getElementById('business-area-filter');
    const teamFilter = document.getElementById('team-filter');
    const environmentFilter = document.getElementById('environment-filter');
    const statusFilter = document.getElementById('status-filter');
    const startDateFilter = document.getElementById('start-date-filter');
    const endDateFilter = document.getElementById('end-date-filter');
    
    if (datePresetFilter) datePresetFilter.addEventListener('change', applyDatePreset);
    if (calendarMonthFilter) calendarMonthFilter.addEventListener('change', applyFilters);
    if (businessAreaFilter) businessAreaFilter.addEventListener('change', applyFilters);
    if (teamFilter) teamFilter.addEventListener('change', applyFilters);
    if (environmentFilter) environmentFilter.addEventListener('change', applyFilters);
    if (statusFilter) statusFilter.addEventListener('change', applyFilters);
    if (startDateFilter) startDateFilter.addEventListener('change', applyFilters);
    if (endDateFilter) endDateFilter.addEventListener('change', applyFilters);
    
    // Action button listeners
    const clearFiltersBtn = document.getElementById('clear-filters');
    const exportCsv = document.getElementById('export-csv');
    const exportJson = document.getElementById('export-json');
    const exportPdf = document.getElementById('export-pdf');
    
    if (clearFiltersBtn) clearFiltersBtn.addEventListener('click', clearFilters);
    if (exportCsv) exportCsv.addEventListener('click', exportCSV);
    if (exportJson) exportJson.addEventListener('click', exportJSON);
    if (exportPdf) exportPdf.addEventListener('click', exportPDF);
}

function applyDatePreset() {
    const datePreset = document.getElementById('date-preset-filter')?.value || '';
    const startDateFilter = document.getElementById('start-date-filter');
    const endDateFilter = document.getElementById('end-date-filter');
    
    if (datePreset && startDateFilter && endDateFilter) {
        const today = new Date();
        const startDate = new Date(today);
        startDate.setDate(today.getDate() - parseInt(datePreset));
        
        startDateFilter.value = startDate.toISOString().split('T')[0];
        endDateFilter.value = today.toISOString().split('T')[0];
    } else if (!datePreset && startDateFilter && endDateFilter) {
        // Clear date filters when "All Data" is selected
        startDateFilter.value = '';
        endDateFilter.value = '';
    }
    
    applyFilters();
}

function applyFilters() {
    const businessArea = document.getElementById('business-area-filter')?.value || '';
    const team = document.getElementById('team-filter')?.value || '';
    const environment = document.getElementById('environment-filter')?.value || '';
    const status = document.getElementById('status-filter')?.value || '';
    const startDate = document.getElementById('start-date-filter')?.value || '';
    const endDate = document.getElementById('end-date-filter')?.value || '';
    const calendarMonth = document.getElementById('calendar-month-filter')?.value || '';
    
    filteredIssues = allIssues.filter(issue => {
        // Normalize business area - only accept valid values
        const normalizedBusinessArea = normalizeBusinessArea(issue.business_area);
        if (businessArea && normalizedBusinessArea !== businessArea) return false;
        if (team && issue.team_name !== team) return false;
        if (environment && issue.environment !== environment) return false;
        if (status && issue.status !== status) return false;
        if (startDate && issue.created_at < new Date(startDate)) return false;
        if (endDate && issue.created_at > new Date(endDate)) return false;
        
        // Calendar month filter
        if (calendarMonth) {
            let matchesMonth = false;
            
            // Check if created_at matches the selected month
            if (issue.created_at) {
                const createdMonthKey = `${issue.created_at.getFullYear()}-${String(issue.created_at.getMonth() + 1).padStart(2, '0')}`;
                if (createdMonthKey === calendarMonth) {
                    matchesMonth = true;
                }
            }
            
            // Check if start_date/end_date range overlaps with the selected month
            if (!matchesMonth && issue.start_date && issue.end_date) {
                const [selectedYear, selectedMonth] = calendarMonth.split('-').map(Number);
                const selectedMonthStart = new Date(selectedYear, selectedMonth - 1, 1);
                const selectedMonthEnd = new Date(selectedYear, selectedMonth, 0); // Last day of the month
                
                const issueStart = new Date(issue.start_date);
                const issueEnd = new Date(issue.end_date);
                
                // Check if issue date range overlaps with selected month
                if (issueStart <= selectedMonthEnd && issueEnd >= selectedMonthStart) {
                    matchesMonth = true;
                }
            }
            
            if (!matchesMonth) return false;
        }
        
        return true;
    });
    
    // Re-render with filtered data
    renderSummary();
    renderAnalytics();
    renderCharts();
}

function clearFilters() {
    const filters = [
        'date-preset-filter',
        'calendar-month-filter',
        'business-area-filter',
        'team-filter', 
        'environment-filter',
        'status-filter',
        'start-date-filter',
        'end-date-filter'
    ];
    
    filters.forEach(filterId => {
        const filter = document.getElementById(filterId);
        if (filter) filter.value = '';
    });
    
    filteredIssues = [...allIssues];
    renderSummary();
    renderAnalytics();
    renderCharts();
}

function exportCSV() {
    const headers = ['ID', 'Title', 'Status', 'Business Area', 'Team', 'Environment', 'Start Date', 'End Date', 'Cost'];
    const rows = filteredIssues.map(issue => [
        issue.id,
        issue.title,
        issue.status,
        normalizeBusinessArea(issue.business_area) || '',
        issue.team_name || '',
        issue.environment || '',
        issue.start_date ? formatDate(issue.start_date) : '',
        issue.end_date ? formatDate(issue.end_date) : '',
        issue.cost || ''
    ]);
    
    const csvContent = [headers, ...rows]
        .map(row => row.map(cell => `"${cell}"`).join(','))
        .join('\n');
    
    downloadFile(csvContent, 'autoshutdown-insights.csv', 'text/csv');
}

function exportJSON() {
    const jsonContent = JSON.stringify(filteredIssues, null, 2);
    downloadFile(jsonContent, 'autoshutdown-insights.json', 'application/json');
}

function exportPDF() {
    console.log('exportPDF called');
    
    // Check if html2pdf is available
    if (typeof html2pdf === 'undefined') {
        console.error('html2pdf library not loaded');
        alert('PDF export library not loaded. Please refresh the page and try again.');
        return;
    }
    
    // Show loading indicator
    const originalText = document.getElementById('export-pdf').textContent;
    document.getElementById('export-pdf').textContent = 'Generating PDF...';
    document.getElementById('export-pdf').disabled = true;
    
    // Create a container for PDF content
    const pdfContent = document.createElement('div');
    pdfContent.style.backgroundColor = 'white';
    pdfContent.style.padding = '20px';
    pdfContent.style.fontFamily = 'Arial, sans-serif';
    
    // Add title and filter info
    const title = document.createElement('h1');
    title.textContent = 'Auto-shutdown Insights Report';
    title.style.textAlign = 'center';
    title.style.marginBottom = '20px';
    title.style.color = '#1f2937';
    pdfContent.appendChild(title);
    
    // Add filter summary
    const filterSummary = createFilterSummary();
    pdfContent.appendChild(filterSummary);
    
    // Clone and add summary section
    const summarySection = document.querySelector('.summary-section');
    if (summarySection) {
        const summaryClone = summarySection.cloneNode(true);
        const summaryTitle = document.createElement('h2');
        summaryTitle.textContent = 'Summary Statistics';
        summaryTitle.style.marginTop = '30px';
        summaryTitle.style.marginBottom = '15px';
        summaryTitle.style.color = '#1f2937';
        pdfContent.appendChild(summaryTitle);
        pdfContent.appendChild(summaryClone);
    }
    
    // Clone and add analytics section
    const analyticsSection = document.querySelector('.analytics-section');
    if (analyticsSection) {
        const analyticsClone = analyticsSection.cloneNode(true);
        const analyticsTitle = document.createElement('h2');
        analyticsTitle.textContent = 'Detailed Analytics';
        analyticsTitle.style.marginTop = '30px';
        analyticsTitle.style.marginBottom = '15px';
        analyticsTitle.style.color = '#1f2937';
        pdfContent.appendChild(analyticsTitle);
        pdfContent.appendChild(analyticsClone);
    }
    
    // Add charts as images
    addChartsToPDF(pdfContent).then(() => {
        console.log('Charts added successfully, starting PDF generation');
        
        // Configure PDF options
        const opt = {
            margin: 1,
            filename: 'autoshutdown-insights-report.pdf',
            image: { type: 'jpeg', quality: 0.98 },
            html2canvas: { 
                scale: 2,
                useCORS: true,
                backgroundColor: '#ffffff'
            },
            jsPDF: { 
                unit: 'in', 
                format: 'letter', 
                orientation: 'portrait' 
            }
        };
        
        console.log('Starting html2pdf generation');
        
        // Generate PDF
        html2pdf().from(pdfContent).set(opt).save().then(() => {
            console.log('PDF generation completed successfully');
            // Reset button state
            document.getElementById('export-pdf').textContent = originalText;
            document.getElementById('export-pdf').disabled = false;
        }).catch((error) => {
            console.error('Error generating PDF:', error);
            document.getElementById('export-pdf').textContent = originalText;
            document.getElementById('export-pdf').disabled = false;
            alert('Error generating PDF. Please try again.');
        });
    }).catch((error) => {
        console.error('Error adding charts to PDF:', error);
        document.getElementById('export-pdf').textContent = originalText;
        document.getElementById('export-pdf').disabled = false;
        alert('Error preparing PDF content. Please try again.');
    });
}

function createFilterSummary() {
    const filterDiv = document.createElement('div');
    filterDiv.style.marginBottom = '20px';
    filterDiv.style.padding = '15px';
    filterDiv.style.backgroundColor = '#f8fafc';
    filterDiv.style.borderRadius = '8px';
    filterDiv.style.border = '1px solid #e5e7eb';
    
    const filterTitle = document.createElement('h3');
    filterTitle.textContent = 'Applied Filters';
    filterTitle.style.marginTop = '0';
    filterTitle.style.marginBottom = '10px';
    filterTitle.style.color = '#1f2937';
    filterDiv.appendChild(filterTitle);
    
    const filters = [
        { id: 'date-preset-filter', label: 'Date Preset' },
        { id: 'calendar-month-filter', label: 'Calendar Month' },
        { id: 'business-area-filter', label: 'Business Area' },
        { id: 'team-filter', label: 'Team' },
        { id: 'environment-filter', label: 'Environment' },
        { id: 'status-filter', label: 'Status' },
        { id: 'start-date-filter', label: 'Start Date' },
        { id: 'end-date-filter', label: 'End Date' }
    ];
    
    const activeFilters = filters.filter(filter => {
        const element = document.getElementById(filter.id);
        return element && element.value && element.value.trim() !== '';
    });
    
    if (activeFilters.length > 0) {
        activeFilters.forEach(filter => {
            const element = document.getElementById(filter.id);
            const filterInfo = document.createElement('p');
            filterInfo.style.margin = '5px 0';
            filterInfo.style.color = '#374151';
            
            // Special handling for calendar month filter to show readable label
            let displayValue = element.value;
            if (filter.id === 'calendar-month-filter' && element.value) {
                const selectedOption = element.querySelector(`option[value="${element.value}"]`);
                if (selectedOption) {
                    displayValue = selectedOption.textContent;
                }
            }
            
            filterInfo.innerHTML = `<strong>${filter.label}:</strong> ${displayValue}`;
            filterDiv.appendChild(filterInfo);
        });
    } else {
        const noFilters = document.createElement('p');
        noFilters.textContent = 'No filters applied - showing all data';
        noFilters.style.color = '#6b7280';
        noFilters.style.fontStyle = 'italic';
        filterDiv.appendChild(noFilters);
    }
    
    const totalResults = document.createElement('p');
    totalResults.style.marginTop = '10px';
    totalResults.style.fontWeight = 'bold';
    totalResults.style.color = '#1f2937';
    totalResults.innerHTML = `<strong>Total Results:</strong> ${filteredIssues.length} requests`;
    filterDiv.appendChild(totalResults);
    
    return filterDiv;
}

async function addChartsToPDF(container) {
    console.log('addChartsToPDF called');
    
    const chartsTitle = document.createElement('h2');
    chartsTitle.textContent = 'Charts & Visualizations';
    chartsTitle.style.marginTop = '30px';
    chartsTitle.style.marginBottom = '15px';
    chartsTitle.style.color = '#1f2937';
    container.appendChild(chartsTitle);
    
    const chartContainers = document.querySelectorAll('.chart-container');
    console.log('Found chart containers:', chartContainers.length);
    
    const chartsGrid = document.createElement('div');
    chartsGrid.style.display = 'grid';
    chartsGrid.style.gridTemplateColumns = '1fr 1fr';
    chartsGrid.style.gap = '20px';
    chartsGrid.style.marginBottom = '20px';
    
    for (const chartContainer of chartContainers) {
        const canvas = chartContainer.querySelector('canvas');
        const title = chartContainer.querySelector('h3');
        
        if (canvas && title) {
            console.log('Processing chart:', title.textContent);
            
            const chartDiv = document.createElement('div');
            chartDiv.style.textAlign = 'center';
            chartDiv.style.padding = '15px';
            chartDiv.style.border = '1px solid #e5e7eb';
            chartDiv.style.borderRadius = '8px';
            chartDiv.style.backgroundColor = '#ffffff';
            
            const chartTitle = document.createElement('h4');
            chartTitle.textContent = title.textContent;
            chartTitle.style.marginTop = '0';
            chartTitle.style.marginBottom = '10px';
            chartTitle.style.color = '#1f2937';
            chartDiv.appendChild(chartTitle);
            
            try {
                const img = document.createElement('img');
                img.src = canvas.toDataURL('image/png');
                img.style.maxWidth = '100%';
                img.style.height = 'auto';
                chartDiv.appendChild(img);
                console.log('Chart image created successfully');
            } catch (error) {
                console.error('Error creating chart image:', error);
                // Add fallback text if chart image fails
                const fallbackText = document.createElement('p');
                fallbackText.textContent = 'Chart could not be exported';
                fallbackText.style.color = '#6b7280';
                chartDiv.appendChild(fallbackText);
            }
            
            chartsGrid.appendChild(chartDiv);
        }
    }
    
    container.appendChild(chartsGrid);
    console.log('Charts added to PDF container');
    
    // Return a resolved promise since we don't have any actual async operations
    return Promise.resolve();
}

function downloadFile(content, filename, mimeType) {
    const blob = new Blob([content], { type: mimeType });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
}

function showEnvironmentDetails(environment, count) {
    const requests = filteredIssues.filter(issue => (issue.environment || 'Unknown') === environment);
    
    let details = `<h3>Environment: ${environment}</h3>`;
    details += `<p><strong>Total Requests:</strong> ${count}</p>`;
    details += '<div class="request-list">';
    
    requests.forEach(request => {
        details += `<div class="request-item">
            <strong><a href="${request.html_url}" target="_blank" rel="noopener noreferrer" style="color: #3b82f6; text-decoration: none;">${request.title}</a></strong> - ${request.status}
            ${request.cost ? ` (${request.cost})` : ''}
            <br><small>Team: ${request.team_name || 'Unknown'}</small>
        </div>`;
    });
    
    details += '</div>';
    showModal('Environment Details', details);
}

function showStatusDetails(status, count) {
    const requests = filteredIssues.filter(issue => issue.status === status);
    
    let details = `<h3>Status: ${status.charAt(0).toUpperCase() + status.slice(1)}</h3>`;
    details += `<p><strong>Total Requests:</strong> ${count}</p>`;
    details += '<div class="request-list">';
    
    requests.forEach(request => {
        details += `<div class="request-item">
            <strong><a href="${request.html_url}" target="_blank" rel="noopener noreferrer" style="color: #3b82f6; text-decoration: none;">${request.title}</a></strong>
            ${request.cost ? ` (${request.cost})` : ''}
            <br><small>Team: ${request.team_name || 'Unknown'} - Environment: ${request.environment || 'Unknown'}</small>
        </div>`;
    });
    
    details += '</div>';
    showModal('Status Details', details);
}

function showCostRangeDetails(range, count) {
    const requests = filteredIssues.filter(issue => {
        if (!issue.cost) return false;
        const costMatch = issue.cost.match(/£?([\d,]+\.?\d*)/);
        if (!costMatch) return false;
        const cost = parseFloat(costMatch[1].replace(',', ''));
        return cost > range.min && cost <= range.max;
    });
    
    let details = `<h3>Cost Range: ${range.label}</h3>`;
    details += `<p><strong>Total Requests:</strong> ${count}</p>`;
    details += '<div class="request-list">';
    
    requests.forEach(request => {
        details += `<div class="request-item">
            <strong><a href="${request.html_url}" target="_blank" rel="noopener noreferrer" style="color: #3b82f6; text-decoration: none;">${request.title}</a></strong> - ${request.cost}
            <br><small>Team: ${request.team_name || 'Unknown'} - Environment: ${request.environment || 'Unknown'}</small>
        </div>`;
    });
    
    details += '</div>';
    showModal('Cost Range Details', details);
}

function showModal(title, content) {
    const modal = document.getElementById('request-modal');
    const modalContent = document.getElementById('modal-content');
    const modalTitle = modal.querySelector('h2');
    
    if (modal && modalContent && modalTitle) {
        modalTitle.textContent = title;
        modalContent.innerHTML = content;
        modal.classList.remove('hidden');
        
        // Close modal on close button click
        const closeBtn = modal.querySelector('.close');
        if (closeBtn) {
            closeBtn.onclick = () => modal.classList.add('hidden');
        }
        
        // Close modal on outside click
        modal.onclick = (e) => {
            if (e.target === modal) {
                modal.classList.add('hidden');
            }
        };
    }
}