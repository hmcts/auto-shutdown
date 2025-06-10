// Shared functionality across all pages
const CONFIG = {
    // Configuration moved to backend data fetcher
    // Frontend now only loads cached data
};

// Global state
let allIssues = [];
let filteredIssues = [];
let currentDate = new Date();

// Shared functions for data loading and common functionality
async function fetchIssues() {
    try {
        // Load data from cached dashboard data file
        const response = await fetch('./dashboard_data.json');
        
        if (!response.ok) {
            throw new Error(`Failed to load dashboard data: ${response.status}`);
        }
        
        const cachedData = await response.json();
        
        if (!cachedData.data || !Array.isArray(cachedData.data)) {
            throw new Error('Invalid dashboard data format');
        }
        
        // Transform and parse the cached data
        allIssues = cachedData.data.map(issue => ({
            ...issue,
            created_at: new Date(issue.created_at),
            updated_at: new Date(issue.updated_at),
            start_date: issue.start_date ? new Date(issue.start_date) : null,
            end_date: issue.end_date ? new Date(issue.end_date) : null
        }));
        
        filteredIssues = [...allIssues];
        hideLoading();
        
        if (cachedData.last_updated) {
            console.log(`Data last updated: ${cachedData.last_updated}`);
        }
        
    } catch (error) {
        console.error('Error loading dashboard data:', error);
        showError();
        
        // Show user-friendly error message
        const errorContainer = document.getElementById('error');
        if (errorContainer) {
            errorContainer.innerHTML = `
                <div style="text-align: center; padding: 40px;">
                    <h3 style="color: #ef4444; margin-bottom: 16px;">⚠️ Unable to Load Dashboard Data</h3>
                    <p style="color: #6b7280; margin-bottom: 16px;">
                        The dashboard data is currently unavailable. This could be due to:
                    </p>
                    <ul style="color: #6b7280; text-align: left; max-width: 400px; margin: 0 auto 16px auto;">
                        <li>Data not yet generated (first-time setup)</li>
                        <li>Network connectivity issues</li>
                        <li>GitHub Pages deployment in progress</li>
                    </ul>
                    <p style="color: #6b7280;">
                        The data is refreshed daily. Please try again later or contact the administrator.
                    </p>
                    <button onclick="location.reload()" style="margin-top: 16px; padding: 8px 16px; background: #3b82f6; color: white; border: none; border-radius: 4px; cursor: pointer;">
                        Refresh Page
                    </button>
                </div>
            `;
        }
    }
}

function showLoading() {
    const loading = document.getElementById('loading');
    const error = document.getElementById('error');
    if (loading) loading.classList.remove('hidden');
    if (error) error.classList.add('hidden');
}

function hideLoading() {
    const loading = document.getElementById('loading');
    if (loading) loading.classList.add('hidden');
}

function showError() {
    const loading = document.getElementById('loading');
    const error = document.getElementById('error');
    if (loading) loading.classList.add('hidden');
    if (error) error.classList.remove('hidden');
}

function parseDate(dateString) {
    if (!dateString || dateString === 'Not specified' || dateString === '_No response_') {
        return null;
    }
    
    // Handle DD/MM/YYYY format
    const ddmmyyyy = dateString.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
    if (ddmmyyyy) {
        const [, day, month, year] = ddmmyyyy;
        return new Date(year, month - 1, day);
    }
    
    // Handle other formats
    const date = new Date(dateString);
    return isNaN(date.getTime()) ? null : date;
}

function formatDate(date) {
    if (!date) return 'Not specified';
    return date.toLocaleDateString('en-GB', {
        day: '2-digit',
        month: 'short',
        year: 'numeric'
    });
}

function normalizeBusinessArea(businessArea) {
    if (!businessArea || typeof businessArea !== 'string') return '';
    
    const normalized = businessArea.trim();
    
    // Only return valid business areas, ignore malformed data
    if (normalized === 'CFT' || normalized === 'cft') return 'CFT';
    if (normalized === 'Cross-Cutting' || normalized === 'cross-cutting') return 'Cross-Cutting';
    
    // Return empty string for invalid/malformed data
    return '';
}

function parseFieldFromBody(body, fieldPattern) {
    if (!body) return null;
    
    const regex = new RegExp(`### ${fieldPattern}[\\s\\S]*?\\n\\n([^\\n#]+)`, 'i');
    const match = body.match(regex);
    
    if (match && match[1]) {
        const value = match[1].trim();
        // Filter out common non-responses
        if (value === '_No response_' || value === 'N/A' || value === '?') {
            return null;
        }
        return value;
    }
    
    return null;
}

function parseJustification(issue) {
    // Try the parsed field first, fall back to parsing from body
    if (issue.justification && issue.justification !== '?') {
        return issue.justification;
    }
    return parseFieldFromBody(issue.body, 'Justification for exclusion\\?');
}

function parseStayOnLate(issue) {
    // Try the parsed field first, fall back to parsing from body
    if (issue.stay_on_late && issue.stay_on_late !== '?') {
        return issue.stay_on_late;
    }
    return parseFieldFromBody(issue.body, 'Do you need this exclusion past 11pm\\?');
}

function showRequestDetails(request) {
    const modal = document.getElementById('request-modal');
    const modalContent = document.getElementById('modal-content');
    
    if (!modal || !modalContent) return;
    
    modalContent.innerHTML = `
        <h3>${request.title}</h3>
        <p><strong>Status:</strong> <span class="request-status ${request.status}">${request.status}</span></p>
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0;">
            <div><strong>Business Area:</strong> ${normalizeBusinessArea(request.business_area) || 'Not specified'}</div>
            <div><strong>Team:</strong> ${request.team_name || 'Not specified'}</div>
            <div><strong>Environment:</strong> ${request.environment || 'Not specified'}</div>
            <div><strong>Created:</strong> ${formatDate(request.created_at)}</div>
            <div><strong>Start Date:</strong> ${request.start_date ? formatDate(request.start_date) : 'Not specified'}</div>
            <div><strong>End Date:</strong> ${request.end_date ? formatDate(request.end_date) : 'Not specified'}</div>
            <div><strong>Stay on Late:</strong> ${parseStayOnLate(request) || 'Not specified'}</div>
            <div><strong>Change/Jira ID:</strong> ${request.change_jira_id || 'Not specified'}</div>
            ${request.cost ? `<div><strong>Estimated Cost:</strong> <span style="font-weight: 600; color: #059669;">${request.cost}</span></div>` : ''}
        </div>
        <div style="margin-top: 20px;">
            <strong>Justification:</strong>
            <p style="margin-top: 5px; padding: 10px; background: #f9fafb; border-radius: 4px;">
                ${parseJustification(request) || 'Not specified'}
            </p>
        </div>
        <div style="margin-top: 20px;">
            <a href="${request.html_url}" target="_blank" class="btn-primary" style="display: inline-block; text-decoration: none; padding: 8px 16px;">
                View on GitHub
            </a>
        </div>
    `;
    
    modal.classList.remove('hidden');
}

function closeModal() {
    const modal = document.getElementById('request-modal');
    if (modal) {
        modal.classList.add('hidden');
    }
}

// Set up modal close functionality
document.addEventListener('DOMContentLoaded', function() {
    const modal = document.getElementById('request-modal');
    if (modal) {
        const closeBtn = modal.querySelector('.close');
        if (closeBtn) {
            closeBtn.onclick = closeModal;
        }
        
        modal.onclick = function(event) {
            if (event.target === modal) {
                closeModal();
            }
        };
    }
});