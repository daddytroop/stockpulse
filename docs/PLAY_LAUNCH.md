# Publishing on Google Play and going live with ads

The app can be published on the Play Store as is. This is the short
version of what has to happen, and in what order.

## 1. Create an upload keystore

Do this once, on the machine that will publish the app, and keep the file
somewhere safe. Losing it means you cannot update the app.

```bash
keytool -genkey -v -keystore ~/stockpulse-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## 2. Give CI the keystore (optional but recommended)

Add these as **repository secrets** (Settings → Secrets and variables →
Actions):

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | `base64 -w0 ~/stockpulse-upload.jks` |
| `STORE_PASSWORD` | the keystore password |
| `KEY_ALIAS` | `upload` |
| `KEY_PASSWORD` | the key password |
| `ADS_LIVE` | `false` for now, `true` once AdMob approves the app |

With those set, every tagged build also produces a **signed app bundle**
(`app-release.aab`), attached to the GitHub release next to the APK. Without
them, the build still works and the APK stays debug-signed and sideloadable.

To build a bundle locally instead, copy
`platform_overlay/android/key.properties.example` to `android/key.properties`
after running `scripts/setup_platforms`, fill it in, and run:

```bash
flutter build appbundle --release
```

## 3. Create the Play Console listing

- Create the app in the Play Console with package name `app.stockpulse`.
- A **closed testing** track is enough for AdMob to review the app. Upload
  the `.aab` from the GitHub release to that track and roll it out.
- Fill in the store listing: title, description, screenshots, icon.
- Add a **privacy policy URL**. AdMob will not serve ads without one.
- Set the **developer website** to a domain you control. AdMob reads
  `app-ads.txt` from that domain, at the root:
  `https://yourdomain.com/app-ads.txt`.

### app-ads.txt

The repository already contains the file:

```
google.com, pub-2085007206942111, DIRECT, f08c47fec0942fa0
```

The web build publishes it at its root as well, so hosting the web artifact
on a domain (or enabling GitHub Pages for this repository) gives you a
ready-made URL for the Play listing's website field.

## 4. Link the app in AdMob

In the AdMob console, open **Apps → Stock Pulse (Android) → Add store**
and pick the Play listing. AdMob then reviews the app; this usually takes a
few days. Until it is approved, the app shows "Limited ad serving".

## 5. Turn on live ads

Until the review is done, keep `ADS_LIVE` set to `false`: the build then
serves Google's **test ads**, which is what AdMob asks for while an app is
under review, and it means an accidental click on your own ad cannot flag
the account.

When AdMob approves the app:

1. Set the `ADS_LIVE` secret to `true`.
2. Tag a new version (`git tag v1.5.4 && git push origin v1.5.4`).
3. The new build serves live ads.

You can also build a live-ads APK yourself at any time:

```bash
flutter build apk --release --dart-define=ADS_LIVE=true
```

## 6. Check the placement report

After a few days of real use, open **Settings → Advertising** in the app.
The report shows impressions, clicks and estimated revenue per placement,
taken from the ad SDK's own paid-event reporting. Use it to decide which
placements deserve a dedicated ad unit - AdMob's own dashboard cannot
separate placements that share one ad unit.
