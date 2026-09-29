import SwiftUI

@main struct GalaGoApp:App {
    @StateObject private var store=AppStore()
    var body:some Scene {WindowGroup{RootView().environmentObject(store).tint(Theme.teal).preferredColorScheme(.light)}}
}
enum Theme {
    static let teal=Color(red:0.02,green:0.40,blue:0.39)
    static let ink=Color(red:0.07,green:0.18,blue:0.23)
    static let paper=Color(red:0.97,green:0.96,blue:0.92)
    static let coral=Color(red:0.96,green:0.39,blue:0.26)
}
struct RootView:View {
    @EnvironmentObject var store:AppStore
    @State private var tab=CommandLine.arguments.contains("--demo") ? 1 : 0
    var body:some View {
        TabView(selection:$tab) {
            DiscoverView().tag(0).tabItem{Label("Discover",systemImage:"sparkles")}
            CompareView().tag(1).tabItem{Label("Compare",systemImage:"chart.bar.xaxis")}
            VoucherListView().tag(2).tabItem{Label("Vouchers",systemImage:"ticket")}
            SavedView().tag(3).tabItem{Label("Saved",systemImage:"bookmark")}
        }.onAppear{if CommandLine.arguments.contains("--demo"){store.demo=true}}.alert("GalaGo",isPresented:Binding(get:{store.toast != nil},set:{if !$0{store.toast=nil}})){Button("OK"){store.toast=nil}}message:{Text(store.toast ?? "")}
    }
}
struct BrandHero:View {
    var body:some View {
        ZStack(alignment:.leading) {
            RoundedRectangle(cornerRadius:28).fill(Theme.teal.gradient)
            GeometryReader{geo in
                ZStack {
                    Circle().fill(Color(red:1,green:0.79,blue:0.35)).frame(width:65,height:65).position(x:geo.size.width-52,y:44)
                    Ellipse().fill(Color.white.opacity(0.10)).frame(width:230,height:90).rotationEffect(.degrees(-28)).position(x:geo.size.width-28,y:132)
                    Image(systemName:"airplane").font(.system(size:62,weight:.bold)).rotationEffect(.degrees(-30)).foregroundColor(.white.opacity(0.90)).position(x:geo.size.width-78,y:133)
                }.clipped()
            }
            VStack(alignment:.leading,spacing:10) {
                HStack(spacing:4){Image(systemName:"location.north.circle.fill");Text("GalaGo").font(.system(size:28,weight:.heavy,design:.rounded))}.foregroundColor(.white)
                Text("More gala.\nLess gastos.").font(.system(size:30,weight:.bold,design:.rounded)).foregroundColor(.white)
                Text("MANILA TO THE PHILIPPINES").font(.system(size:10,weight:.bold)).tracking(1.5).foregroundColor(.white.opacity(0.8))
            }.padding(24)
        }.frame(height:218).accessibilityElement(children:.combine)
    }
}
struct Pill:View {
    let text:String
    var color:Color=Theme.teal
    var body:some View{Text(text).font(.caption2.weight(.semibold)).padding(.horizontal,9).padding(.vertical,5).foregroundColor(color).background(color.opacity(0.09),in:Capsule())}
}
struct Card<Content:View>:View {
    @ViewBuilder var content:Content
    var body:some View{VStack(alignment:.leading,spacing:12){content}.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:22))}
}
struct DiscoverView:View {
    @EnvironmentObject var store:AppStore
    @State private var settings=false
    @State private var scanner=false
    @State private var manual=false
    @State private var selected="ALL"
    @State private var query=""
    @State private var candidate:PriceCandidate?
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:18) {
                    BrandHero()
                    Card {
                        HStack{Pill(text:"MNL ROUND TRIP");Pill(text:"3–7 DAYS");Spacer();Button{settings=true}label:{Image(systemName:"slider.horizontal.3")}.accessibilityLabel("Search settings")}
                        Text("Find your next escape").font(.title3.bold()).foregroundColor(Theme.ink)
                        Text("\(store.state.settings.firstDeparture) — \(store.state.settings.lastDeparture)").font(.subheadline)
                        Text("\(store.state.settings.adults) adult(s) · \(store.state.settings.rooms) room(s) · PHP totals").font(.caption).foregroundColor(.secondary)
                        Picker("Destinations",selection:$selected){Text("All 38 destination airports").tag("ALL");ForEach(Destination.all){Text("\($0.name) · \($0.code)").tag($0.code)}}.tint(Theme.ink)
                        Button {guard store.state.settings.validation==nil else{store.toast=store.state.settings.validation;return};store.makePlan(destinations:selected=="ALL" ? Destination.all.map(\.code) : [selected]);scanner=true} label:{Label("Search public pages",systemImage:"magnifyingglass").font(.headline).frame(maxWidth:.infinity).padding(.vertical,8)}.buttonStyle(.borderedProminent)
                        Text("Scans Cebu Pacific, Agoda and Klook in saved batches. Keep the scanner open. Review price candidates before ranking.").font(.caption).foregroundColor(.secondary)
                    }
                    HStack(spacing:10){ForEach(Provider.allCases){p in Pill(text:p.name)}}
                    if !store.state.jobs.isEmpty {Card{HStack{Text("Your search progress").font(.headline);Spacer();Button("Resume"){scanner=true}};let done=store.state.jobs.filter{$0.status=="done" || $0.status=="review"}.count;ProgressView(value:Double(done),total:Double(max(1,store.state.jobs.count))).tint(Theme.teal);Text("\(done) / \(store.state.jobs.count) pages checked · \(store.state.candidates.count) candidates").font(.caption);Text("Search coverage is partial until every page is checked. Candidate prices can omit taxes, use per-night rates or require a different date.").font(.caption).foregroundColor(.secondary)}}
                    if !store.state.candidates.isEmpty {Card{Text("Recent captures for review").font(.headline);NavigationLink("View all captured prices"){CapturesView()};Text("Up to 3,000 recent candidates are kept. Save full quotes to retain prices you want to compare.").font(.caption).foregroundColor(.secondary);ForEach(Array(store.state.candidates.suffix(8).reversed())){item in Button{candidate=item}label:{HStack{VStack(alignment:.leading){Text("\(item.job.destination) · \(item.job.provider.name)").font(.subheadline.bold());Text(item.context).font(.caption).lineLimit(2).foregroundColor(.secondary)};Spacer();Text(Money.php(item.amount)).font(.subheadline.bold())}}}}}
                    Card {
                        HStack{Text("Build a complete comparison").font(.headline);Spacer();Image(systemName:"plus.circle.fill").foregroundColor(Theme.coral)}
                        Text("Add the actual checkout totals for your party. Include taxes, required fees, baggage and transfers.").font(.subheadline).foregroundColor(.secondary)
                        Button("Add a trip quote"){manual=true}.buttonStyle(.bordered)
                    }
                    VStack(alignment:.leading,spacing:12){Text("Explore the islands").font(.title2.bold()).foregroundColor(Theme.ink);Text("Destination catalog; flight service from MNL must be checked. Some airports may require a connection or have no available route.").font(.caption).foregroundColor(.secondary);ForEach(Destination.all.filter{query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.code.localizedCaseInsensitiveContains(query)}){d in NavigationLink{DestinationView(destination:d)}label:{HStack(spacing:14){Image(systemName:d.symbol).font(.title3).frame(width:44,height:44).foregroundColor(Theme.teal).background(Theme.teal.opacity(0.08),in:RoundedRectangle(cornerRadius:14));VStack(alignment:.leading,spacing:4){Text(d.name).font(.headline).foregroundColor(Theme.ink);Text("\(d.region) · \(d.code)").font(.caption).foregroundColor(.secondary)};Spacer();Image(systemName:"chevron.right").font(.caption).foregroundColor(.secondary)}.padding(13).background(.white,in:RoundedRectangle(cornerRadius:18))}}}
                }.padding(18)
            }.background(Theme.paper).navigationTitle("GalaGo").navigationBarTitleDisplayMode(.inline)
            .toolbar{ToolbarItem(placement:.primaryAction){Button{settings=true}label:{Image(systemName:"slider.horizontal.3")}}}
            .searchable(text:$query,prompt:"Find an island or city")
            .sheet(isPresented:$settings){SettingsView()}
            .sheet(isPresented:$scanner){ScannerView(store:store)}
            .sheet(isPresented:$manual){QuoteEditor()}
            .sheet(item:$candidate){QuoteEditor(candidate:$0)}
        }
    }
}
struct CompareView:View {
    @EnvironmentObject var store:AppStore
    @State private var allDates=false
    @State private var editor=false
    @State private var settings=false
    var body:some View {
        NavigationStack{ScrollView{VStack(alignment:.leading,spacing:16){
            Text("Small budget.\nBig possibilities.").font(.system(size:31,weight:.bold,design:.rounded)).foregroundColor(Theme.ink)
            Toggle("Show illustrative examples",isOn:$store.demo).font(.subheadline)
            if store.demo {Label("DEMO PRICES · NOT LIVE OR BOOKABLE",systemImage:"info.circle.fill").font(.caption.bold()).foregroundColor(Theme.coral)}
            HStack{Pill(text:"SORTED BY TOTAL");Spacer();Button{settings=true}label:{Label("Filters",systemImage:"line.3.horizontal.decrease")}}
            Toggle("Show every date option",isOn:$allDates).font(.subheadline)
            Text("\(store.destinations.count) of 38 destination airports have matching complete quotes. Cheapest among available quotes; coverage is not exhaustive.").font(.caption).foregroundColor(.secondary)
            if store.ranked.isEmpty {Card{Image(systemName:"airplane.circle").font(.largeTitle).foregroundColor(Theme.teal);Text("Your first comparison is waiting").font(.title3.bold());Text("Capture provider prices in Discover, then add the full trip totals. Unknown or incomplete prices never become a ₱0 deal.").font(.subheadline).foregroundColor(.secondary);Button("Add a trip quote"){editor=true}.buttonStyle(.borderedProminent)}}
            ForEach(Array((allDates ? store.ranked : store.destinations).enumerated()),id:\.element.id){index,trip in NavigationLink{TripDetail(trip:trip)}label:{TripCard(trip:trip,rank:index+1)}}
            Text("Totals include your editable meal and local transport budgets. Cashback and unconfirmed voucher codes are excluded from what you pay.").font(.caption).foregroundColor(.secondary)
        }.padding(20)}.background(Theme.paper).navigationTitle("Cheapest escapes").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.primaryAction){Button{editor=true}label:{Image(systemName:"plus")}}}.sheet(isPresented:$editor){QuoteEditor()}.sheet(isPresented:$settings){SettingsView()}}
    }
}
struct TripCard:View {
    let trip:RankedTrip
    let rank:Int
    var body:some View{Card{
        HStack{Pill(text:"#\(rank) LOWEST TOTAL");Spacer();Pill(text:trip.quote.source == .demo ? "Example" : trip.quote.expiresAt<Date() ? "Expired" : trip.quote.source == .manual ? "User checked" : "Imported",color:trip.quote.source == .demo ? Theme.coral : Theme.teal)}
        HStack{VStack(alignment:.leading,spacing:5){Text(Destination.find(trip.quote.destination)?.name ?? trip.quote.destination).font(.title2.bold()).foregroundColor(Theme.ink);Text("MNL ↔ \(trip.quote.destination) · \(trip.quote.days)D\(trip.quote.days-1)N").font(.caption).foregroundColor(.secondary)};Spacer();Image(systemName:Destination.find(trip.quote.destination)?.symbol ?? "airplane").font(.largeTitle).foregroundColor(Theme.teal)}
        Text("\(trip.quote.departure) – \(trip.quote.returning)").font(.subheadline).foregroundColor(.secondary)
        Divider()
        HStack(alignment:.firstTextBaseline){Text(Money.php(trip.total)).font(.system(size:30,weight:.bold,design:.rounded)).foregroundColor(Theme.ink);Spacer();Text("\(Money.php(trip.perPerson)) / person").font(.caption).foregroundColor(.secondary)}
        Text("Total for \(trip.quote.adults) · flight + stay + activities + daily budgets").font(.caption2).foregroundColor(.secondary)
        if trip.discount>0 {Pill(text:"\(Money.php(trip.discount)) confirmed savings")}
    }.multilineTextAlignment(.leading)}
}
