# Original İlaç Vakti app mark

Deep teal `#006B60` matches the application theme. An off-white diagonal capsule and a warm amber clock identify user-entered medication schedules without text or medical claims. Flat shapes and generous margins remain legible at small sizes. Artwork and background are fully opaque; output uses RGB24 PNG without an alpha channel. No borrowed brand artwork or Flutter mark is used.

Run from the selected app root:

```powershell
flutter test --no-pub tool/make_icons.dart
```

This checks drawing opacity, native PNG decoding and dimensions in memory; it writes no icons. After active builds have ended, generate:

```powershell
flutter test --no-pub --dart-define=WRITE_ICONS=true tool/make_icons.dart
```

The generator replaces only the existing Android launcher PNGs (48, 72, 96, 144 and 192 pixels) and the filenames/square sizes in the existing iOS AppIcon `Contents.json` (20–1024 pixels, including the 1024 marketing icon). It adds no package dependency or asset-catalog configuration. Inspect the generated 1024 image and small Android icon, then rebuild both platforms; source code and a passing decoder test alone are not visual acceptance.

## Generated evidence — 2026-10-11

Actual generation command passed after native build cleanup: 20 PNG files (5 Android, 15 distinct iOS filenames). All headers are 8-bit RGB color type 2 with square expected dimensions. Generator checks full drawing opacity and decodes every distinct size through Flutter. The 1024 and 48 pixel results were visually inspected: capsule divider and clock hands remain readable, with generous teal margins and no Flutter mark. This is asset acceptance, not rebuilt app/device acceptance.

| Output | Pixels | SHA-256 |
|---|---:|---|
| `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` | 72 | `f09e2488e1feccd74d20d2f6626d83559a808a8c26d97d3acb5c19edd3cc22b8` |
| `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` | 48 | `59ced1f30041cb95e77ce01f2875290a178a09bc905dad6bb28d5af935a109e2` |
| `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` | 96 | `8bba0fd47c0e1729bba0021c3a65064b477de2fa8c9e06eedb6d94c2698d9a31` |
| `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` | 144 | `6e535440212c580ee3bb0ed8724541d5e8793e4f2ebc8d770363a9f9b37f76ae` |
| `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` | 192 | `9f7545938b2475f278fa313d5ca1e10b8a26d2ffe0bc49e3a67ce9b8e924d3bd` |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` | 1024 | `e2211092371d31b17d0f7f2f7c51c6d23b59b9c7c43ed3f39ee8c8bf8d4cef96` |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png` | 20 | `c99aa836c79628f30c22e77cd4de88ce438225b3542a91f8ab6ba5f69f189d89` |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png` | 40 | `964aa560a37fe4130e8186167fe8b395673aae08f2f484c2dc735ef027ba00a3` |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png` | 60 | `902ed62fdb20f6f27de003e2368160b542d046b7e133881e14fae3c5019a0214` |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png` | 29 | `28d0c24ed7d3bf890450133a8ef8f24e0279c86834dad6d113790e730ee2587a` |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png` | 58 | `c7f89d5251da4e288813f762c9ac6a391446ef3f7f5e75dfee68e2bf51e2ad60` |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png` | 87 | `931482aba02fb65247e9b6b5f6be76f064201450a8a4ecd2da32169e49c53ab7` |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png` | 40 | `964aa560a37fe4130e8186167fe8b395673aae08f2f484c2dc735ef027ba00a3` |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png` | 80 | `35121500f8118d36abdc81e6b3273f8c5cff8ed2bda40734f25ba6653bed1224` |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png` | 120 | `5ebd4e7d3173ee81106821d2d764478aedafeb4472b986d9c9b14936d27e8bbf` |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png` | 120 | `5ebd4e7d3173ee81106821d2d764478aedafeb4472b986d9c9b14936d27e8bbf` |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png` | 180 | `e5c288191a73e331adbbf9451a44ea5688d97d0bdbd5c80ab7561fe08ff2b211` |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png` | 76 | `10a74818b97767cb894a2d7106eb06cba587ed43105527bb3d1b6f89e638824a` |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png` | 152 | `4ff37692af4ba42f2c059c29d20d145fc9847d9716651a013531752b248d2e90` |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png` | 167 | `26f986fe1ccdc4ab61b1b958e1764b88d8baa3634501cae2c69cb8f45e3b47e6` |
