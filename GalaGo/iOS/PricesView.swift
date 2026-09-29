import SwiftUI

private struct PriceBoardRow:Identifiable {
    let destination:Destination
    let calculated:CalculatedTrip?
    let checked:RankedTrip?
    var id:String {checked?.id ?? calculated?.id ?? destination.code}
    var total:Int? {checked?.total ?? calculated?.total}
}
struct PricesView:View {
    @EnvironmentObject var store:AppStore
    @State private var scope="All"
    @State private var query=""
    @State private var allDates=false
    @State private var settings=false
    @State private var scanner=false
    private var catalog:[Destination] {Destination.all.filter{(scope=="All" || (scope=="International" ? $0.isInternational : !$0.isInternational)) && (query.isEmpty || "\($0.name) \($0.code) \($0.country)".localizedCaseInsensitiveContains(query))}}
    private var rows:[PriceBoardRow] {
        let codes=Set(catalog.map(\.code))
        let checked=store.ranked.filter{codes.contains($0.quote.destination)}
        let checkedKeys=Set(checked.map{key($0.quote)})
        var result=checked.compactMap{trip -> PriceBoardRow? in guard let d=Destination.find(trip.quote.destination) else{return nil};return PriceBoardRow(destination:d,calculated:nil,checked:trip)}
        if !store.demo {
            result += store.calculated.filter{codes.contains($0.quote.destination) && !checkedKeys.contains(key($0.quote))}.compactMap{trip in guard let d=Destination.find(trip.quote.destination) else{return nil};return PriceBoardRow(destination:d,calculated:trip,checked:nil)}
        }
        result.sort{a,b in if let x=a.total,let y=b.total{return x==y ? a.id<b.id : x<y};if a.total != nil{return true};if b.total != nil{return false};return a.destination.name<b.destination.name}
        if !allDates {var seen=Set<String>();result=result.filter{seen.insert($0.destination.code).inserted}}
        let found=Set(result.map(\.destination.code))
        result += catalog.filter{!found.contains($0.code)}.sorted{$0.name<$1.name}.map{PriceBoardRow(destination:$0,calculated:nil,checked:nil)}
        return result
    }
    private func key(_ q:TripQuote)->String {"\(q.destination)|\(q.departure)|\(q.returning)|\(q.adults)|\(q.rooms)"}
    var body:some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment:.leading,spacing:10) {
                        Text("Every trip.\nAlready added up.").font(.system(size:30,weight:.bold,design:.rounded)).foregroundColor(Theme.ink)
                        Text("MNL round trips · \(store.state.settings.minDays)–\(store.state.settings.maxDays) days · PHP").font(.subheadline)
                        HStack{Pill(text:"LOWEST TOTAL FIRST");Pill(text:"\(rows.filter{$0.total != nil}.count) PRICED")}
                        Text("Totals recalculate from captured prices and your budgets. Estimates need checkout verification; unpriced trips stay visible.").font(.caption).foregroundColor(.secondary)
                        if store.demo {Pill(text:"ILLUSTRATIVE DEMO · NOT LIVE",color:Theme.coral)}
                    }.padding(.vertical,7)
                    Picker("Coverage",selection:$scope){Text("All").tag("All");Text("International").tag("International");Text("Domestic").tag("Domestic")}.pickerStyle(.segmented)
                    Toggle("Show every captured date option",isOn:$allDates).font(.subheadline)
                    Button{store.makePlan(destinations:catalog.map(\.code));scanner=true}label:{Label("Search \(catalog.count) destination airports",systemImage:"magnifyingglass")}
                    NavigationLink("Review captured price units"){CapturesView()}
                }
                Section("Cheapest available totals · \(store.state.settings.adults) traveler(s)") {
                    ForEach(Array(rows.enumerated()),id:\.element.id){index,row in
                        if let checked=row.checked {
                            NavigationLink{TripDetail(trip:checked)}label:{priceRow(row,rank:index+1)}
                        } else if let calculated=row.calculated {
                            NavigationLink{CalculatedPriceDetail(trip:calculated)}label:{priceRow(row,rank:index+1)}
                        } else {
                            NavigationLink{DestinationView(destination:row.destination)}label:{priceRow(row,rank:index+1)}
                        }
                    }
                }
                Section {
                    Text("\(Destination.international.count) international + \(Destination.domestic.count) Philippine airports. Catalog checked \(Destination.catalogChecked). Cebu Pacific availability from MNL is checked for your dates; routes and schedules can change.").font(.caption).foregroundColor(.secondary)
                    Text("Food, local travel and extras are editable allowances. Missing airfare, hotel or paid-activity prices never count as zero. Unknown taxes, visa costs and other required charges must be checked before booking.").font(.caption).foregroundColor(.secondary)
                }
            }.listStyle(.insetGrouped).navigationTitle("Prices")
            .searchable(text:$query,prompt:"Country, city or airport")
            .toolbar{ToolbarItem(placement:.primaryAction){Button{settings=true}label:{Image(systemName:"slider.horizontal.3")}}}
            .sheet(isPresented:$settings){SettingsView()}
            .sheet(isPresented:$scanner){ScannerView(store:store)}
        }
    }
    private func priceRow(_ row:PriceBoardRow,rank:Int)->some View {
        VStack(alignment:.leading,spacing:8) {
            HStack(alignment:.top){Image(systemName:row.destination.symbol).foregroundColor(Theme.teal).frame(width:25);VStack(alignment:.leading,spacing:3){Text(row.destination.name).font(.headline);Text("MNL ↔ \(row.destination.code) · \(row.destination.country)").font(.caption).foregroundColor(.secondary)};Spacer()}
            if let total=row.total {
                HStack{Text("#\(rank)").font(.caption.bold()).foregroundColor(Theme.teal);Text(Money.php(total)).font(.title2.bold()).foregroundColor(Theme.ink);Spacer();Pill(text:row.checked != nil ? (store.demo ? "Demo" : "Checked") : "Estimate",color:row.checked != nil ? Theme.teal : Theme.coral)}
                if let q=row.checked?.quote ?? row.calculated?.quote {Text("\(q.departure) – \(q.returning) · \(q.days)D\(q.days-1)N · \(Money.php((total+q.adults-1)/q.adults)) / person").font(.caption).foregroundColor(.secondary)}
                let savings=row.checked?.discount ?? row.calculated?.discount ?? 0
                if savings>0{Text("Includes \(Money.php(savings)) in confirmed voucher-code savings").font(.caption).foregroundColor(Theme.teal)}
            } else if let trip=row.calculated {
                Text("Incomplete · \(trip.missing.map(\.name).joined(separator:", ")) needed").font(.caption).foregroundColor(Theme.coral)
                Text("Known subtotal \(Money.php(trip.knownSubtotal)) · not ranked").font(.caption).foregroundColor(.secondary)
            } else {
                Text("Awaiting prices · not ranked").font(.caption).foregroundColor(.secondary)
            }
        }.padding(.vertical,8)
    }
}
struct CalculatedPriceDetail:View {
    @EnvironmentObject var store:AppStore
    let original:CalculatedTrip
    init(trip:CalculatedTrip){original=trip}
    private var trip:CalculatedTrip {store.calculated.first{$0.id==original.id} ?? original}
    @State private var editing=false
    @State private var job:ScanJob?
    @State private var candidate:PriceCandidate?
    @State private var settings=false
    private var q:TripQuote {trip.quote}
    var body:some View {
        List {
            Section {
                Text(Destination.find(q.destination)?.name ?? q.destination).font(.title2.bold())
                Text("MNL ↔ \(q.destination) · \(q.departure) – \(q.returning)").font(.caption)
                Text(trip.total.map{Money.php($0)} ?? "Incomplete total").font(.system(size:33,weight:.bold,design:.rounded)).foregroundColor(Theme.teal)
                if let per=trip.perPerson {Text("\(Money.php(per)) per person · \(q.adults) travelers · \(q.rooms) rooms").font(.caption)}
                Pill(text:"AUTOMATIC ESTIMATE",color:Theme.coral)
                Text("Lowest recognized price for each provider in this captured search. Dates, product options, fees and availability still need confirmation.").font(.caption).foregroundColor(.secondary)
            }
            Section("Provider prices · automatically multiplied") {
                ForEach(Provider.allCases){p in
                    if let part=trip.components[p] {
                        Button{candidate=part.candidate}label:{VStack(alignment:.leading,spacing:6){HStack{Text(p.name);Spacer();Text(Money.php(part.total)).bold()};Text(part.calculation).font(.caption).foregroundColor(.secondary);Text(part.candidate.context).font(.caption2).foregroundColor(.secondary).lineLimit(3)}}
                    } else if p == .activity && !trip.paidActivity {
                        amount("Free exploration · no paid activity",0)
                    } else {
                        Button{job=ScanJob(provider:p,destination:q.destination,departure:q.departure,returning:q.returning,adults:q.adults,rooms:q.rooms)}label:{HStack{Text(p.name);Spacer();Label("Find price",systemImage:"magnifyingglass")}}
                    }
                }
            }
            Section("Planning allowances · whole party") {
                amount("Airport transfers",q.transfers);amount("Baggage extras",q.baggage);amount("Other costs / visa / travel tax",q.otherCosts ?? 0)
                amount("Meals · \(q.days) days × \(q.adults)",trip.food);amount("Local transport · \(q.days) days × \(q.adults)",trip.localTransport)
                Button("Edit allowances"){settings=true}
                Text("Zero means no allowance has been added. It does not confirm that an extra is free or included. Avoid counting fees already in provider totals twice.").font(.caption).foregroundColor(.secondary)
            }
            Section("Voucher codes included in this calculation") {
                if trip.savings.isEmpty{Text("No confirmed code for this exact snapshot. Open Codes to check published offers and link an eligible code.").font(.caption).foregroundColor(.secondary)}
                ForEach(trip.savings,id:\.0.id){v,saving in amount("\(v.provider.name) · \(v.code)",-saving)}
                amount(trip.total == nil ? "Known subtotal · incomplete" : "Total after codes",trip.knownSubtotal)
            }
            Section {
                Button("Review and save complete quote"){editing=true}.disabled(trip.total==nil)
                Text("All arithmetic is done. Confirm the provider selections and mandatory charges before adding this trip to checked comparisons and your itinerary.").font(.caption).foregroundColor(.secondary)
            }
        }.navigationTitle("Price breakdown").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented:$editing){QuoteEditor(existing:q)}
        .sheet(isPresented:$settings){SettingsView()}
        .sheet(item:$job){ScannerView(store:store,initial:$0)}
        .sheet(item:$candidate){CaptureReviewView(candidate:$0)}
    }
    private func amount(_ title:String,_ cents:Int)->some View {HStack{Text(title).font(.subheadline);Spacer();Text(Money.php(cents)).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundColor(cents<0 ? Theme.teal : Theme.ink)}}
}
struct CaptureReviewView:View {
    @EnvironmentObject var store:AppStore
    @Environment(\.dismiss) private var dismiss
    let candidate:PriceCandidate
    @State private var basis=PriceBasis.unknown
    @State private var excluded=false
    private var updated:PriceCandidate {var c=candidate;c.basis=basis;c.excluded=excluded;return c}
    var body:some View {
        NavigationStack {Form {
            Section("Captured amount") {
                Text(Money.php(candidate.amount)).font(.largeTitle.bold())
                Text("\(candidate.job.provider.name) · MNL ↔ \(candidate.job.destination)")
                Text("\(candidate.job.departure) – \(candidate.job.returning) · \(candidate.job.adults) adults · \(candidate.job.rooms) rooms").font(.caption)
                Text(candidate.context).font(.caption).textSelection(.enabled)
                if let url=URL(string:candidate.url),ProviderLinks.allowed(url){Link("Open source page",destination:url)}
            }
            Section("What does this price cover?") {
                Picker("Price unit",selection:$basis){ForEach(PriceBasis.allCases){Text($0.label).tag($0)}}
                Toggle("Exclude this price from calculations",isOn:$excluded)
                if let part=PriceCalculator.component(updated){LabeledContent("Calculated group cost",value:Money.php(part.total));Text(part.calculation).font(.caption)}
                Text("Check dates, room occupancy and product options on the source. Choose Unknown for a one-way fare, discount amount, child fare or a teaser with no confirmed quantity. Saving recalculates the Prices page.").font(.caption).foregroundColor(.secondary)
            }
        }.navigationTitle("Review price unit").navigationBarTitleDisplayMode(.inline).toolbar{
            ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}
            ToolbarItem(placement:.confirmationAction){Button("Save"){store.revise(updated);dismiss()}}
        }.onAppear{basis=candidate.basis ?? PriceBasis.infer(candidate);excluded=candidate.excluded ?? false}}
    }
}
