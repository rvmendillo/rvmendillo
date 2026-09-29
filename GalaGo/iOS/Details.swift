import SwiftUI
import UniformTypeIdentifiers

struct DestinationView:View {
    @EnvironmentObject var store:AppStore
    let destination:Destination
    @State private var editor=false
    @State private var job:ScanJob?
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:20){
        ZStack{RoundedRectangle(cornerRadius:28).fill(Theme.teal.gradient);VStack(spacing:12){Image(systemName:destination.symbol).font(.system(size:58));Text(destination.name).font(.largeTitle.bold());Text("MNL ↔ \(destination.code) · \(destination.region)").font(.subheadline)}}.foregroundColor(.white).frame(height:230)
        Text("Plan your escape").font(.title2.bold())
        ForEach(Provider.allCases){p in Button{job=ScanJob(provider:p,destination:destination.code,departure:store.state.settings.firstDeparture,returning:ManilaDate.add(store.state.settings.firstDeparture,days:store.state.settings.minDays-1),adults:store.state.settings.adults,rooms:store.state.settings.rooms)}label:{HStack{Label(p.name,systemImage:p == .flight ? "airplane" : p == .hotel ? "bed.double" : "ticket");Spacer();Image(systemName:"arrow.up.right")}.padding().background(.white,in:RoundedRectangle(cornerRadius:16))}}
        Text("These links request your search details. Confirm them on the provider page. A listed airport is not a guarantee of a Cebu Pacific route from MNL.").font(.caption).foregroundColor(.secondary)
        Card{Text("Ideas for your itinerary").font(.headline);ForEach(destination.highlights,id:\.self){Text("• \($0)").font(.subheadline)};Text("Suggestions only. Check opening times, access and travel time. Paid options need a separate quote.").font(.caption).foregroundColor(.secondary)}
        Button("Add complete trip quote"){editor=true}.buttonStyle(.borderedProminent).frame(maxWidth:.infinity)
    }.padding(20)}.background(Theme.paper).navigationTitle(destination.name).navigationBarTitleDisplayMode(.inline).sheet(isPresented:$editor){QuoteEditor(destination:destination.code)}.sheet(item:$job){ScannerView(store:store,initial:$0)}}
}
struct TripDetail:View {
    @EnvironmentObject var store:AppStore
    let original:RankedTrip
    init(trip:RankedTrip){self.original=trip}
    private var trip:RankedTrip {
        guard let current=store.state.quotes.first(where:{$0.id==original.id}) else{return original}
        var settings=store.state.settings
        settings.firstDeparture=current.departure;settings.lastDeparture=current.departure
        settings.minDays=current.days;settings.maxDays=current.days
        settings.adults=current.adults;settings.rooms=current.rooms;settings.includeExpired=true
        return Ranking.calculate([current],vouchers:store.state.vouchers,settings:settings).first ?? original
    }
    @State private var editing=false
    @State private var plan:[String]=[]
    private var q:TripQuote{trip.quote}
    private var destination:Destination?{Destination.find(q.destination)}
    private var shareText:String {"GalaGo · \(destination?.name ?? q.destination)\nMNL ↔ \(q.destination) · \(q.departure) to \(q.returning)\n\(q.days) days / \(q.days-1) nights · \(q.adults) adult(s), \(q.rooms) room(s)\nPlanning total: \(Money.php(trip.total)) · \(Money.php(trip.perPerson)) per person\nChecked: \(q.checkedAt.formatted())\nSnapshot only. Recheck prices and availability at checkout.\n\n"+plan.enumerated().map{"Day \($0.offset+1): \($0.element)"}.joined(separator:"\n")}
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:18){
        TripCard(trip:trip,rank:(store.destinations.firstIndex(where:{$0.quote.destination==q.destination}) ?? 0)+1)
        Card{
            Text("Every peso accounted for").font(.headline)
            cost("Cebu Pacific · return flights",q.flight)
            cost("Agoda · \(q.days-1) nights, \(q.rooms) room(s)",q.hotel)
            cost("Klook / selected activities",q.activity)
            cost("Airport transfers · both ways",q.transfers)
            cost("Extra baggage · both ways",q.baggage)
            cost("Meals · \(q.days) days",trip.food)
            cost("Local transport · \(q.days) days",trip.localTransport)
            ForEach(trip.savings,id:\.0.id){v,value in cost("\(v.provider.name) · \(v.code)",-value)}
            Divider();cost("Total for \(q.adults) traveler(s)",trip.total,bold:true)
            Text("Flights and hotel already include mandatory charges as confirmed by the quote author. Meals and local transport are your estimates. Cashback is excluded.").font(.caption).foregroundColor(.secondary)
        }
        Card{Text("Your stay & experience").font(.headline);Label(q.hotelName,systemImage:"bed.double");Label(q.activityName,systemImage:"ticket");if !q.note.isEmpty{Text(q.note).font(.caption).foregroundColor(.secondary)}}
        HStack{Text("Your day-by-day plan").font(.title2.bold());Spacer();Image(systemName:"pencil").foregroundColor(Theme.teal)}
        Text("Edit each day. Suggested activities are not reservations; additional paid activities are not included in this total.").font(.caption).foregroundColor(.secondary)
        ForEach(plan.indices,id:\.self){i in Card{HStack{Pill(text:"DAY \(i+1)");Text(ManilaDate.add(q.departure,days:i)).font(.caption).foregroundColor(.secondary)};TextField("Plan for this day",text:$plan[i],axis:.vertical).lineLimit(3...8)}}
        HStack{
            Button("Save itinerary"){store.state.plans[q.id]=plan;if !store.state.favorites.contains(q.id){store.state.favorites.append(q.id)};store.save();store.toast="Itinerary saved."}.buttonStyle(.borderedProminent).disabled(q.source == .demo)
            ShareLink(item:shareText){Image(systemName:"square.and.arrow.up").padding(10)}
        }
        Text("Checked \(q.checkedAt.formatted(date:.abbreviated,time:.shortened)). Recheck after \(q.expiresAt.formatted(date:.abbreviated,time:.shortened)).").font(.caption).foregroundColor(.secondary)
    }.padding(20)}.background(Theme.paper).navigationTitle(destination?.name ?? q.destination).navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.primaryAction){Button("Edit quote"){editing=true}.disabled(q.source == .demo)}}.sheet(isPresented:$editing){QuoteEditor(existing:q)}.onAppear{plan=store.state.plans[q.id] ?? defaultPlan}.onChange(of:q.days){_ in plan=defaultPlan}}
    private func cost(_ title:String,_ value:Int,bold:Bool=false)->some View{HStack(alignment:.firstTextBaseline){Text(title).font(bold ? .headline : .subheadline);Spacer();Text(Money.php(value)).font(bold ? .headline : .subheadline).monospacedDigit().foregroundColor(value<0 ? Theme.teal : Theme.ink)}}
    private var defaultPlan:[String]{(0..<q.days).map { i in if i==0{return "Fly MNL → \(q.destination). Airport transfer and check-in at \(q.hotelName). Easy local walk and dinner."};if i==q.days-1{return "Check out. Leave time for your airport transfer and airline check-in. Fly \(q.destination) → MNL."};if i==1 && q.activity>0{return "\(q.activityName). Confirm the tour schedule, meeting point, transport and inclusions before booking."};let ideas=destination?.highlights ?? ["Local exploration"];return "Flexible day: \(ideas[(i-1)%ideas.count]). Optional idea; price any paid entry or tour before adding it to your budget."}}
}
struct SavedView:View {
    @EnvironmentObject var store:AppStore
    @State private var importing=false
    @State private var exporting=false
    @State private var showAll=true
    @State private var document=JSONDocument(data:Data())
    @State private var edit:TripQuote?
    var body:some View{NavigationStack{List{
        Section{Text("Your travel notebook").font(.title2.bold());Text("Quotes and itineraries stay on this device. Export quotes as JSON for a backup or to bring in prices from your own data source.").font(.subheadline).foregroundColor(.secondary);HStack{Button("Import quotes"){importing=true}.buttonStyle(.bordered);Button("Export quotes"){document=JSONDocument(data:(try? AppStore.encoder.encode(store.state.quotes)) ?? Data());exporting=true}.buttonStyle(.bordered)}}
        Section{Toggle("Show all saved quotes",isOn:$showAll)}
        Section("Trip quotes"){ForEach(store.state.quotes.filter{showAll || store.state.favorites.contains($0.id)}){q in NavigationLink{if let saved=savedTrip(q){TripDetail(trip:saved)}else{Text("This quote needs to be rechecked.")}}label:{HStack{VStack(alignment:.leading,spacing:5){Text(Destination.find(q.destination)?.name ?? q.destination).font(.headline);Text("\(q.departure) · \(q.days) days · \(q.adults) traveler(s)").font(.caption).foregroundColor(.secondary);if q.expiresAt<Date(){Text("Recheck price · expired snapshot").font(.caption).foregroundColor(Theme.coral)}};Spacer();Image(systemName:store.state.favorites.contains(q.id) ? "bookmark.fill" : "pencil")}}.swipeActions{Button(role:.destructive){store.state.quotes.removeAll{$0.id==q.id};store.state.favorites.removeAll{$0==q.id};store.state.plans.removeValue(forKey:q.id);store.save()}label:{Label("Delete",systemImage:"trash")};Button{store.toggleFavorite(q.id)}label:{Label("Save",systemImage:"bookmark")}.tint(Theme.teal)}};if store.state.quotes.isEmpty{Text("Saved trip quotes will appear here.").foregroundColor(.secondary)}}
        Section("About GalaGo"){Text("Version 1.0 · More gala. Less gastos.");Text("Independent planning app. Not affiliated with Cebu Pacific, Agoda or Klook. Provider names identify the source of offers.").font(.caption).foregroundColor(.secondary);Text("Searches run in the foreground, in batches of 20 pages. Network deadlines end a page attempt, not the saved search. Rate limits and verification screens may pause scanning.").font(.caption).foregroundColor(.secondary)}
    }.navigationTitle("Saved").sheet(item:$edit){QuoteEditor(existing:$0)}.fileImporter(isPresented:$importing,allowedContentTypes:[.json]){result in switch result{case .success(let url):store.importQuotes(url);case .failure(let error):store.toast=error.localizedDescription}}.fileExporter(isPresented:$exporting,document:document,contentType:.json,defaultFilename:"GalaGo-quotes"){result in if case .failure(let error)=result{store.toast=error.localizedDescription}}}}
    private func savedTrip(_ q:TripQuote)->RankedTrip? {
        var settings=store.state.settings
        settings.firstDeparture=q.departure;settings.lastDeparture=q.departure
        settings.minDays=q.days;settings.maxDays=q.days
        settings.adults=q.adults;settings.rooms=q.rooms;settings.includeExpired=true
        return Ranking.calculate([q],vouchers:store.state.vouchers,settings:settings).first
    }

}
