# Privacy Policy Hosting Guide

## ✅ Completed In-App Integration

The privacy policy is now fully integrated into the CalAI app:

1. ✅ **PrivacyPolicyView.swift** - Beautiful SwiftUI component displaying the policy
2. ✅ **Settings Integration** - "Legal & Privacy" section with:
   - In-app privacy policy viewer
   - Link to online version
   - Privacy questions email contact
3. ✅ **Onboarding Integration** - Privacy consent screen shown on first launch

## 📋 Next Step: Host Privacy Policy Online

You need to host the privacy policy at: `https://rasheuristics.com/calai/privacy`

### Option 1: GitHub Pages (Recommended - Free)

**Step 1: Create Repository**
```bash
# Create a new repo on GitHub
# Name: calai-privacy
# Public repository
```

**Step 2: Add HTML File**

Create `index.html` with the content below (see HTML Template section).

**Step 3: Enable GitHub Pages**
1. Go to repository Settings
2. Pages → Source → Deploy from branch
3. Branch: main, folder: / (root)
4. Save

**Step 4: Access URL**
- Your privacy policy will be at: `https://<your-username>.github.io/calai-privacy`
- You can set up a custom domain to redirect to `rasheuristics.com/calai/privacy`

### Option 2: Your Own Domain

**Requirements:**
- Web hosting with HTTPS
- Access to `rasheuristics.com` DNS settings

**Steps:**
1. Upload the HTML file to your web server
2. Configure it to be accessible at `/calai/privacy`
3. Ensure HTTPS is enabled (required by Apple)

---

## 📄 HTML Template for Online Privacy Policy

