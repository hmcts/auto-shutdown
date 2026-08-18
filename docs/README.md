# Autoshutdown Exclusion Dashboard

This directory contains the source files for the GitHub Pages site that displays the visual dashboard for autoshutdown exclusion requests.

## Pages

- `index.html` - Overview page with calendar and recent requests
- `insights.html` - Insights page with statistics, charts, and filters

## Files

- `styles.css` - Styling for all pages
- `shared.js` - Shared functionality across all pages (data loading, modal, field parsing)
- `overview.js` - Overview page specific functionality
- `insights.js` - Insights page specific functionality
- `dashboard_data.json` - Cached request data consumed by both pages

## Features

### Overview Page
- Calendar view showing exclusion requests over time
- Recent requests list with key details
- Quick navigation to detailed views

### Insights Page
- Advanced filtering by business area, team, environment, status, and date range
- Summary statistics and key metrics
- Interactive charts and analytics
- Data export functionality (CSV/JSON/PDF)

## Navigation

The dashboard features a responsive navigation system allowing easy movement between:
- **Overview** - Calendar and recent activity
- **Insights** - Statistics and analytics

## Testing locally

See [Testing the dashboard app locally](../README.md#testing-the-dashboard-app-locally)
in the repo root README - it's plain static files served with any local HTTP
server, using the `dashboard_data.json` already committed here.

## Setup

GitHub Pages should automatically build and deploy this site when files are committed to the `docs/` directory on the main branch.

The dashboard fetches data from the cached `dashboard_data.json` file which is updated regularly by the backend data processing system.