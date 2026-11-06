# Launch checklist

Everything the code needs is done. What is left happens in Google's
consoles and can only be done from your accounts. Work top to bottom:
each step unblocks the next. [`PLAY_LAUNCH.md`](PLAY_LAUNCH.md) has the
detail behind each one, and [`STORE_LISTING.md`](STORE_LISTING.md) has the
listing text.

## 1. Sign the app (once, 10 minutes)

- [ ] Create the upload keystore (`keytool` command in PLAY_LAUNCH.md §5)
      and keep a backup somewhere safe. Losing it means you can never
      update the app.
- [ ] Add the GitHub secrets `KEYSTORE_BASE64`, `STORE_PASSWORD`,
      `KEY_ALIAS`, `KEY_PASSWORD`. From then on every tagged release
      also contains `app-release.aab`, the file Play wants.

## 2. Play Console: the app and its listing

- [ ] Create the app with package name **`app.stockpulse`**.
- [ ] Main store listing: paste from STORE_LISTING.md, upload the icon
      (`assets/icon/app_icon.png`), a 1024×500 feature graphic and the
      screenshots.
- [ ] App content: privacy policy URL, **Ads: yes**, content rating
      questionnaire, target audience **18+** (finance app, keeps you out
      of the Families policy), Data safety (answers in PLAY_LAUNCH.md),
      and the **Financial features** declaration: choose that the app
      does *not* provide loans, trading or payments (it is a tracker).
- [ ] Payments profile: Play Console → Settings → Payments profile. Needed
      before you can sell anything.

## 3. Pro: the one-time unlock

- [ ] Upload a signed `.aab` to the **Internal testing** track first. Play
      only lets you create in-app products once a build that uses
      billing has been uploaded.
- [ ] Monetize → Products → In-app products → **Create product**:
  - Product ID: **`stockpulse_pro_lifetime`** (must match exactly)
  - Name: *Stock Pulse Pro*
  - Description: *One-time unlock: dividend snowball, health score,
    unlimited watchlist alerts, pro chart studies, exclusive themes, no ads.*
  - Price: suggested **$5.99 USD**, then let Play convert to other
    currencies.
  - **Activate** it.
- [ ] Settings → License testing: add your Google account. Testers can
      buy Pro without being charged.
- [ ] Install from the internal testing link, open any locked tool, and
      buy. Then uninstall, reinstall and check that Pro comes back on its
      own (purchases are restored at start-up).

## 4. AdMob: ads and the "watch an ad" trial

- [ ] Create a **Rewarded** ad unit in the Stock Pulse app in AdMob and
      paste its ID into `AdUnits.rewarded` in
      `lib/services/ad_service.dart`. Until then the "Watch an ad for 24
      hours" button stays hidden in release builds.
- [ ] Privacy & messaging → create a **GDPR** message (and the **US
      states** message). The app shows Google's consent form
      automatically, but only once these messages exist. Without them,
      users in the EU and UK get no ads at all.
- [ ] Register your phone as a test device (AdMob → Settings → Test
      devices) so you can never click a real ad yourself.
- [ ] After the app is live on Play, link it to the store listing in
      AdMob (Apps → App settings → Linked app store). AdMob reviews it
      within a few days, and the ads start by themselves; no new build is
      needed.
- [ ] Put `app-ads.txt` at the root of the website you list on Play.

## 5. Testing track, then production

- [ ] New personal developer accounts must run a **closed test with at
      least 12 testers for 14 days** before Play allows production. Start
      this as early as possible. Friends and family who install from
      the opt-in link count.
- [ ] Promote to production, with the release notes from
      STORE_LISTING.md.

## What to check on a real phone before production

| Check | Where |
|---|---|
| Banner at the end of the portfolio, native cards in the holdings list, News and Dividends | Live ads need AdMob approval; before that, turn on "Test ads on this device" in the developer panel (5 taps on the version in Settings → About, test builds only) |
| Buying Pro removes every ad at once | License tester account |
| "Watch an ad" unlocks a feature for 24h | Needs the rewarded unit from step 4 |
| Consent form appears for an EU user | Use a VPN to an EU country after step 4 |
| Widgets update with the app closed | Leave the phone for an hour |
