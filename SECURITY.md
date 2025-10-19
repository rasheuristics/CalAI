# CalAI Security Guide

## API Key Management

CalAI uses iOS Keychain for secure storage of all API keys and sensitive credentials. This document explains how API keys are managed and how to configure them.

### Supported API Keys

1. **Anthropic API Key** (for Claude AI)
2. **OpenAI API Key** (for GPT models)
3. **OpenWeatherMap API Key** (for weather data)

### Security Features

✅ **All API keys are stored in iOS Keychain** - not in UserDefaults or plain text files
✅ **Automatic migration** - legacy keys in UserDefaults are automatically migrated to Keychain
✅ **No hardcoded secrets** - removed all hardcoded API keys from source code
✅ **Secure deletion** - keys are properly removed from Keychain when deleted

### How to Configure API Keys

#### Option 1: Through the App Settings (Recommended)

1. Open CalAI app
2. Go to **Settings** tab
3. Scroll to **AI Configuration** section
4. Enter your API keys:
   - Anthropic API Key: Get from [console.anthropic.com](https://console.anthropic.com)
   - OpenAI API Key: Get from [platform.openai.com](https://platform.openai.com)
5. Go to **Morning Briefing Settings** to configure weather
6. Enter OpenWeatherMap API Key: Get free from [openweathermap.org](https://openweathermap.org)

#### Option 2: Programmatic Configuration (For Development)

```swift
import Foundation

// Configure API keys via Config class
Config.anthropicAPIKey = "sk-ant-your-key-here"
Config.openaiAPIKey = "sk-your-openai-key-here"

// Configure weather API key
WeatherService.shared.apiKey = "your-openweather-key-here"
```

### API Key Storage Details

All keys are stored in iOS Keychain with these attributes:
- **Service**: `com.calai.apikeys`
- **Access**: `kSecAttrAccessibleAfterFirstUnlock`
- **Synchronizable**: No (keys stay on device only)

### Migration from Previous Versions

If you're upgrading from an older version:

1. **Automatic Migration**: Keys stored in UserDefaults are automatically migrated to Keychain on first launch
2. **Migration Status**: Check console logs for migration confirmation
3. **Verification**: Old keys are deleted from UserDefaults after successful migration

### Security Best Practices

#### For Users:
- ✅ Never share your API keys with others
- ✅ Rotate your API keys periodically
- ✅ Use API keys with minimum required permissions
- ✅ Monitor your API usage on provider dashboards
- ⚠️ If you suspect your key is compromised, revoke it immediately

#### For Developers:
- ✅ Never commit API keys to version control
- ✅ Use `.gitignore` to exclude sensitive files
- ✅ Always use SecureStorage for credential storage
- ✅ Test with demo/test API keys, not production keys
- ⚠️ Never hardcode API keys in source code

### Files That Should Never Be Committed

The following files are excluded via `.gitignore`:

```
Config.secret.swift
Secrets.swift
*.secret.swift
.env
.env.*
GoogleService-Info.plist.secret
Info.plist.secret
```

### OpenWeatherMap API Key

**Note**: The hardcoded demo key has been removed. Users must now:

1. Get a free API key from [openweathermap.org/api](https://openweathermap.org/api)
2. Enter it in **Settings > Morning Briefing Settings**
3. The key is automatically stored in Keychain

### Troubleshooting

#### "API Key Not Found" Error

If you see this error:
1. Open **Settings** tab
2. Re-enter your API key
3. Restart the app

#### "Invalid API Key Format" Error

- **Anthropic**: Keys should start with `sk-ant-`
- **OpenAI**: Keys should start with `sk-`
- **OpenWeather**: Keys should be 32 hexadecimal characters

#### Migration Issues

If automatic migration fails:
1. Note your API keys from Settings
2. Delete and reinstall the app
3. Re-enter your API keys manually

### Code Reference

**SecureStorage Implementation**: `CalAI/Utilities/SecureStorage.swift`
**API Key Configuration**: `CalAI/Config.swift`
**Weather API Management**: `CalAI/Features/MorningBriefing/WeatherService.swift`

### Reporting Security Issues

If you discover a security vulnerability:
1. **DO NOT** create a public GitHub issue
2. Email security concerns to: [your-email@domain.com]
3. Include detailed steps to reproduce
4. Allow time for patch before public disclosure

---

**Last Updated**: 2025-10-19
**Version**: 1.0.0
