import SwiftUI
import UniformTypeIdentifiers

struct SettingsView:View {
    @EnvironmentObject var store:AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var settings=SearchSettings()
    @State private var food="350"
    @State private var transport="100"
    @State private var transfers="0"
    @State private var baggage="0"
    @State private var other="0"
    @State private var paidActivity=true
    var body:some View{NavigationStack{Form{
        Section("Trip search"){LabeledContent("Origin",value:"Manila · MNL (fixed)");DatePicker("Earliest departure",selection:dateBinding(\.firstDeparture),displayedComponents:.date);DatePicker("Latest departure",selection:dateBinding(\.lastDeparture),displayedComponents:.date);Stepper("At least \(settings.minDays) days",value:$settings.minDays,in:3...7).onChange(of:settings.minDays){v in if settings.maxDays<v{settings.maxDays=v}};Stepper("Up to \(settings.maxDays) days",value:$settings.maxDays,in:settings.minDays...7);Text("3 days = 2 nights. The return date may fall after the last departure date.").font(.caption).foregroundColor(.secondary)}
        Section("Retrieval speed") {
            Picker("Search mode",selection:Binding(get:{settings.retrievalMode},set:{settings.searchMode=$0})){ForEach(SearchMode.allCases){Text($0.title).tag($0)}}
            Text("Quick results checks the first, middle and last departure dates, with every selected trip length and destination. Every departure date covers the full window. Both reuse fresh prices and search the three providers concurrently.").font(.caption).foregroundColor(.secondary)
        }
        Section("Travel party"){Stepper("\(settings.adults) adult(s)",value:$settings.adults,in:1...9).onChange(of:settings.adults){v in settings.rooms=min(settings.rooms,v)};Stepper("\(settings.rooms) room(s)",value:$settings.rooms,in:1...settings.adults);Text("Adult fares only. Include all room occupancy charges in your hotel quote.").font(.caption).foregroundColor(.secondary)}
        Section("Daily budget · PHP per person"){TextField("Meals per day",text:$food).keyboardType(.decimalPad);TextField("Local transport per day",text:$transport).keyboardType(.decimalPad);Text("These are your planning allowances, not prices from a provider. Airport transfers are a separate trip total.").font(.caption).foregroundColor(.secondary)}
        Section("Trip extras · PHP for the whole party") {
            TextField("Airport transfers, both ways",text:$transfers).keyboardType(.decimalPad)
            TextField("Baggage extras, both ways",text:$baggage).keyboardType(.decimalPad)
            TextField("Other costs: visa, travel tax, insurance",text:$other).keyboardType(.decimalPad)
            Toggle("Include one paid Klook activity",isOn:$paidActivity)
            Text("Applied to automatic estimates in Prices. Set allowances for your destination; 0 does not confirm a cost is free. Checked quotes keep their own extras. Turn off paid activities only if you plan free exploration.").font(.caption).foregroundColor(.secondary)
        }
        Section("Voucher eligibility"){Picker("Booking channel",selection:$settings.channel){Text("Website").tag("web");Text("Provider app").tag("app")};TextField("Payment method",text:$settings.payment);Toggle("Eligible as a new customer",isOn:$settings.newCustomer);Text("Card names must match the voucher’s requirement. Eligibility must still be checked at checkout.").font(.caption).foregroundColor(.secondary)}
        Section{Toggle("Include expired quotes",isOn:$settings.includeExpired);Text("Expired quotes are labeled. Expired voucher savings are never subtracted.").font(.caption).foregroundColor(.secondary)}
    }.navigationTitle("Search settings").toolbar{ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}};ToolbarItem(placement:.confirmationAction){Button("Save"){guard let f=Money.parse(food),let t=Money.parse(transport),let x=Money.parse(transfers),let b=Money.parse(baggage),let o=Money.parse(other) else{store.toast="Enter valid daily PHP amounts.";return};settings.foodDaily=f;settings.transportDaily=t;var extra=ExtraBudget();extra.transfers=x;extra.baggage=b;extra.other=o;extra.paidActivity=paidActivity;settings.extras=extra;if let error=settings.validation{store.toast=error;return};store.state.settings=settings;store.save();dismiss()}}}.onAppear{settings=store.state.settings;food=String(Double(settings.foodDaily)/100);transport=String(Double(settings.transportDaily)/100);transfers=String(Double(settings.budget.transfers)/100);baggage=String(Double(settings.budget.baggage)/100);other=String(Double(settings.budget.other)/100);paidActivity=settings.budget.paidActivity}}}
    private func dateBinding(_ path:WritableKeyPath<SearchSettings,String>)->Binding<Date>{Binding(get:{ManilaDate.parse(settings[keyPath:path]) ?? Date()},set:{settings[keyPath:path]=ManilaDate.string($0)})}
}
struct QuoteEditor:View {
    @EnvironmentObject var store:AppStore
    @Environment(\.dismiss) private var dismiss
    var candidate:PriceCandidate?=nil
    var destination:String?=nil
    var existing:TripQuote?=nil
    @State private var quote=TripQuote()
    @State private var amounts=["flight":"","hotel":"","activity":"0","transfers":"0","baggage":"0","other":"0"]
    @State private var expiry=60
    @State private var browserJob:ScanJob?
    @State private var included=""
    @State private var loaded=false
    @State private var error:String?=nil
    var body:some View{NavigationStack{Form{
        if candidate != nil {Section{Label("Captured price needs review",systemImage:"exclamationmark.circle").foregroundColor(Theme.coral);Text("Check currency, dates, quantity and whether the captured amount is per night, per person or a starting fare. Enter complete group totals below.").font(.caption)}}
        Section("MNL round trip"){Picker("Destination",selection:$quote.destination){ForEach(Destination.all){Text("\($0.name) · \($0.code)").tag($0.code)}};DatePicker("Departure",selection:dateBinding(\.departure),displayedComponents:.date);DatePicker("Return",selection:dateBinding(\.returning),displayedComponents:.date);Text("\(quote.days) days · \(max(0,quote.days-1)) nights").font(.caption);Stepper("\(quote.adults) adult(s)",value:$quote.adults,in:1...9).onChange(of:quote.adults){v in quote.rooms=min(quote.rooms,v)};Stepper("\(quote.rooms) room(s)",value:$quote.rooms,in:1...max(1,quote.adults))}
        Section {amountRow("Return flights · whole party",key:"flight",provider:.flight);amountRow("Hotel · entire stay, all rooms",key:"hotel",provider:.hotel);TextField("Hotel name",text:$quote.hotelName);amountRow("Activities · whole party",key:"activity",provider:.activity);TextField("Activity / package name",text:$quote.activityName);amountRow("Round-trip airport transfers · party",key:"transfers");amountRow("Baggage extras · both ways, party",key:"baggage");amountRow("Other required costs · visa / tax / insurance",key:"other")} header:{Text("Complete PHP totals")} footer:{Text("Use checkout totals with mandatory taxes and fees. Enter baggage as 0 if already in flights. Enter transfers as 0 only if free or already included. Activities can be 0 for a trip with no paid tours.")}
        Section("Discounts already in these totals"){TextField("Included voucher codes, comma separated",text:$included).textInputAutocapitalization(.characters);Text("Listing an included code prevents subtracting it again.").font(.caption).foregroundColor(.secondary)}
        Section("Verify your quote"){Toggle("I checked the dates, party, room count, taxes, required fees, visa costs and transfer costs",isOn:$quote.mandatoryFeesIncluded);Picker("Recheck after",selection:$expiry){Text("15 minutes").tag(15);Text("1 hour").tag(60);Text("24 hours").tag(1440)};TextField("Notes / inclusions",text:$quote.note,axis:.vertical).lineLimit(3...6);Text("A saved quote is your checked snapshot. Prices and availability may change before payment.").font(.caption).foregroundColor(.secondary)}
        if let error=error{Section{Text(error).foregroundColor(.red)}}
    }.navigationTitle(existing==nil ? "Add trip quote" : "Edit trip quote").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}};ToolbarItem(placement:.confirmationAction){Button("Save"){save()}}}.onAppear{load()}.sheet(item:$browserJob){j in ScannerView(store:store,initial:j){c in amounts[j.provider.rawValue]=String(Double(c.amount)/100);quote.mandatoryFeesIncluded=false;browserJob=nil}}}}
    private func dateBinding(_ path:WritableKeyPath<TripQuote,String>)->Binding<Date>{Binding(get:{ManilaDate.parse(quote[keyPath:path]) ?? Date()},set:{quote[keyPath:path]=ManilaDate.string($0);quote.mandatoryFeesIncluded=false})}
    private func amountRow(_ title:String,key:String,provider:Provider?=nil)->some View{VStack(alignment:.leading,spacing:6){Text(title).font(.caption).foregroundColor(.secondary);HStack{Text("₱").foregroundColor(.secondary);TextField("0.00",text:Binding(get:{amounts[key] ?? ""},set:{amounts[key]=$0;quote.mandatoryFeesIncluded=false})).keyboardType(.decimalPad);if let p=provider{Button("Capture"){browserJob=ScanJob(provider:p,destination:quote.destination,departure:quote.departure,returning:quote.returning,adults:quote.adults,rooms:quote.rooms)}.font(.caption)}}}}
    private func load(){guard !loaded else{return};loaded=true;quote=existing ?? TripQuote();if existing==nil{quote.departure=store.state.settings.firstDeparture;quote.returning=ManilaDate.add(quote.departure,days:store.state.settings.minDays-1);quote.adults=store.state.settings.adults;quote.rooms=store.state.settings.rooms;if let destination=destination{quote.destination=destination}};if let c=candidate{quote.destination=c.job.destination;quote.departure=c.job.departure;quote.returning=c.job.returning;quote.adults=c.job.adults;quote.rooms=c.job.rooms;quote.note="Captured from \(c.url)\n\(c.context)"};for pair in [("flight",quote.flight),("hotel",quote.hotel),("activity",quote.activity),("transfers",quote.transfers),("baggage",quote.baggage),("other",quote.otherCosts ?? 0)]{amounts[pair.0]=String(Double(pair.1)/100)};if let c=candidate{amounts[c.job.provider.rawValue]=String(Double(c.amount)/100)};included=quote.includedVoucherCodes.joined(separator:", ")}
    private func save(){guard let f=Money.parse(amounts["flight"] ?? ""),let h=Money.parse(amounts["hotel"] ?? ""),let a=Money.parse(amounts["activity"] ?? ""),let t=Money.parse(amounts["transfers"] ?? ""),let b=Money.parse(amounts["baggage"] ?? ""),let o=Money.parse(amounts["other"] ?? "") else{error="Enter valid amounts for every cost, using 0 only when it is really free or already included.";return};quote.flight=f;quote.hotel=h;quote.activity=a;quote.transfers=t;quote.baggage=b;quote.otherCosts=o;quote.source = .manual;quote.checkedAt=Date();quote.expiresAt=Date().addingTimeInterval(Double(expiry)*60);quote.includedVoucherCodes=included.split(separator:",").map{$0.trimmingCharacters(in:.whitespaces)};if let e=quote.validation{error=e;return};store.upsert(quote);dismiss()}
}
struct VoucherEditor:View {
    var hint:PromoHint?=nil
    var existing:Voucher?=nil
    @EnvironmentObject var store:AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var voucher=Voucher()
    @State private var amount=""
    @State private var cap="0"
    @State private var minimum="0"
    @State private var error:String?=nil
    var body:some View{NavigationStack{Form{
        if let terms=hint?.terms{Section("Published offer terms"){Text(terms).font(.caption);Text("Published codes still need current expiry and exact checkout eligibility.").font(.caption).foregroundColor(.secondary)}}
        Section("Offer"){TextField("Promo code",text:$voucher.code).textInputAutocapitalization(.characters);Picker("Provider",selection:$voucher.provider){ForEach(Provider.allCases){Text($0.name).tag($0)}};Toggle("Percentage discount",isOn:$voucher.percentage);TextField(voucher.percentage ? "Percent off, e.g. 10" : "PHP off",text:$amount).keyboardType(.decimalPad);TextField("Maximum PHP discount · 0 means no cap",text:$cap).keyboardType(.decimalPad);TextField("Minimum spend in PHP",text:$minimum).keyboardType(.decimalPad);TextField("Official offer URL",text:$voucher.sourceURL).keyboardType(.URL).textInputAutocapitalization(.never)}
        Section("Booking and travel dates"){dateRow("Book from",\.bookingStart);dateRow("Book until",\.bookingEnd);dateRow("Travel from",\.travelStart);dateRow("Travel through",\.travelEnd)}
        Section("Restrictions"){Picker("Channel",selection:$voucher.channel){Text("Any").tag("any");Text("Website").tag("web");Text("Provider app").tag("app")};TextField("Required card, or Any card",text:$voucher.payment);Toggle("New customers only",isOn:$voucher.newCustomerOnly)}
        Section("Exact quotes you checked"){ForEach(store.codeQuotes){q in Toggle("\(q.destination) · \(q.departure) · \(Money.php(q.amount(voucher.provider)))",isOn:Binding(get:{voucher.eligibleQuoteIDs.contains(q.id)},set:{if $0{voucher.eligibleQuoteIDs.append(q.id)}else{voucher.eligibleQuoteIDs.removeAll{$0==q.id}}}))};if store.codeQuotes.isEmpty{Text("Capture a full estimate in Prices or add a complete quote first.").foregroundColor(.secondary)}}
        Section{Toggle("I confirmed this offer applies at checkout to the selected quotes, with these amounts and restrictions",isOn:$voucher.confirmed);Text("Leave off to save a potential code without reducing any total. Ensure the price does not already include this code. For taxes, restricted items or foreign-currency offers, use the exact PHP saving shown at checkout.").font(.caption).foregroundColor(.secondary)}
        if let error=error{Text(error).foregroundColor(.red)}
    }.navigationTitle(existing == nil ? "Add voucher code" : "Edit voucher code").toolbar{ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}};ToolbarItem(placement:.confirmationAction){Button("Save"){save()}}}.onAppear{if let existing=existing{voucher=existing;amount=String(Double(existing.value)/100);cap=String(Double(existing.cap)/100);minimum=String(Double(existing.minSpend)/100);return};if let hint=hint{voucher.code=hint.code;voucher.provider=hint.provider;voucher.sourceURL=hint.sourceURL};let today=ManilaDate.string(Date());voucher.bookingStart=today;voucher.bookingEnd=today;voucher.travelStart=store.state.settings.firstDeparture;voucher.travelEnd=ManilaDate.add(store.state.settings.lastDeparture,days:6)}}}
    private func dateRow(_ title:String,_ path:WritableKeyPath<Voucher,String>)->some View{DatePicker(title,selection:Binding(get:{ManilaDate.parse(voucher[keyPath:path]) ?? Date()},set:{voucher[keyPath:path]=ManilaDate.string($0)}),displayedComponents:.date)}
    private func save(){guard !voucher.code.trimmingCharacters(in:.whitespaces).isEmpty,let value=Money.parse(amount),let c=Money.parse(cap),let m=Money.parse(minimum),value>0,(!voucher.percentage || value<=10000),voucher.bookingStart<=voucher.bookingEnd,voucher.travelStart<=voucher.travelEnd else{error="Check the code, amounts and date ranges.";return};guard !voucher.confirmed || !voucher.eligibleQuoteIDs.isEmpty else{error="Select at least one quote you checked.";return};voucher.value=value;voucher.cap=c;voucher.minSpend=m;if let i=store.state.vouchers.firstIndex(where:{$0.id==voucher.id}){store.state.vouchers[i]=voucher}else{store.state.vouchers.append(voucher)};store.save();dismiss()}
}
