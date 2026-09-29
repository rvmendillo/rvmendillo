import SwiftUI
import UniformTypeIdentifiers

struct LocalState: Codable {
    var settings = SearchSettings()
    var quotes:[TripQuote] = []
    var vouchers:[Voucher] = []
    var favorites:[String] = []
    var plans:[String:[String]] = [:]
    var jobs:[ScanJob] = []
    var candidates:[PriceCandidate] = []
    var cooldowns:[String:Date] = [:]
    var promoHints:[PromoHint] = []
}
@MainActor final class AppStore: ObservableObject {
    @Published var state = LocalState()
    @Published var toast:String? = nil
    @Published var demo = false
    private let file = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("galago-state.json")
    static let encoder:JSONEncoder = {let e=JSONEncoder();e.dateEncodingStrategy = .iso8601;e.outputFormatting=[.prettyPrinted,.sortedKeys];return e}()
    static let decoder:JSONDecoder = {let d=JSONDecoder();d.dateDecodingStrategy = .iso8601;return d}()
    init() {
        if let data=try? Data(contentsOf:file) {do {state=try Self.decoder.decode(LocalState.self,from:data)} catch {toast="Saved data could not be loaded. Your file has been kept for recovery."}}
        for i in state.jobs.indices where state.jobs[i].status == "running" {state.jobs[i].status="queued"}
    }
    func save() {do {try Self.encoder.encode(state).write(to:file,options:[.atomic,.completeFileProtection])} catch {toast="Could not save changes: \(error.localizedDescription)"}}
    var ranked:[RankedTrip] {Ranking.calculate(demo ? examples : state.quotes,vouchers:state.vouchers,settings:state.settings,demo:demo)}
    var destinations:[RankedTrip] {Ranking.cheapestPerDestination(ranked)}
    var examples:[TripQuote] {
        ["ILO","CEB","DVO","MPH","PPS","TAG"].enumerated().map { i,code in
            var q=TripQuote();q.id="example-\(code)";q.destination=code;q.departure=state.settings.firstDeparture;q.returning=ManilaDate.add(q.departure,days:state.settings.minDays-1);q.adults=state.settings.adults;q.rooms=state.settings.rooms
            q.flight=(240000+i*39000)*q.adults;q.hotel=(110000+i*15000)*(q.days-1)*q.rooms;q.activity=75000*q.adults;q.transfers=45000*q.adults;q.mandatoryFeesIncluded=true;q.source = .demo;q.hotelName="Illustrative budget stay";q.activityName="Illustrative day tour";return q
        }
    }
    func upsert(_ quote:TripQuote) {invalidateVouchers(for:quote.id);if let i=state.quotes.firstIndex(where:{$0.id==quote.id}){state.quotes[i]=quote}else{state.quotes.append(quote)};demo=false;save()}
    func invalidateVouchers(for id:String) {for i in state.vouchers.indices {state.vouchers[i].eligibleQuoteIDs.removeAll{$0==id};if state.vouchers[i].eligibleQuoteIDs.isEmpty{state.vouchers[i].confirmed=false}}}
    func toggleFavorite(_ id:String) {if state.favorites.contains(id){state.favorites.removeAll{$0==id}}else{state.favorites.append(id)};save()}
    func makePlan(destinations:[String]) {
        let jobs=ScanPlan.jobs(settings:state.settings,destinations:destinations)
        let old=Dictionary(state.jobs.map{($0.id,$0)},uniquingKeysWith: {first,_ in first})
        state.jobs=jobs.map {job in guard var prior=old[job.id] else{return job};if prior.status=="done" && (state.candidates.filter{$0.job.id==job.id}.map(\.capturedAt).max() ?? .distantPast) < Date().addingTimeInterval(-3600){prior.status="queued";prior.attempts=0};return prior}
        save()
    }
    func importQuotes(_ url:URL) {
        let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}}
        do {let data=try Data(contentsOf:url);guard data.count<=5_000_000 else {toast="Import a JSON file smaller than 5 MB.";return};let quotes=try Self.decoder.decode([TripQuote].self,from:data);var added=0;for var q in quotes.prefix(5000) {guard q.validation==nil, q.source != .demo else {continue};q.source = .imported;invalidateVouchers(for:q.id);if let i=state.quotes.firstIndex(where:{$0.id==q.id}){state.quotes[i]=q}else{state.quotes.append(q)};added+=1};save();toast="Imported \(added) complete quotes. \(quotes.count-added) invalid or demo entries skipped."}catch{toast="Could not import this JSON file: \(error.localizedDescription)"}
    }
}
struct JSONDocument: FileDocument {
    static var readableContentTypes:[UTType]{[.json]}
    var data:Data
    init(data:Data){self.data=data}
    init(configuration:ReadConfiguration)throws{data=configuration.file.regularFileContents ?? Data()}
    func fileWrapper(configuration:WriteConfiguration)throws->FileWrapper{FileWrapper(regularFileWithContents:data)}
}
