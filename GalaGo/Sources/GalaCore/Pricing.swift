import Foundation

public struct ExtraBudget: Codable, Equatable {
    public var transfers = 0
    public var baggage = 0
    public var other = 0
    public var paidActivity = true
    public init() {}
}
public enum PriceBasis: String, Codable, CaseIterable, Identifiable {
    case unknown, tripGroup, tripPerson, nightRoom, nightAllRooms, activityPerson
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .unknown:return "Unknown — choose the price unit"
        case .tripGroup:return "Full booking total · whole party"
        case .tripPerson:return "Round-trip flight · per person"
        case .nightRoom:return "Hotel · per room per night"
        case .nightAllRooms:return "Hotel · all rooms per night"
        case .activityPerson:return "Activity · per adult"
        }
    }
    public static func infer(_ candidate:PriceCandidate) -> PriceBasis {
        let text=(candidate.evidence ?? candidate.context).lowercased()
        func has(_ pattern:String)->Bool { text.range(of:pattern,options:.regularExpression) != nil }
        // Teasers, savings, child prices and crossed-out retail amounts must not win a trip ranking.
        guard !has("retail|original price|was |save |saving|discount|cashback|off\\b|from\\s*(?:php|₱)|starting at|child|infant|deposit|installment") else{return .unknown}
        let perPerson=has("per (?:adult|person|travell?er|passenger)|/(?:adult|person)")
        let group=has("grand total|booking total|total amount due|whole party|all (?:adults|travell?ers|passengers)|total for [1-9] adults")
        switch candidate.job.provider {
        case .flight:
            guard has("round[ -]?trip|return flights?|both ways") else{return .unknown}
            return perPerson ? .tripPerson : group ? .tripGroup : .unknown
        case .hotel:
            if has("per night|/night|nightly") {
                if has("all rooms"){return .nightAllRooms}
                if has("per room|/room|room per night") || candidate.job.rooms == 1{return .nightRoom}
            }
            if group || (candidate.job.rooms == 1 && has("total for [2-6] nights|entire stay|stay total")){return .tripGroup}
            return .unknown
        case .activity:return perPerson ? .activityPerson : group ? .tripGroup : .unknown
        }
    }
}
public struct PriceComponent {
    public let candidate:PriceCandidate
    public let basis:PriceBasis
    public let total:Int
    public var calculation:String {
        let j=candidate.job
        switch basis {
        case .nightRoom:return "\(Money.php(candidate.amount)) × \((ManilaDate.days(j.departure,j.returning) ?? 0)) nights × \(j.rooms) room(s)"
        case .nightAllRooms:return "\(Money.php(candidate.amount)) × \((ManilaDate.days(j.departure,j.returning) ?? 0)) nights"
        case .tripPerson,.activityPerson:return "\(Money.php(candidate.amount)) × \(j.adults) adult(s)"
        default:return "Complete group amount"
        }
    }
}
public struct CalculatedTrip: Identifiable {
    public var id:String {quote.id}
    public let quote:TripQuote
    public let components:[Provider:PriceComponent]
    public let food:Int
    public let localTransport:Int
    public let savings:[(Voucher,Int)]
    public let paidActivity:Bool
    public var missing:[Provider] {Provider.allCases.filter{components[$0] == nil && ($0 != .activity || paidActivity)}}
    public var discount:Int {savings.reduce(0){$0+$1.1}}
    public var knownSubtotal:Int {quote.flight+quote.hotel+quote.activity+quote.transfers+quote.baggage+(quote.otherCosts ?? 0)+food+localTransport-discount}
    public var total:Int? {missing.isEmpty ? knownSubtotal : nil}
    public var perPerson:Int? {total.map{($0+quote.adults-1)/quote.adults}}
}
public enum PriceCalculator {
    public static func key(_ job:ScanJob)->String {"\(job.destination)|\(job.departure)|\(job.returning)|\(job.adults)|\(job.rooms)"}
    public static func component(_ candidate:PriceCandidate)->PriceComponent? {
        let j=candidate.job
        guard !j.voucherScan, candidate.excluded != true, candidate.amount>0, candidate.amount<=1_000_000_000,
              (1...9).contains(j.adults),(1...j.adults).contains(j.rooms),
              let nights=ManilaDate.days(j.departure,j.returning),(2...6).contains(nights), ProviderLinks.allowed(URL(string:candidate.url) ?? URL(string:"about:blank")!) else{return nil}
        let basis=candidate.basis ?? PriceBasis.infer(candidate)
        let multiplier:Int
        switch basis {
        case .tripGroup:multiplier=1
        case .tripPerson:guard j.provider == .flight else{return nil};multiplier=j.adults
        case .nightRoom:guard j.provider == .hotel else{return nil};multiplier=nights*j.rooms
        case .nightAllRooms:guard j.provider == .hotel else{return nil};multiplier=nights
        case .activityPerson:guard j.provider == .activity else{return nil};multiplier=j.adults
        case .unknown:return nil
        }
        let total=candidate.amount*multiplier
        guard total<=1_000_000_000 else{return nil}
        return PriceComponent(candidate:candidate,basis:basis,total:total)
    }
    // Keep the cheapest usable component of every unit per search, independent of the raw capture cache.
    public static func compact(_ candidates:[PriceCandidate])->[PriceCandidate] {
        var best:[String:PriceComponent]=[:]
        for c in candidates {
            guard let part=component(c) else{continue}
            let key=c.job.id+"|"+part.basis.rawValue
            if let old=best[key], old.total<part.total {continue}
            best[key]=part
        }
        return best.values.map(\.candidate).sorted{$0.id<$1.id}
    }
    public static func calculate(_ candidates:[PriceCandidate],vouchers:[Voucher],settings:SearchSettings,now:Date=Date())->[CalculatedTrip] {
        guard settings.validation == nil else{return []}
        var groups:[String:[PriceCandidate]]=[:]
        for c in candidates {
            let j=c.job
            guard !j.voucherScan,j.adults==settings.adults,j.rooms==settings.rooms,Destination.find(j.destination) != nil,
                  j.departure>=settings.firstDeparture,j.departure<=settings.lastDeparture,
                  let nights=ManilaDate.days(j.departure,j.returning),(settings.minDays...settings.maxDays).contains(nights+1),
                  c.capturedAt<=now.addingTimeInterval(300),settings.includeExpired || c.capturedAt>=now.addingTimeInterval(-3600) else{continue}
            groups[key(j),default:[]].append(c)
        }
        return groups.keys.sorted().compactMap { key in
            guard let input=groups[key],let j=input.first?.job else{return nil}
            var parts:[Provider:PriceComponent]=[:]
            for c in input {
                guard let part=component(c) else{continue}
                if let old=parts[c.job.provider],old.total<part.total || (old.total==part.total && old.candidate.id<part.candidate.id){continue}
                parts[c.job.provider]=part
            }
            if !settings.budget.paidActivity {parts.removeValue(forKey:.activity)}
            var q=TripQuote();q.id="capture|"+key+"|"+Provider.allCases.map{parts[$0]?.candidate.id ?? "missing"}.joined(separator:"|")
            q.destination=j.destination;q.departure=j.departure;q.returning=j.returning;q.adults=j.adults;q.rooms=j.rooms
            q.flight=parts[.flight]?.total ?? 0;q.hotel=parts[.hotel]?.total ?? 0;q.activity=parts[.activity]?.total ?? 0
            q.transfers=settings.budget.transfers;q.baggage=settings.budget.baggage;q.otherCosts=settings.budget.other
            q.source = .captured;q.checkedAt=parts.values.map(\.candidate.capturedAt).min() ?? input[0].capturedAt;q.expiresAt=q.checkedAt.addingTimeInterval(3600)
            q.hotelName="Captured Agoda offer";q.activityName=settings.budget.paidActivity ? "Captured Klook offer" : "Free exploration"
            q.note="Automatic estimate. Verify provider dates, party, room occupancy, taxes, fare inclusions, required transfers and international costs.\n"+Provider.allCases.compactMap{parts[$0].map{"\($0.candidate.job.provider.name): \($0.candidate.context)\n\($0.candidate.url)"}}.joined(separator:"\n")
            let savings=Provider.allCases.compactMap{p -> (Voucher,Int)? in
                vouchers.filter{$0.provider==p}.map{($0,$0.saving(for:q,settings:settings,now:now))}.filter{$0.1>0}.sorted{a,b in a.1==b.1 ? a.0.code<b.0.code : a.1>b.1}.first
            }
            return CalculatedTrip(quote:q,components:parts,food:settings.foodDaily*q.days*q.adults,localTransport:settings.transportDaily*q.days*q.adults,savings:savings,paidActivity:settings.budget.paidActivity)
        }.sorted { a,b in
            if let x=a.total,let y=b.total {return x==y ? a.id<b.id : x<y}
            if a.total != nil{return true};if b.total != nil{return false}
            return a.missing.count==b.missing.count ? a.id<b.id : a.missing.count<b.missing.count
        }
    }
    public static func cheapestPerDestination(_ trips:[CalculatedTrip])->[CalculatedTrip] {
        var seen=Set<String>();return trips.filter{seen.insert($0.quote.destination).inserted}
    }
}
public enum PublishedCodes {
    public static let examples:[PromoHint] = [
        .init(code:"JRWDELIVERY",provider:.activity,sourceURL:"https://www.klook.com/en-PH/deals/",capturedAt:ManilaDate.parse("2026-09-29")!,terms:"Published offer: JPY 6,000 off eligible Shinkansen same-day luggage delivery. Product-specific. Check current expiry, allocation and PHP checkout saving."),
        .init(code:"TAKAYAMA2800",provider:.activity,sourceURL:"https://www.klook.com/en-PH/deals/",capturedAt:ManilaDate.parse("2026-09-29")!,terms:"Published offer: JPY 2,800 off JR Takayama-Hokuriku Area Tourist Pass. Product-specific. Check current expiry, allocation and PHP checkout saving."),
        .init(code:"SOLANIWAONSEN28%",provider:.activity,sourceURL:"https://www.klook.com/en-PH/deals/",capturedAt:ManilaDate.parse("2026-09-29")!,terms:"Published offer: 28% off eligible Solaniwa Onsen Osaka ticket. Product-specific. Keep the % character in the code. Check current expiry and checkout eligibility.")
    ]
}
