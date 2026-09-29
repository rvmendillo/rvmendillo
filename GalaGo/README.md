# GalaGo — More gala. Less gastos.

Native SwiftUI iPhone/iPad travel planner, iOS 16+. Origin is always MNL. Compare 3–7 calendar-day Philippine round trips using Cebu Pacific, Agoda and Klook, with editable daily itineraries, PHP group totals and a voucher wallet.

## Install the IPA

`GalaGo-unsigned.ipa` is a compiled arm64 iPhone application, **not signed for installation**. Import it into your signing application (for example, your existing Feather setup), sign it with a valid certificate and provisioning profile for your device, then install. No signing credentials are embedded in the source or package. The unsigned file cannot be installed just by tapping it in Files.

Source and workflow live on the `codex/galago-20260929` branch. The existing main branch is unchanged.

## What works

- Catalog of 38 Philippine destination airports. A catalog entry does not assert current Cebu Pacific service. Connections or unavailable routes must be checked with the airline. Clark is never substituted for MNL.
- Enumerates every departure date in your selected window and each duration from 3 to 7 days (2 to 6 nights), across the catalog or one selected destination.
- On-device WKWebView scraper reads **rendered PHP price text and explicit promo-code mentions** on the three provider websites. No API keys are required for this public-page capture feature.
- Single active page, 35-second page deadline, 8-second spacing, 20-page foreground batches, saved queue, bounded retry/backoff, provider-wide `Retry-After` cooldowns, CAPTCHA/access-denial pause and resume. Leaving the app pauses work and preserves progress. The latest 3,000 raw price candidates are retained; save complete quotes to keep important prices independently of that rolling candidate cache.
- Captured prices and promo strings are candidates, never automatically represented as bookable offers. Browse normally when a provider resets search parameters or requires interaction. Confirm the destination, dates, travelers, rooms, currency, rate unit and taxes before saving a complete quote.
- Rank complete, matching, unexpired quotes by full **group** total. Cheapest-per-destination or every date option. Clearly labeled examples are opt-in and never mixed into real quotes.
- Exact centavo arithmetic, per-person display, editable food/local-transport allowances, all-room/all-night accommodation totals and separate transfer/baggage costs.
- Best confirmed voucher per provider with percentage/fixed amounts, caps, minimum spend, booking/travel dates, channel, payment and new-customer restrictions. Valid only for explicitly linked quotes. Already-included codes cannot be subtracted twice. Editing or replacing a quote invalidates its linked voucher confirmations.
- Editable day-by-day itinerary, bookmarks, share sheet, quote JSON import/export, local protected persistence.

## Limits that cannot be guaranteed away

This build is a **scraping-assisted planner**, not an independently verified, fully automatic market-wide booking search. Public pages can change, reject automated access, require authentication or show only teaser prices. The scraper does not automatically navigate every flight/hotel checkout, solve CAPTCHAs, rotate IP addresses, bypass rate limits, or verify every account-specific voucher. It fails closed: missing data never becomes a zero-cost deal. User review is required before a scraped candidate becomes a ranked quote.

A large all-destination date window means thousands of page jobs and may take many sessions; completeness is shown explicitly. Keep the scanner open and tap Resume for the next batch. Quotes age, voucher availability changes and inventory can sell out. No app can promise every source will always respond, no rate limits, no timeouts, exhaustive lowest-price coverage, or acceptance of every discount.

Cashback is not subtracted from the amount payable because payout and stacking can be conditional. One confirmed code per provider is conservative; choose the exact checkout saving as a fixed amount when taxes/items are excluded from a percentage offer. Extra optional itinerary ideas are not included unless added to the activity budget.

## Cost model

```
Group total = return flight total for party
            + hotel total for all rooms and nights
            + selected activity total for party
            + round-trip airport transfer total for party
            + baggage extras not already in flight quote
            + daily food allowance × days × travelers
            + daily local transport allowance × days × travelers
            − best eligible confirmed discount for each provider
```

All stored money is integer PHP centavos. A 3-day trip has 2 hotel nights. Quotes are specific to dates, adults and room count. The current UI supports adult-only trips; children require additional modeling and are not silently priced as adults.

## Build and verification

On macOS with Xcode and an iOS SDK:

```bash
cd GalaGo
swift test
node scripts/test-capture.cjs
python3 scripts/generate_project.py
swift scripts/icon.swift Resources/Assets.xcassets/AppIcon.appiconset
xcodebuild -project GalaGo.xcodeproj -scheme GalaGo -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

The GitHub Actions workflow performs the core tests, capture-script fixture checks, device build, IPA packaging, simulator build, launch and screenshots. Public-site end-to-end pricing reliability is **not** certified by those tests. The separate scraper test reads the actual embedded script from Swift so it cannot silently diverge from the app.

19 core tests cover total arithmetic, day/night boundaries, date enumeration, voucher eligibility/caps/non-stacking/double counting, expired quotes, invalid input, demo separation, party matching, ranking and retry policy. Capture fixtures cover currency, explicit code detection, blocked pages and bounded output.

## Data and privacy

Quotes, plans and search state are stored locally in the app's Documents directory with iOS file protection. WebKit maintains normal provider website data for browsing. The capture script reads visible text only; it does not inspect passwords, form values, cookies, tokens, local storage or authenticated request headers. No analytics or tracking backend is added. Exported quotes may contain notes you entered; share deliberately. No automatic purchases or reservations are performed.

Independent branding. Cebu Pacific, Agoda and Klook retain their trademarks; GalaGo is not affiliated with these services.

## Provider references checked on 29 September 2026

- Agoda partner onboarding: https://developer.agoda.com/demand/docs/getting-started
- Agoda API authentication and search schema: https://developer.agoda.com/demand/docs/json-search-api
- Cebu Pacific partner portal: https://partners.cebupacificair.com/
- Klook affiliate portal: https://affiliate.klook.com/home

Agoda documents partner credentials and pre-checking changing availability. No public unauthenticated production API credentials were supplied for this project, so they are not fabricated or bundled. The on-device scraper is available independently of API access.
