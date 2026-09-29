import Foundation

public enum ManilaDate {
    public static var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Manila")!; return c }
    public static func string(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = calendar.timeZone; f.dateFormat = "yyyy-MM-dd"; return f.string(from: date) }
    public static func parse(_ s: String) -> Date? { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = calendar.timeZone; f.dateFormat = "yyyy-MM-dd"; f.isLenient = false; guard let d = f.date(from: s), string(d) == s else { return nil }; return d }
    public static func add(_ s: String, days: Int) -> String { guard let d = parse(s), let n = calendar.date(byAdding: .day, value: days, to: d) else { return s }; return string(n) }
    public static func days(_ start: String, _ end: String) -> Int? { guard let a = parse(start), let b = parse(end) else { return nil }; return calendar.dateComponents([.day], from: a, to: b).day }
}

public struct SearchSettings: Codable, Equatable {
    public var firstDeparture = ManilaDate.add(ManilaDate.string(Date()), days: 14)
    public var lastDeparture = ManilaDate.add(ManilaDate.string(Date()), days: 44)
    public var minDays = 3
    public var maxDays = 7
    public var adults = 1
    public var rooms = 1
    public var foodDaily = 35000
    public var transportDaily = 10000
    public var payment = "Any card"
    public var channel = "web"
    public var newCustomer = false
    public var includeExpired = false
    public init() {}
    public var validation: String? {
        guard let span = ManilaDate.days(firstDeparture, lastDeparture), span >= 0, span <= 365 else { return "Choose a departure window of up to 366 days." }
        guard (3...7).contains(minDays), (minDays...7).contains(maxDays) else { return "Trip lengths must be between 3 and 7 days." }
        guard (1...9).contains(adults), (1...9).contains(rooms), rooms <= adults else { return "Use 1–9 adults, with no more rooms than adults." }
        guard (0...10000000).contains(foodDaily), (0...10000000).contains(transportDaily) else { return "Daily budgets must be valid PHP amounts." }
        return nil
    }
    public func dates() -> [(String, String)] {
        guard validation == nil, let span = ManilaDate.days(firstDeparture, lastDeparture) else { return [] }
        return (0...span).flatMap { offset in (minDays...maxDays).map { duration in let start = ManilaDate.add(firstDeparture, days: offset); return (start, ManilaDate.add(start, days: duration - 1)) } }
    }
}

