# GalaGo — More gala. Less gastos.

Native SwiftUI iPhone/iPad travel planner, iOS 16+. Origin is always MNL. Compare 3–7 calendar-day domestic and international round trips using Cebu Pacific, Agoda and Klook, with editable daily itineraries, PHP group totals and a voucher wallet.

## Install the IPA

`GalaGo-unsigned.ipa` is a compiled arm64 iPhone application, **not signed for installation**. Import it into your signing application (for example, your existing Feather setup), sign it with a valid certificate and provisioning profile for your device, then install. No signing credentials are embedded in the source or package. The unsigned file cannot be installed just by tapping it in Files.

Source and workflow live on the `codex/galago-20260929` branch. The existing main branch is unchanged.

## What works

- Catalog of 65 destination airports: 38 Philippine and 27 international airports. A catalog entry does not assert current Cebu Pacific service. Connections or unavailable routes must be checked with the airline. Clark is never substituted for MNL.
- Enumerates every departure date in your selected window and each duration from 3 to 7 days (2 to 6 nights), across the catalog, the international/domestic subset, or one selected destination. Quick results (the default) samples the first, middle and last departure dates; Every departure date retains the complete date grid.
- On-device WKWebView scraper reads **rendered PHP price text and explicit promo-code mentions** on the three provider websites. No API keys are required for this public-page capture feature.
- Three independent provider workers, at most one active page per provider, 35-second page deadlines, and at least 8 seconds between starts for the same provider. Readiness checks capture visible prices without the old fixed 5-second post-load delay or 8-second post-capture delay. Queues continue in the foreground, reuse exact matching cached searches, honor bounded retry/backoff and provider-wide `Retry-After` cooldowns, and pause the affected provider on verification/access denial. Leaving the app pauses work and preserves progress. The latest 3,000 raw price candidates are retained. Recognized lowest component prices are archived separately for every searched date/party/provider and remain available after the raw cache rolls over.
- A dedicated **Prices** tab automatically multiplies recognized PHP rates by adults, rooms and hotel nights, adds daily budgets and trip extras, subtracts confirmed codes, and sorts totals lowest first. Every airport remains visible; missing provider amounts are labeled incomplete, never filled with zero. Tap a price for every line of arithmetic and its source. Estimates and checked snapshots are labeled.
- A dedicated **Codes** tab shows actual copyable voucher strings, captured terms and source URLs. It includes three published, product-specific Klook code observations from 29 September 2026; they remain unverified and do not automatically reduce a trip. Official-page capture buttons are available for all three providers. Codes containing a literal `%` retain it.
- Captured prices and promo strings are candidates, never automatically represented as bookable offers. Browse normally when a provider resets search parameters or requires interaction. Confirm the destination, dates, travelers, rooms, currency, rate unit and taxes before saving a complete quote.
- Rank complete, matching, unexpired quotes by full **group** total. Cheapest-per-destination or every date option. Clearly labeled examples are opt-in and never mixed into real quotes.
- Exact centavo arithmetic, per-person display, editable food/local-transport allowances, all-room/all-night accommodation totals and separate transfer/baggage costs.
- Best confirmed voucher per provider with percentage/fixed amounts, caps, minimum spend, booking/travel dates, channel, payment and new-customer restrictions. Valid only for explicitly linked quotes. Already-included codes cannot be subtracted twice. Editing or replacing a quote invalidates its linked voucher confirmations.
- Editable day-by-day itinerary, bookmarks, share sheet, quote JSON import/export, local protected persistence.

## Limits that cannot be guaranteed away

This build is a **scraping-assisted planner**, not an independently verified, fully automatic market-wide booking search. Public pages can change, reject automated access, require authentication or show only teaser prices. The scraper does not automatically navigate every flight/hotel checkout, solve CAPTCHAs, rotate IP addresses, bypass rate limits, or verify every account-specific voucher. It fails closed: missing data never becomes a zero-cost deal. Recognized captured prices become automatically ranked **estimates**. User review is required before an estimate becomes a checked quote. Ambiguous units require a one-time choice in Review price unit; multiplication then happens automatically.

A large all-destination date window still means many page jobs. Quick mode reduces the date grid explicitly; use Every departure date for exhaustive departure-date enumeration. Keep the scanner open; requests continue at the per-provider pace until done or paused. Scans are not exhaustive until their selected queue completes, and quick-mode results are not an exhaustive date-window minimum. Quotes age, voucher availability changes and inventory can sell out. No app can promise every source will always respond, no rate limits, no timeouts, exhaustive lowest-price coverage, or acceptance of every discount.

Cashback is not subtracted from the amount payable because payout and stacking can be conditional. One confirmed code per provider is conservative; choose the exact checkout saving as a fixed amount when taxes/items are excluded from a percentage offer. Extra optional itinerary ideas are not included unless added to the activity budget.

## Cost model

