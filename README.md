# FamilyTrack Pro

A secure, mobile-friendly family location sharing app built with vanilla HTML, CSS, and JavaScript.

## Features

- Real-time GPS location sharing with consent enforcement
- SOS emergency alerts to all family members
- Safe zones with enter/exit notifications
- Location history log (last 30 entries)
- Battery level monitoring
- Brute-force login protection (locks after 5 attempts)
- Auto session timeout (30 minutes)
- Full audit log of all actions
- Change family code anytime
- 100% client-side — no server, no database, no data collection

## How to use

1. Open `index.html` in any browser
2. Enter your name and the family code
3. Consent to location sharing
4. Start sharing your location with family

## Default login

- Family code: `family123`
- Change it in the **Security** tab after logging in

## Deployment

Works on any static hosting platform:
- Netlify (drag and drop)
- GitHub Pages
- Vercel
- Tiiny.host

## Privacy

All data stays on your device. Nothing is sent to any server.

## Tech stack

- HTML5 Geolocation API
- Battery Status API
- Vanilla JavaScript
- Google Fonts (Syne + Inter)
