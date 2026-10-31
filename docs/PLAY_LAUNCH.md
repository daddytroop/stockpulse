# Getting the app approved (Play Store + AdMob)

There are two approvals, and they are separate:

| Approval | Who does it | What it unlocks |
|---|---|---|
| **Play Store** | Google Play review (hours to days) | Being installable from the Play Store |
| **AdMob** | Google AdMob review (a few days, **after** the app is linked to a store listing) | Full ad serving instead of "Limited ad serving" |

AdMob will not review the app until it is linked to a Play listing. That is the step that everything else waits on.

---

## 1. Prepare the things both consoles ask for

### A privacy policy URL

Both consoles want a URL a person can open. The repository already contains the policy, and it is published with the web build:

- `PRIVACY.md` - the policy, also shown **inside the app** under Settings → About → Privacy policy
- `build/web/privacy.html` - the same text as a web page, written by `tools/md_to_html.js`

So: deploy the web build (GitHub Pages, Cloudflare Pages, Netlify, anything) and use

```
https://your-domain/privacy.html
```

as the privacy policy URL in both consoles. If you would rather point at the repository itself, `https://github.com/daddytroop/stockpulse/blob/main/PRIVACY.md` also works.

### app-ads.txt

Also in the repository, and also published with the web build as `build/web/app-ads.txt`. Put it at the **root** of the domain you list as the developer's website:

```
https://your-domain/app-ads.txt
```

Google's reseller ID for AdMob inventory is `f08c47fec0942fa0`, which is what the file contains.

---

## 2. Create the Play Console listing

1. **Create the app** at [play.google.com/console](https://play.google.com/console) with package name `app.stockpulse`. It must match `applicationId` in `platform_overlay/android/app/build.gradle`.
2. **Upload a signed bundle.** Tag a release (`git tag v1.5.6 && git push origin v1.5.6`) and take `app-release.aab` from the GitHub release. To get a signed bundle, add the four keystore secrets first (below).
3. **Fill in the store listing**: app name, short description, full description, screenshots (phone, and the 7-inch tablet if you have one), the 512px icon, and the feature graphic. The icon is `assets/icon/app_icon.png`.
4. **App content** - the forms that must be filled in before the first review:

| Form | What to answer |
|---|---|
| Privacy policy | The URL from step 1A |
| Ads | **Yes**, the app contains ads |
| App access | All functionality is available without a login, so leave the credentials blank |
| Content rating | Complete the questionnaire (no objectionable content) |
| Target audience | 18+ only - the app is not directed at children |
| News app | No |
| COVID-19 contact tracing | No |
| Data safety | See the table below |
| Advertising ID declaration | Yes - the Google Mobile Ads SDK uses the advertising ID |
| Government apps | No |
| Financial features | The app **tracks** investments; it never buys, sells or holds assets on your behalf, so no special declaration is needed |
| Health apps | No |

### The Data safety form, answered

Everything the app stores itself stays on the device, so it is **not collected**. What is collected comes from Google's advertising SDK:

| Data type | Collected? | Shared? | Purpose |
|---|---|---|---|
| Financial info (your holdings) | No | No | It never leaves the device |
| Location (approximate) | Yes | Yes | Advertising or marketing - from the ads SDK |
| App activity (in-app actions) | Yes | Yes | Advertising or marketing, analytics - from the ads SDK |
| Device or other IDs | Yes | Yes | Advertising or marketing - from the ads SDK |
| Advertising info | Yes | Yes | Advertising or marketing - from the ads SDK |
| App info and performance (crash logs, diagnostics) | Yes | Yes | Analytics - from Google Play services |

### Closed testing is enough

You do **not** need a public release. Upload the bundle to a **closed testing** track and roll it out to your own test account. AdMob is happy with that, and so is the Play review.

---

## 3. Link the app in AdMob

1. In the AdMob console open **Apps → Stock Pulse (Android) → Add store**.
2. Pick the Play listing you just created. If Play has not finished processing the listing yet, wait for it - the store sometimes takes a few hours to show up.
3. AdMob then reviews the app. This usually takes **a few days**. During the review the status stays **"Requires review"** and the app is limited to test ads.
4. When it is approved the limit lifts and real ads start serving.

### If it is rejected

AdMob emails the reason. In practice it is nearly always one of these:

- **No privacy policy, or a policy that cannot be opened** - make sure the URL loads without a login and without a redirect that breaks it.
- **The store listing does not match the app** - the screenshots and description should show what the app actually does.
- **The app does not load, or crashes on launch** - test the exact bundle you uploaded.
- **Ads are not labelled** - ours are labelled "Sponsored", and Google's own template draws the AdChoices badge.
- **The app asks for a login it does not need** - ours does not.

---

## 4. The ads start by themselves

A release build uses the real AdMob units, so **the ads begin serving the moment AdMob approves the app**. There is no flag to flip and no rebuild to make.

Before approval, AdMob simply serves nothing from those units - an unapproved app shows no ads at all, which is why there is nothing to worry about during the Play review.

The one thing to do is protect your own phone, because clicking a real ad is what can get an account flagged:

1. **Register your device in AdMob** - AdMob → Device management → Register device. The SDK then serves Google's test ads to that device automatically, and a real ad can never appear on it.
2. Or flip the **"test ads on this device"** switch in the developer panel (five taps on the version number in Settings → About). It affects that device only.

A build can also be forced to test ads everywhere with `--dart-define=ADS_LIVE=false`, or by setting the `ADS_LIVE` repository secret to `false` for one release.

---

## 5. The keystore secrets

Add these as **repository secrets** (Settings → Secrets and variables → Actions) so every tagged build also produces a signed `.aab`:

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | `base64 -w0 ~/stockpulse-upload.jks` |
| `STORE_PASSWORD` | the keystore password |
| `KEY_ALIAS` | `upload` |
| `KEY_PASSWORD` | the key password |
| `ADS_LIVE` | leave unset (live ads are the default); set it to `false` only for a release that must serve test ads |

Create the keystore once and keep it safe - losing it means you cannot update the app:

```bash
keytool -genkey -v -keystore ~/stockpulse-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

To build a bundle locally instead, copy `platform_overlay/android/key.properties.example` to `android/key.properties` after running `scripts/setup_platforms`, fill it in, and run `flutter build appbundle --release`.

---

## 6. After approval

Open **Settings → Advertising** in the app after a few days of real use. The developer panel (five taps on the version number in Settings → About) shows a placement report: impressions, clicks and estimated revenue per placement, from the ad SDK's own paid-event reporting. Use it to decide which placements deserve their own ad unit.
