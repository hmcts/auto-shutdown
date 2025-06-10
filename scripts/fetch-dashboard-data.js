#!/usr/bin/env node

/**
 * Dashboard Data Fetcher
 * 
 * This script fetches GitHub Issues data for the auto-shutdown exclusion dashboard
 * and caches it to avoid API rate limits on the frontend.
 * 
 * Runs daily via GitHub Actions workflow to keep data fresh.
 */

const fs = require('fs').promises;
const path = require('path');

// Configuration
const CONFIG = {
    GITHUB_API_BASE: 'https://api.github.com',
    REPO_OWNER: 'hmcts',
    REPO_NAME: 'auto-shutdown-dev',
    ISSUES_PER_PAGE: 100,
    ISSUES_TO_SHOW: 50,
    OUTPUT_FILE: path.join(__dirname, '..', 'docs', 'dashboard_data.json')
};

/**
 * Fetch issues from GitHub API
 */
async function fetchIssuesFromGitHub() {
    const url = `${CONFIG.GITHUB_API_BASE}/repos/${CONFIG.REPO_OWNER}/${CONFIG.REPO_NAME}/issues`;
    const params = new URLSearchParams({
        state: 'all',
        per_page: CONFIG.ISSUES_PER_PAGE,
        sort: 'created',
        direction: 'desc'
    });

    const headers = {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'AutoShutdown-Dashboard-Fetcher'
    };

    // Add GitHub token if available (for higher rate limits)
    if (process.env.GITHUB_TOKEN) {
        headers['Authorization'] = `token ${process.env.GITHUB_TOKEN}`;
    }

    console.log('Fetching issues from GitHub API...');
    const response = await fetch(`${url}?${params}`, { headers });
    
    if (!response.ok) {
        let errorMessage = `GitHub API error: ${response.status}`;
        if (response.status === 403) {
            errorMessage += ' - Rate limit exceeded';
        } else if (response.status === 404) {
            errorMessage += ' - Repository not found or not accessible';
        }
        throw new Error(errorMessage);
    }

    const issues = await response.json();
    console.log(`Fetched ${issues.length} issues from GitHub`);
    
    // Filter for autoshutdown exclusion requests
    const filteredByType = issues.filter(issue => 
        issue.title && 
        (issue.title.toLowerCase().includes('auto shutdown') || 
         issue.title.toLowerCase().includes('autoshutdown') ||
         issue.title.toLowerCase().includes('exclusion') ||
         issue.labels.some(label => 
            label.name.includes('auto-approved') || 
            label.name.includes('approved') ||
            label.name.includes('pending')
         ))
    );

    console.log(`Found ${filteredByType.length} autoshutdown exclusion issues`);

    // Take only the last 50 matching issues (most recent first)
    const last50Issues = filteredByType.slice(0, CONFIG.ISSUES_TO_SHOW);

    // Transform issue data and fetch cost information
    const transformedIssues = await Promise.all(last50Issues.map(async (issue) => {
        const transformedIssue = transformIssueData(issue);
        transformedIssue.cost = await extractCostFromComments(issue.number);
        return transformedIssue;
    }));

    return transformedIssues;
}

/**
 * Extract cost information from issue comments
 */
async function extractCostFromComments(issueNumber) {
    try {
        const url = `${CONFIG.GITHUB_API_BASE}/repos/${CONFIG.REPO_OWNER}/${CONFIG.REPO_NAME}/issues/${issueNumber}/comments`;
        
        const headers = {
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'AutoShutdown-Dashboard-Fetcher'
        };

        if (process.env.GITHUB_TOKEN) {
            headers['Authorization'] = `token ${process.env.GITHUB_TOKEN}`;
        }

        const response = await fetch(url, { headers });
        
        if (!response.ok) {
            console.warn(`Failed to fetch comments for issue ${issueNumber}: ${response.status}`);
            return null;
        }

        const comments = await response.json();
        
        // Look for cost information in comments
        for (const comment of comments) {
            const body = comment.body.toLowerCase();
            
            // Look for cost patterns
            const costPatterns = [
                /cost[:\s]*£([\d,]+\.?\d*)/i,
                /£([\d,]+\.?\d*)/i,
                /\$([\d,]+\.?\d*)/i,
                /estimated[:\s]*£([\d,]+\.?\d*)/i
            ];
            
            for (const pattern of costPatterns) {
                const match = comment.body.match(pattern);
                if (match) {
                    return `£${match[1]}`;
                }
            }
        }
        
        return null;
    } catch (error) {
        console.warn(`Error fetching cost for issue ${issueNumber}:`, error.message);
        return null;
    }
}

