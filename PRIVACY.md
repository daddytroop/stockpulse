# Privacy Policy - Stock Pulse

**Last updated: 30 October 2026**

Stock Pulse is a free, open-source portfolio and dividend tracker. It is published by an independent developer, is not affiliated with any broker or market data provider, and is not investment advice.

This policy explains what the app does with your information.

## The short version

- Your **portfolios, holdings, quantities and cost basis never leave your device**. They are stored in the app's own private storage.
- The developer **does not collect, receive, sell or share any of your financial data**. There is no account, no sign-up and no server behind the app.
- The **only data sent anywhere** comes from the advertising SDK and from optional features you turn on yourself, and both are described below.
- You can delete everything the app stores, in one action, from **Settings → Data → Restore backup** area, or by uninstalling.

## What is stored on your device

The app stores the following locally, in the app's private storage:

- Your portfolios and the symbols, quantities and average costs within them
- Transactions you record (buys and sells)
- Cached quotes, price history and dividend history
- Your preferences: theme, accent colour, display currency, notification settings, biometric lock, and the optional Gist sync configuration

On Android, some of this is written to the home-screen widgets and to the device's notification schedule, so the widget and the alerts stay current when the app is closed. That data never leaves the device either.

## Market data

Prices, quotes, dividend histories, earnings dates, company logos and news headlines are fetched from **Yahoo Finance's unofficial public endpoints** and from **Wikimedia Commons** for logos. Those requests necessarily reveal your IP address and the fact that you are requesting market data. They are not linked to you by the developer. Market data may be delayed and may occasionally be wrong; the app shows the timestamp of every quote for that reason.

## Advertising

The Android build shows ads from **Google AdMob**, which is how the app is funded. Windows and the web build do not request ads.

Google's advertising SDK operates independently of the app's own storage. It may use the device advertising ID, information about the device, app interactions and approximate location to serve and measure ads. Google's own policies govern that data, and it is not available to the developer.

- If you are in the European Economic Area, the United Kingdom, Switzerland or the United States, Google presents a consent message before any ad is served. You can change that choice at any time under **Settings → Advertising → Ad privacy choices**. Choosing to decline consent does not remove the ads; it means the ads carry less information about you.
- Ads are labelled, and they never affect the accuracy of the numbers in the app.
- Google's test ads are used until the app is approved and published on Google Play; live ads are enabled afterwards.

## Optional features you control

**Private Gist sync.** If you turn this on, the app writes a backup of your portfolios to a private Gist in **your own** GitHub account, using a personal access token that you supply and that is stored only on your device. Nobody else - including the developer - can read it. You can revoke the token in GitHub at any time.

**Crash diagnostics.** If you turn these on, the app records crashes and errors locally so you can send them to the developer if you choose. The records are redacted: they never contain symbols, quantities, tokens or account numbers.

**Notifications.** Dividend, earnings and price-move alerts are scheduled on your device by Android itself. Nothing is sent to a push server.

## Children

Stock Pulse is not directed at children and is not designed for them. It is a tool for adults managing their own investments.

## Your rights

Because your financial data never leaves your device, the developer has nothing to hand over: there is no account to delete, no export to request and no server-side record to erase. To remove everything the app holds, uninstall it, or use the backup and restore tools in **Settings → Data** to overwrite the data with an empty backup.

If you have a question about this policy, open an issue on the project's GitHub page.

## Changes

If this policy changes, the "Last updated" date above changes with it and the new version is published with the app.
