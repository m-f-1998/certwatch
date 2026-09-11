# CertWatch

Local-first SSL/TLS certificate expiry tracker for iOS. Monitor domains, inspect certificate chains, get local alerts, and view status on Home Screen widgets.

Built with Swift 6, SwiftUI, SwiftData, WidgetKit, StoreKit 2, and Network.framework.

## Features

### Base app
- Monitor up to **5 endpoints**
- Live TLS certificate inspection
- Expiry dashboard with status badges and validity progress
- Certificate detail inspector with SANs, chain, and PEM copy/share
- Manual refresh (single + pull-to-all)
- One notification threshold (30 days)
- Terminal Precision dark UI

### Pro (one-time IAP)
- Unlimited endpoints
- Custom alert thresholds
- Home Screen widgets (small + medium)
- Daily background refresh
- Tags, notes, export/import

## Requirements

- Xcode 16+
- iOS 17.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Setup

```bash
xcodegen generate
open CertWatch.xcodeproj
```

For StoreKit testing, select **Configuration/CertWatch.storekit** under Product → Scheme → Edit Scheme → Run → Options.

Register products and App Groups in Apple Developer before release:
- App ID: `com.mfrankland.certwatch`
- Widget: `com.mfrankland.certwatch.widget`
- App Group: `group.com.matthewfrankland.certwatch`
- IAP: `com.mfrankland.certwatch.pro`

## Tests

```bash
xcodegen generate
xcodebuild test -scheme CertWatch -destination 'platform=iOS Simulator,name=iPhone 17'
```

110+ unit tests cover hostname parsing, expiry logic, notifications, export/import, and model behaviour.

## Project structure

| Path | Purpose |
|------|---------|
| `App/` | SwiftUI app, features, assets |
| `Shared/` | Models, services, design system |
| `Widget/` | WidgetKit extension |
| `CertWatchTests/` | Unit tests |
| `Configuration/` | StoreKit test config |
| `project.yml` | XcodeGen spec |

Data is stored locally via SwiftData in an App Group container.

## App Store checklist

- [x] Configure signing for app + widget targets
- [x] Enable App Group on both App IDs
- [x] Add app icon
- [x] Support and privacy URLs (`https://matthewfrankland.co.uk/certwatch`)
- [ ] Attach StoreKit product in App Store Connect
- [ ] Add App Review note explaining local network usage for TLS inspection

## Privacy

CertWatch does not operate a backend. Network requests are only made to hostnames you enter when you run a check or refresh. Saved data stays on your device.

## App icon concept

Shield outline with a circular countdown ring at 10 o'clock — mint green on deep charcoal. Avoid generic padlock clipart.

## License

Copyright © Matthew Frankland. All rights reserved.