```
Group total = return flight total for party
            + hotel total for all rooms and nights
            + selected activity total for party
            + round-trip airport transfer total for party
            + baggage extras not already in flight quote
            + other costs (visa, travel tax, insurance, etc.)
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

42 core tests cover total arithmetic, day/night boundaries, date enumeration, voucher eligibility/caps/non-stacking/double counting, expired quotes, invalid input, demo separation, party matching, ranking and retry policy. 24 capture/readiness assertions cover currency, explicit code detection (including %), offer terms, separate price evidence, blocked pages and bounded output. New core cases verify all 27 international airports, correct country search parameters, automatic unit arithmetic, missing costs, extras, teaser exclusion, exact snapshot voucher eligibility and decoding older saved data.

## Data and privacy

Quotes, plans and search state are stored locally in the app's Documents directory with iOS file protection. WebKit maintains normal provider website data for browsing. The price capture reads visible text. Route validation reads only public search-route fields and route labels; it does not inspect passwords, account/contact fields, cookies, tokens, local storage, or authenticated request headers. No analytics or tracking backend is added. Exported quotes may contain notes you entered; share deliberately. No automatic purchases or reservations are performed.

Independent branding. Cebu Pacific, Agoda and Klook retain their trademarks; GalaGo is not affiliated with these services.

## Provider references checked on 29 September 2026

- Agoda partner onboarding: https://developer.agoda.com/demand/docs/getting-started
- Agoda API authentication and search schema: https://developer.agoda.com/demand/docs/json-search-api
- Cebu Pacific partner portal: https://partners.cebupacificair.com/
- Klook affiliate portal: https://affiliate.klook.com/home

Agoda documents partner credentials and pre-checking changing availability. No public unauthenticated production API credentials were supplied for this project, so they are not fabricated or bundled. The on-device scraper is available independently of API access.

## Version 1.1: international coverage and automatic Prices

International airport catalog (MNL origin and return fixed): DPS, DMK, BKK, BWN, DAD, DXB, FUK, CAN, HAN, SGN, HKG, CGK, KHH, KUL, MFM, MEL, NGO, KIX, RUH, CTS, PVG, SYD, ICN, SIN, TPE, NRT, XMN. Country names are used in Agoda searches. This is Cebu Pacific scope, not all airlines from Manila. Catalog inclusion does not promise service on every date; availability is established by the provider. Domestic entries retain the earlier broader Philippine catalog; MNL is never replaced with Clark.

The automatic calculation uses the cheapest recognized component from each provider for the same destination, dates, adults and rooms. It does not solve product availability, optimize every fare/hotel combination after restricted vouchers, or claim a complete global minimum. Activities default to one paid Klook experience; choose free exploration in Settings to explicitly omit that component. Meal, local transport and extra budgets are global planning allowances: adjust them for the destination before accepting a total. Extra budget defaults of zero mean unset, not a guarantee of no charge.

Captured estimates expire after one hour by default. Include expired quotes can reveal older snapshots; expired snapshots do not receive voucher deductions. Editing captured units, refreshing captures or editing a saved quote invalidates relevant voucher confirmations. The app preserves the v1.0 saved-state format through optional new fields.

Additional sources checked 29 September 2026:
- Cebu Pacific international airport guides: https://help.cebupacificair.com/articles/flying-out-soon
- Cebu Pacific network corroboration: https://www.flightconnections.com/route-map-cebu-pacific-5j
- Klook published code observations: https://www.klook.com/en-PH/deals/
- Agoda current offer page: https://www.agoda.com/deals

No live total is bundled or fabricated. Published foreign-currency voucher amounts require the actual PHP checkout saving before deduction; no invented exchange rate is used. Klook product-specific codes must be linked only to the eligible product's exact trip snapshot, with current booking/travel dates and checkout eligibility confirmed. No universal Cebu Pacific or Agoda code has been invented.

## Version 1.2: fix MNL-to-MNL and retrieve prices sooner

The previous flight URL incorrectly sent both `o1/d1` and `o2/d2`, plus uppercase passenger keys. Cebu Pacific's public booking client interprets the presence of `o2` as a **multi-city** request. Its passenger keys are lowercase. A round trip uses only `o1=MNL`, `d1=<destination>`, `dd1=<outbound>`, `dd2=<return>`, `adt`, `chd`, `inl`, and `inf`. The return airport is implied by the round-trip mode; do not append `o2` or `d2`.

This contract was inspected in the airline's publicly served client on 29 September 2026:
https://www.cebupacificair.com/main.f4423cb09aa518ba.js

The app rejects same-airport, changed-route, changed-date, duplicate-parameter and multi-city flight links before accepting captured prices. Visible public route fields are also checked where present. Legacy flight captures from the broken URL are removed on upgrade and those flight jobs are queued again; manually checked trip quotes and voucher data remain intact. Search dates display in Manila time even when the device is abroad.

Speed changes:
- Cebu Pacific, Agoda and Klook each get an independent worker and visible provider tab. One slow or restricted provider no longer holds the other two.
- One in-flight page per provider, minimum eight-second start spacing per provider, persisted cooldown and last-start state. This is not an IP-rotation or rate-limit bypass mechanism.
- Price readiness is inspected every 750 ms after navigation commits. No separate fixed five-second wait after load, and no unconditional eight-second pause after capture.
- Exact destination/date/party/room cache entries under one hour are reused. Invalid flight URLs and excluded captures cannot satisfy the cache.
- Quick results checks up to three departure dates across **every selected destination and every selected 3–7-day length**. For a 31-day, 3–7-day, 65-airport search this queues 2,925 pages instead of 30,225 (90.3% fewer). This compares scheduled work, not measured live-network speed, and deliberately samples the departure window. Every departure date remains available in Settings.
- Foreground scans continue automatically instead of pausing after each 20-page batch.

Verification covers all 65 airports and 1/4/9 adults against the corrected link contract, legacy/duplicate/same-airport rejection, date-window coverage, independent worker selection, exact cache matching/expiry, timing and persisted-state compatibility. Live search speed depends on the providers. The airline's page rendered blank in this test browser, so live booking results could not be visually verified; the corrected contract was verified directly against its current publicly served client code.