public struct Destination: Identifiable, Codable, Hashable {
    public var id: String { code }
    public let code: String
    public let name: String
    public let region: String
    public let symbol: String
    public let highlights: [String]
    public static let all: [Destination] = [
        .init(code:"BCD",name:"Bacolod",region:"Visayas",symbol:"fork.knife",highlights:["The Ruins","Lacson Street food walk","Silay heritage houses"]),
        .init(code:"BSO",name:"Basco",region:"Luzon",symbol:"mountain.2",highlights:["Basco lighthouse","Batan island viewpoints","Ivatan heritage walk"]),
        .init(code:"TAG",name:"Bohol",region:"Visayas",symbol:"leaf",highlights:["Chocolate Hills","Loboc River","Panglao beaches"]),
        .init(code:"MPH",name:"Boracay · Caticlan",region:"Visayas",symbol:"sun.max",highlights:["White Beach","Diniwid Beach","Island hopping"]),
        .init(code:"KLO",name:"Boracay · Kalibo",region:"Visayas",symbol:"sun.max",highlights:["White Beach","Diniwid Beach","Island hopping"]),
        .init(code:"BPR",name:"Borongan",region:"Visayas",symbol:"water.waves",highlights:["Baybay Boulevard","Eastern Samar beaches","Local food walk"]),
        .init(code:"BXU",name:"Butuan",region:"Mindanao",symbol:"building.columns",highlights:["Balangay museum","Agusan River","Butuan city walk"]),
        .init(code:"CGY",name:"Cagayan de Oro",region:"Mindanao",symbol:"water.waves",highlights:["City heritage walk","Whitewater rafting","Bukidnon day trip"]),
        .init(code:"CYP",name:"Calbayog",region:"Visayas",symbol:"drop",highlights:["Calbayog city walk","Waterfall day trip","Samar food trail"]),
        .init(code:"CGM",name:"Camiguin",region:"Mindanao",symbol:"mountain.2",highlights:["White Island","Katibawasan Falls","Hot spring stop"]),
        .init(code:"CRM",name:"Catarman",region:"Visayas",symbol:"sun.max",highlights:["Catarman town walk","Northern Samar coast","Local market"]),
        .init(code:"CYZ",name:"Cauayan",region:"Luzon",symbol:"leaf",highlights:["Cauayan heritage walk","Isabela countryside","Local food trail"]),
        .init(code:"CEB",name:"Cebu",region:"Visayas",symbol:"building.columns",highlights:["Old Cebu heritage walk","Moalboal day trip","Mactan coast"]),
        .init(code:"USU",name:"Coron",region:"Luzon",symbol:"water.waves",highlights:["Coron town and Mt. Tapyas","Island hopping","Maquinit hot spring"]),
        .init(code:"CBO",name:"Cotabato",region:"Mindanao",symbol:"building.columns",highlights:["City cultural tour","Tamontaka heritage stop","Local market"]),
        .init(code:"DRP",name:"Daraga · Legazpi",region:"Luzon",symbol:"mountain.2",highlights:["Cagsawa Ruins","Daraga Church","Legazpi boulevard"]),
        .init(code:"DVO",name:"Davao",region:"Mindanao",symbol:"leaf",highlights:["Davao city walk","Samal island day trip","Local food trail"]),
        .init(code:"DPL",name:"Dipolog",region:"Mindanao",symbol:"sun.max",highlights:["Dipolog Boulevard","Dapitan heritage walk","Dakak coast"]),
        .init(code:"DGT",name:"Dumaguete",region:"Visayas",symbol:"water.waves",highlights:["Rizal Boulevard","Apo Island day trip","Valencia countryside"]),
        .init(code:"ENI",name:"El Nido",region:"Luzon",symbol:"water.waves",highlights:["Island hopping","Nacpan Beach","El Nido town"]),
        .init(code:"GES",name:"General Santos",region:"Mindanao",symbol:"fork.knife",highlights:["Tuna food trail","Sarangani day trip","City park walk"]),
        .init(code:"ILO",name:"Iloilo",region:"Visayas",symbol:"building.columns",highlights:["Iloilo River Esplanade","Jaro and Molo heritage walk","Guimaras day trip"]),
        .init(code:"LAO",name:"Laoag",region:"Luzon",symbol:"sun.max",highlights:["Laoag city walk","Paoay heritage tour","Ilocos coastal drive"]),
        .init(code:"MBT",name:"Masbate",region:"Luzon",symbol:"sun.max",highlights:["Masbate city walk","Buntod sandbar","Local food trail"]),
        .init(code:"WNP",name:"Naga",region:"Luzon",symbol:"building.columns",highlights:["Naga heritage walk","Panicuason springs","Bicol food trail"]),
        .init(code:"OZC",name:"Ozamiz",region:"Mindanao",symbol:"building.columns",highlights:["Cotta Fort","Ozamiz city walk","Misamis countryside"]),
        .init(code:"PAG",name:"Pagadian",region:"Mindanao",symbol:"sun.max",highlights:["Pagadian city walk","Dao Dao island","Local food trail"]),
        .init(code:"PPS",name:"Puerto Princesa",region:"Luzon",symbol:"leaf",highlights:["City baywalk","Underground River tour","Honda Bay tour"]),
        .init(code:"RXS",name:"Roxas",region:"Visayas",symbol:"fork.knife",highlights:["Baybay seafood stop","Roxas heritage walk","Panay Church"]),
        .init(code:"SJI",name:"San Jose · Mindoro",region:"Luzon",symbol:"sun.max",highlights:["San Jose town walk","Mindoro coast","Local food trail"]),
        .init(code:"SWL",name:"San Vicente",region:"Luzon",symbol:"sun.max",highlights:["Long Beach","Port Barton","Island hopping"]),
        .init(code:"IAO",name:"Siargao",region:"Mindanao",symbol:"water.waves",highlights:["General Luna","Island hopping","Magpupungko area"]),
        .init(code:"SUG",name:"Surigao",region:"Mindanao",symbol:"water.waves",highlights:["Surigao city walk","Mabua coast","Local market"]),
        .init(code:"TAC",name:"Tacloban",region:"Visayas",symbol:"building.columns",highlights:["San Juanico area","MacArthur Landing Memorial","Tacloban city walk"]),
        .init(code:"TWT",name:"Tawi-Tawi",region:"Mindanao",symbol:"mountain.2",highlights:["Bongao cultural tour","Bud Bongao","Local market"]),
        .init(code:"TUG",name:"Tuguegarao",region:"Luzon",symbol:"mountain.2",highlights:["Callao Cave","Cagayan food trail","City heritage walk"]),
        .init(code:"VRC",name:"Virac",region:"Luzon",symbol:"water.waves",highlights:["Virac town walk","Catanduanes coast","Rolling hills day trip"]),
        .init(code:"ZAM",name:"Zamboanga",region:"Mindanao",symbol:"building.columns",highlights:["Paseo del Mar","Fort Pilar","Local food trail"])
    ]
    public static func find(_ code: String) -> Destination? { all.first { $0.code == code } }
}