Save this as `index.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="CalAI Privacy Policy - Your privacy matters to us">
    <title>CalAI Privacy Policy</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
            line-height: 1.6;
            color: #333;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
        }

        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            padding: 40px;
            border-radius: 16px;
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
        }

        h1 {
            color: #667eea;
            font-size: 36px;
            margin-bottom: 10px;
        }

        h2 {
            color: #555;
            margin-top: 30px;
            margin-bottom: 15px;
            font-size: 24px;
            border-bottom: 2px solid #667eea;
            padding-bottom: 8px;
        }

        h3 {
            color: #666;
            margin-top: 20px;
            margin-bottom: 10px;
            font-size: 20px;
        }

        .last-updated {
            color: #999;
            font-size: 14px;
            margin-bottom: 30px;
        }

        .highlight {
            background: #e8f5e9;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
            border-left: 4px solid #4caf50;
        }

        .warning {
            background: #fff3e0;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
            border-left: 4px solid #ff9800;
        }

        ul {
            margin: 15px 0;
            padding-left: 30px;
        }

        li {
            margin: 8px 0;
        }

        .icon {
            display: inline-block;
            margin-right: 8px;
        }

        .contact {
            background: #f5f5f5;
            padding: 20px;
            border-radius: 8px;
            margin-top: 30px;
        }

        a {
            color: #667eea;
            text-decoration: none;
        }

        a:hover {
            text-decoration: underline;
        }

        .footer {
            text-align: center;
            margin-top: 40px;
            color: #999;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Privacy Policy for CalAI</h1>
        <p class="last-updated">Effective Date: November 10, 2025 | Last Updated: November 10, 2025</p>

        <div class="highlight">
            <h3>🔒 Key Principle: Privacy First</h3>
            <p>We minimize data collection and prioritize your privacy. Most data processing happens on your device.</p>
        </div>

        <h2>1. Calendar Data (Local Storage Only)</h2>
        <h3>What We Collect:</h3>
        <ul>
            <li>Calendar events (titles, dates, times, locations, descriptions)</li>
            <li>Event participants and attendees</li>
            <li>Calendar source information (Google Calendar, Outlook, Apple Calendar)</li>
        </ul>

        <h3>How We Use It:</h3>
        <ul>
            <li>Display your calendar within the App</li>
            <li>Provide AI-powered scheduling assistance</li>
            <li>Generate morning briefings and insights</li>
            <li>Detect scheduling conflicts</li>
        </ul>

        <div class="highlight">
            <h3>✅ Important Privacy Guarantees:</h3>
            <ul>
                <li>✅ Calendar data stays on YOUR device</li>
                <li>✅ We do NOT upload calendar events to our servers</li>
                <li>✅ We do NOT sell or share your calendar data</li>
                <li>❌ We never access calendar data without your explicit permission</li>
            </ul>
        </div>

        <h2>2. AI Processing Data (Cloud Services)</h2>
        <p>When you use AI features (voice commands, smart suggestions), we send <strong>LIMITED</strong> data to third-party AI providers:</p>

        <h3>Data Sent to AI Providers (OpenAI or Anthropic):</h3>
        <ul>
            <li>Your voice command transcript (e.g., "Schedule a meeting tomorrow at 2pm")</li>
            <li>Minimal calendar context needed to fulfill your request</li>
            <li>Example: "User has 3 events on Tuesday"</li>
        </ul>

        <h3>Data NOT Sent:</h3>
        <ul>
            <li>❌ Full calendar event details</li>
            <li>❌ Personal identifying information</li>
            <li>❌ Complete calendar contents</li>
            <li>❌ Participant names or email addresses</li>
        </ul>

        <div class="warning">
            <h3>🔧 Your Control:</h3>
            <ul>
                <li>You can disable AI features in Settings → AI Settings</li>
                <li>You can choose "Pattern-Based" mode for fully local processing</li>
                <li>You provide your own API key (we don't see it)</li>
            </ul>
        </div>

        <h2>3. Authentication Tokens (Secure Storage)</h2>
        <h3>What We Store:</h3>
        <ul>
            <li>OAuth tokens for Google Calendar access</li>
            <li>OAuth tokens for Microsoft Outlook access</li>
            <li>API keys for AI services</li>
        </ul>

        <h3>How We Protect It:</h3>
        <ul>
            <li>Stored in iOS Keychain (encrypted by iOS)</li>
            <li>Never transmitted except to authorized services</li>
            <li>Automatically deleted when you disconnect a calendar source</li>
        </ul>

        <h2>4. Weather Data (Location Services)</h2>
        <h3>What We Collect:</h3>
        <ul>
            <li>Approximate location (city level) for weather forecasts</li>
            <li>Only when you request weather information</li>
        </ul>

        <h3>How We Use It:</h3>
        <ul>
            <li>Fetch weather data from Apple WeatherKit</li>
            <li>Display weather in morning briefings</li>
            <li>Provide weather context for event planning</li>
        </ul>

        <h3>Your Control:</h3>
        <ul>
            <li>Location permission required (you grant in iOS Settings)</li>
            <li>Weather features disabled if permission denied</li>
            <li>Can be disabled in Settings → Morning Briefing</li>
        </ul>

        <h2>5. Crash and Performance Data (Optional)</h2>
        <h3>What We Collect (if crash reporting enabled):</h3>
        <ul>
            <li>Crash stack traces and error logs</li>
            <li>Device model and iOS version</li>
            <li>App version and build number</li>
            <li>Anonymous usage patterns</li>
            <li>Network connectivity status</li>
        </ul>

        <h3>What We Do NOT Collect:</h3>
        <ul>
            <li>❌ Calendar event details</li>
            <li>❌ Personal information</li>
            <li>❌ Exact location data</li>
            <li>❌ API keys or credentials</li>
        </ul>

        <div class="warning">
            <h3>🔧 Your Control:</h3>
            <ul>
                <li>Crash reporting is OPT-IN (you must enable it)</li>
                <li>Can be disabled anytime in Settings → Advanced → Crash Reporting</li>
            </ul>
        </div>

        <h2>6. Third-Party Services We Use</h2>
        <ul>
            <li><strong>Google Calendar</strong> - Sync your Google calendars</li>
            <li><strong>Microsoft Outlook</strong> - Sync your Outlook calendars</li>
            <li><strong>OpenAI</strong> - AI assistant features</li>
            <li><strong>Apple WeatherKit</strong> - Weather forecasts</li>
        </ul>

        <div class="highlight">
            <p><strong>We do NOT share data with:</strong> Advertisers, data brokers, or marketing companies.</p>
        </div>

        <h2>7. Your Rights and Choices</h2>
        <p>You have the right to:</p>
        <ul>
            <li>✅ Access your data (stored locally on your device)</li>
            <li>✅ Delete your data anytime</li>
            <li>✅ Opt-out of crash reporting</li>
            <li>✅ Opt-out of analytics</li>
            <li>✅ Revoke calendar permissions</li>
            <li>✅ Disable AI features</li>
        </ul>

        <h2>8. Data Deletion</h2>
        <p>To delete your data:</p>
        <ul>
            <li>Sign out from calendar sources in Settings</li>
            <li>Uninstall the CalAI app from your device</li>
            <li>Email us at <a href="mailto:privacy@rasheuristics.com">privacy@rasheuristics.com</a> to request deletion of any cloud data</li>
        </ul>

        <h2>9. Children's Privacy</h2>
        <p>CalAI is not intended for users under the age of 13. We do not knowingly collect data from children.</p>

        <h2>10. Changes to This Policy</h2>
        <p>We may update this privacy policy from time to time. We will notify you of any changes by updating the "Last Updated" date.</p>

        <div class="contact">
            <h2>Contact Us</h2>
            <p><strong>Questions about privacy?</strong></p>
            <p>📧 Email: <a href="mailto:privacy@rasheuristics.com">privacy@rasheuristics.com</a></p>
            <p>🌐 Website: <a href="https://rasheuristics.com">rasheuristics.com</a></p>
        </div>

        <div class="footer">
            <p>© 2025 Rasheuristics. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
```

---

## ✅ Verification Checklist

Before App Store submission, verify:

- [ ] Privacy policy hosted and accessible at public URL
- [ ] URL returns 200 OK (not 404)
- [ ] HTTPS enabled (required by Apple)
- [ ] Mobile-friendly (responsive design)
- [ ] All links work (email, contact)
- [ ] URL added to App Store Connect
- [ ] In-app links updated to match hosted URL

---

## 🔗 Update App Links

Once hosted, update these files to use your actual URL:

1. **SettingsTabView.swift** (line 789):
   ```swift
   Link(destination: URL(string: "https://rasheuristics.com/calai/privacy")!)
   ```

2. **PrivacyPolicyView.swift** (line 164):
   ```swift
   Link(destination: URL(string: "https://rasheuristics.com/calai/privacy")!)
   ```

3. **PrivacyPolicyView.swift** (line 201):
   ```swift
   ShareSheet(items: [URL(string: "https://rasheuristics.com/calai/privacy")!])
   ```

---

## 📱 App Store Connect Configuration

When submitting to App Store:

1. Go to App Store Connect
2. Select your app → App Information
3. Scroll to "Privacy Policy URL"
4. Enter: `https://rasheuristics.com/calai/privacy`
5. Save

---

## 🎯 Success!

Once hosted, your privacy policy implementation will be complete:

✅ In-app viewer (beautiful SwiftUI)
✅ Settings integration (easy access)
✅ Onboarding consent (first launch)
✅ Online hosting (App Store requirement)
✅ Email contact (user support)

**Estimated time to host:** 15-30 minutes
