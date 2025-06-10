# Autoshutdown Exclusion Dashboard

This directory contains the source files for the GitHub Pages site that displays the visual dashboard for autoshutdown exclusion requests.

## Pages

- `index.html` - Overview page with calendar and recent requests
- `insights.html` - Insights page with statistics, charts, and filters  
- `reports.html` - Reports page with advanced export capabilities

## Files

- `styles.css` - Styling for all pages
- `shared.js` - Shared functionality across all pages
- `overview.js` - Overview page specific functionality
- `insights.js` - Insights page specific functionality  
- `reports.js` - Reports page specific functionality

## Features

### Overview Page
- Calendar view showing exclusion requests over time
- Recent requests list with key details
- Quick navigation to detailed views

### Insights Page  
- Advanced filtering by business area, team, environment, status, and date range
- Summary statistics and key metrics
- Interactive charts and analytics
- Data export functionality (CSV/JSON)

### Reports Page
- Advanced reporting capabilities (coming soon)
- Scheduled reports configuration
- Multiple export formats
- Executive summaries and audit trails

## Navigation

The dashboard features a responsive navigation system allowing easy movement between:
- 📅 **Overview** - Calendar and recent activity
- 📊 **Insights** - Statistics and analytics  
- 📋 **Reports** - Advanced reporting

## Setup

GitHub Pages should automatically build and deploy this site when files are committed to the `docs/` directory on the main branch.

The dashboard fetches data from the cached `dashboard_data.json` file which is updated regularly by the backend data processing system.