public enum Provider: String, Codable, CaseIterable, Identifiable { case flight, hotel, activity; public var id:String { rawValue }; public var name:String { switch self { case .flight:return "Cebu Pacific";case .hotel:return "Agoda";case .activity:return "Klook" } } }
public enum QuoteSource: String, Codable { case manual, partner, imported, demo }
public struct TripQuote: Codable, Identifiable, Equatable {
    public var id = UUID().uuidString
    public var origin = "MNL"
    public var destination = "CEB"
    public var departure = ""
    public var returning = ""
    public var adults = 1
    public var rooms = 1
    public var currency = "PHP"
    public var flight = 0
    public var hotel = 0
    public var activity = 0
    public var transfers = 0
    public var baggage = 0
    public var hotelName = "Agoda stay"
    public var activityName = "Free time / no paid tour"
    public var mandatoryFeesIncluded = false
    public var source: QuoteSource = .manual
    public var checkedAt = Date()
    public var expiresAt = Date().addingTimeInterval(3600)
    public var includedVoucherCodes: [String] = []
    public var note = ""
    public init() {}
    public var days:Int { (ManilaDate.days(departure, returning) ?? -1) + 1 }
    public var validation:String? {
        guard origin == "MNL", currency == "PHP", Destination.find(destination) != nil else { return "Only MNL round trips to the Philippine catalog in PHP are supported." }
        guard (3...7).contains(days), (1...9).contains(adults), (1...adults).contains(rooms) else { return "Quote dates or party size are invalid." }
        guard flight > 0, hotel > 0, [flight,hotel,activity,transfers,baggage].allSatisfy({ (0...1000000000).contains($0) }) else { return "Complete flight and hotel prices are needed." }
        guard mandatoryFeesIncluded else { return "Confirm that mandatory taxes, fees, and transfers are included." }
        guard expiresAt >= checkedAt else { return "Quote expiry must follow its checked time." }
        return nil
    }
    public func amount(_ provider:Provider) -> Int { switch provider { case .flight:return flight; case .hotel:return hotel; case .activity:return activity } }
}

