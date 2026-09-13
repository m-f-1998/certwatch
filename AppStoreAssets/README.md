# App Store screenshots & previews

## Required sizes (App Store Connect)

| Slot | Screenshots (PNG) | App preview (MP4) |
|------|-------------------|-------------------|
| **iPhone 6.5"** | **1242 × 2688** | **886 × 1920** |
| **iPad 13"** | **2064 × 2752** | **1200 × 1600** |

Screenshots and previews use **different** dimensions — do not upload PNG-sized videos.

CertWatch is portrait-only. Previews must be **15–30 seconds**, H.264, max 30 fps.

Up to **10 screenshots** and **3 app preview videos** per device size.

## Generate assets

```bash
chmod +x Scripts/capture-app-store-screenshots.sh
./Scripts/capture-app-store-screenshots.sh
```

### Output

| Folder | Screenshots | Preview video |
|--------|-------------|---------------|
| `AppStoreAssets/iPhone-6.5/` | 1242×2688 PNGs | 886×1920 `iphone-preview.mp4` |
| `AppStoreAssets/iPad-13/` | 2064×2752 PNGs | 1200×1600 `ipad-preview.mp4` |

Screenshots captured:

1. **dashboard** — Pro dashboard with tags and expiry cards  
2. **detail** — Certificate detail with countdown dial  
3. **settings** — Custom notification thresholds  

### Preview videos

Preview videos are built from the three screenshots (5s each, 15s total) at the **preview** dimensions above — not the screenshot dimensions. Requires `ffmpeg` (`brew install ffmpeg`).

Simulator screen recording is unreliable on some Xcode versions; the slideshow approach matches Apple's 15–30s requirement.

### Custom simulators

```bash
IPHONE_SIMULATOR="iPhone 17 Pro Max" IPAD_SIMULATOR="iPad Pro 13-inch (M5)" ./Scripts/capture-app-store-screenshots.sh
```

Any modern simulator works — PNGs and videos are resized to the exact App Store pixel dimensions.

## Suggested upload order

1. Dashboard  
2. Detail  
3. Settings  

Add captions in App Store Connect (not baked into PNGs).