/**
 * Transform GitHub issue data to dashboard format
 */
function transformIssueData(issue) {
    const labels = issue.labels.map(l => l.name);
    
    // Determine status from labels
    let status = 'pending';
    if (labels.includes('auto-approved')) status = 'auto-approved';
    else if (labels.includes('approved')) status = 'approved';
    else if (labels.includes('denied')) status = 'denied';
    else if (labels.includes('cancel') || issue.title.toLowerCase().includes('cancel')) status = 'cancelled';
    
    // Extract data from issue body
    const body = issue.body || '';
    const extractField = (field) => {
        const regex = new RegExp(`${field}[:\\s]*(.*?)(?:\\n|$)`, 'i');
        const match = body.match(regex);
        return match ? match[1].trim() : '';
    };

    return {
        id: issue.number,
        title: issue.title,
        status: status,
        created_at: new Date(issue.created_at),
        updated_at: new Date(issue.updated_at),
        html_url: issue.html_url,
        user: issue.user.login,
        labels: labels,
        business_area: extractField('Business area') || extractField('business_area'),
        team_name: extractField('Team/Application Name') || extractField('team_name'),
        environment: extractField('Environment') || extractField('environment'),
        start_date: parseDate(extractField('Skip shutdown start date') || extractField('start_date')),
        end_date: parseDate(extractField('Skip shutdown end date') || extractField('end_date')),
        justification: extractField('Justification for exclusion') || extractField('justification'),
        change_jira_id: extractField('Change or Jira reference') || extractField('change_jira_id'),
        stay_on_late: extractField('Do you need this exclusion past 11pm') || extractField('stay_on_late'),
        body: body
    };
}

/**
 * Parse date string in various formats
 */
function parseDate(dateString) {
    if (!dateString) return null;
    
    // Try multiple date formats
    const formats = [
        /(\d{1,2})-(\d{1,2})-(\d{4})/,  // DD-MM-YYYY
        /(\d{4})-(\d{1,2})-(\d{1,2})/,  // YYYY-MM-DD
        /(\d{1,2})\/(\d{1,2})\/(\d{4})/  // DD/MM/YYYY
    ];
    
    for (let format of formats) {
        const match = dateString.match(format);
        if (match) {
            if (format === formats[0] || format === formats[2]) {
                // DD-MM-YYYY or DD/MM/YYYY
                return new Date(match[3], match[2] - 1, match[1]);
            } else {
                // YYYY-MM-DD
                return new Date(match[1], match[2] - 1, match[3]);
            }
        }
    }
    
    // Fallback to standard parsing
    const date = new Date(dateString);
    return isNaN(date.getTime()) ? null : date;
}

/**
 * Main execution function
 */
async function main() {
    try {
        console.log('Starting dashboard data fetch...');
        
        // Fetch and transform issues data
        const dashboardData = await fetchIssuesFromGitHub();
        
        // Prepare output data with metadata
        const output = {
            last_updated: new Date().toISOString(),
            total_issues: dashboardData.length,
            data: dashboardData
        };
        
        // Write to cache file
        await fs.writeFile(CONFIG.OUTPUT_FILE, JSON.stringify(output, null, 2));
        console.log(`Dashboard data cached successfully to ${CONFIG.OUTPUT_FILE}`);
        console.log(`Cached ${dashboardData.length} issues`);
        
    } catch (error) {
        console.error('Error fetching dashboard data:', error);
        process.exit(1);
    }
}

// Run if called directly
if (require.main === module) {
    main();
}

module.exports = { main };