public struct Voucher: Codable, Identifiable, Equatable {
    public var id = UUID().uuidString
    public var code = ""
    public var provider: Provider = .hotel
    public var percentage = false
    // basis points for percentages (1000 = 10%), centavos for fixed discounts
    public var value = 0
    public var cap = 0
    public var minSpend = 0
    public var bookingStart = ""
    public var bookingEnd = ""
    public var travelStart = ""
    public var travelEnd = ""
    public var channel = "any"
    public var payment = "Any card"
    public var newCustomerOnly = false
    public var confirmed = false
    public var eligibleQuoteIDs: [String] = []
    public var sourceURL = ""
    public init() {}
    public func saving(for quote:TripQuote, settings:SearchSettings, now:Date) -> Int {
        let today = ManilaDate.string(now)
        guard confirmed, !code.trimmingCharacters(in:.whitespaces).isEmpty, eligibleQuoteIDs.contains(quote.id), !quote.includedVoucherCodes.contains(where: {$0.caseInsensitiveCompare(code) == .orderedSame}), now <= quote.expiresAt, quote.checkedAt <= now.addingTimeInterval(300) else { return 0 }
        guard !bookingStart.isEmpty, !bookingEnd.isEmpty, !travelStart.isEmpty, !travelEnd.isEmpty,
              [bookingStart,bookingEnd,travelStart,travelEnd].allSatisfy({ManilaDate.parse($0) != nil}),
              today >= bookingStart, today <= bookingEnd, quote.departure >= travelStart, quote.returning <= travelEnd,
              channel == "any" || channel == settings.channel, payment == "Any card" || payment == settings.payment,
              !newCustomerOnly || settings.newCustomer else { return 0 }
        let base = quote.amount(provider)
        guard base >= minSpend, minSpend >= 0, cap >= 0, value > 0, value <= (percentage ? 10000 : 1000000000) else { return 0 }
        let raw = percentage ? base * value / 10000 : value
        return max(0, min(base, cap > 0 ? min(raw, cap) : raw))
    }
}

public struct RankedTrip: Identifiable {
    public var id: String { quote.id }
    public let quote: TripQuote
    public let savings: [(Voucher,Int)]
    public let food: Int
    public let localTransport: Int
    public var discount:Int { savings.reduce(0) {$0 + $1.1} }
    public var total:Int { quote.flight + quote.hotel + quote.activity + quote.transfers + quote.baggage + food + localTransport - discount }
    public var perPerson:Int { (total + quote.adults - 1) / quote.adults }
}
public enum Ranking {
    public static func calculate(_ quotes:[TripQuote], vouchers:[Voucher], settings:SearchSettings, now:Date = Date(), demo:Bool = false) -> [RankedTrip] {
        guard settings.validation == nil else { return [] }
        return quotes.filter { q in
            q.validation == nil && (q.source == .demo) == demo && q.adults == settings.adults && q.rooms == settings.rooms &&
            q.departure >= settings.firstDeparture && q.departure <= settings.lastDeparture && (settings.minDays...settings.maxDays).contains(q.days) &&
            q.checkedAt <= now.addingTimeInterval(300) && (settings.includeExpired || q.expiresAt >= now)
        }.map { q in
            let best:[(Voucher,Int)] = Provider.allCases.compactMap { p in
                vouchers.filter {$0.provider == p}.map {($0,$0.saving(for:q,settings:settings,now:now))}.filter {$0.1 > 0}.sorted { a,b in a.1 == b.1 ? a.0.code < b.0.code : a.1 > b.1 }.first
            }
            return RankedTrip(quote:q,savings:best,food:settings.foodDaily*q.days*q.adults,localTransport:settings.transportDaily*q.days*q.adults)
        }.sorted { a,b in a.total == b.total ? a.id < b.id : a.total < b.total }
    }
    public static func cheapestPerDestination(_ trips:[RankedTrip]) -> [RankedTrip] { var seen = Set<String>(); return trips.filter {seen.insert($0.quote.destination).inserted} }
}
public enum Money {
    public static func php(_ cents:Int) -> String { let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "PHP"; f.currencySymbol = "₱"; f.maximumFractionDigits = cents % 100 == 0 ? 0 : 2; return f.string(from:NSNumber(value:Double(cents)/100)) ?? "₱0" }
    public static func parse(_ input:String) -> Int? { let s = input.replacingOccurrences(of:",",with:"").trimmingCharacters(in:.whitespaces); guard s.range(of:"^[0-9]+(?:\\.[0-9]{1,2})?$",options:.regularExpression) != nil, let d = Decimal(string:s,locale:Locale(identifier:"en_US_POSIX")), d >= 0, d <= 10000000 else {return nil}; var v = d*100; var r=Decimal(); NSDecimalRound(&r,&v,0,.plain); return NSDecimalNumber(decimal:r).intValue }
}
