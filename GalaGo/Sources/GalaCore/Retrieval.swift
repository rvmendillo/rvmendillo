import Foundation

public enum SearchMode:String, Codable, CaseIterable, Identifiable {
    case quick, everyDate
    public var id:String {rawValue}
    public var title:String {self == .quick ? "Quick results" : "Every departure date"}
}
public extension SearchSettings {
    var retrievalMode:SearchMode {searchMode ?? .quick}
    func scanDates()->[(String,String)] {
        let all=dates()
        guard retrievalMode == .quick,let span=ManilaDate.days(firstDeparture,lastDeparture) else{return all}
        let starts=Set([firstDeparture,ManilaDate.add(firstDeparture,days:span/2),lastDeparture])
        return all.filter{starts.contains($0.0)}
    }
}
public enum RetrievalPolicy {
    public static let perProviderSpacing:TimeInterval=8
    public static let cacheLifetime:TimeInterval=3600
    public static let pageDeadline:TimeInterval=35
    public static let readyPollNanoseconds:UInt64=750_000_000
    public static func startDelay(lastStart:Date?,cooldown:Date?,now:Date=Date())->TimeInterval {
        let safeStart=max(lastStart?.addingTimeInterval(perProviderSpacing) ?? .distantPast,cooldown ?? .distantPast)
        return max(0,safeStart.timeIntervalSince(now))
    }
    public static func fresh(_ candidates:[PriceCandidate],for job:ScanJob,now:Date=Date())->[PriceCandidate] {
        candidates.filter{c in
            c.job.id==job.id && c.excluded != true && c.capturedAt<=now.addingTimeInterval(300) && c.capturedAt>=now.addingTimeInterval(-cacheLifetime) &&
            (job.provider != .flight || ProviderLinks.matchesFlightURL(URL(string:c.url),job:job))
        }
    }
    public static func workerJobs(_ jobs:[ScanJob],provider:Provider,now:Date=Date())->[ScanJob] {
        jobs.filter{$0.provider==provider && $0.status=="queued" && ($0.retryAfter ?? .distantPast)<=now}
    }
}
public extension ScanJob {
    var validation:String? {
        if voucherScan{return nil}
        guard destination != "MNL",Destination.find(destination) != nil else{return "Choose a destination airport different from MNL."}
        guard let nights=ManilaDate.days(departure,returning),(2...6).contains(nights),(1...9).contains(adults),(1...adults).contains(rooms) else{return "Check the trip dates and traveler count."}
        return nil
    }
}
public extension ProviderLinks {
    static func matchesFlightURL(_ url:URL?,job:ScanJob)->Bool {
        guard let url=url,allowed(url),url.host?.hasSuffix("cebupacificair.com")==true,
              url.path.contains("select-flight"),let c=URLComponents(url:url,resolvingAgainstBaseURL:false) else{return false}
        let pairs=c.queryItems ?? []
        // Duplicate keys or multi-city parameters must not silently alter the requested route.
        guard Set(pairs.map(\.name)).count==pairs.count else{return false}
        let q=Dictionary(pairs.map{($0.name,$0.value ?? "")},uniquingKeysWith:{first,_ in first})
        return q["o1"]=="MNL" && q["d1"]==job.destination && q["d1"] != q["o1"] &&
            q["dd1"]==job.departure && q["dd2"]==job.returning && q["adt"]==String(job.adults) &&
            q["chd"]=="0" && q["inl"]=="0" && q["inf"]=="0" && q["o2"]==nil && q["d2"]==nil
    }
}
public enum PageProbe {
    // Public booking fields only; no account fields, cookies, tokens or site internal state.
    public static let javascript = #"""
    (() => {
      const body=document.body?.innerText || '';
      const visible=e=>e.getClientRects().length>0;
      const fields=Array.from(document.querySelectorAll('input[formcontrolname],input[placeholder],input[aria-label]')).filter(visible);
      const valueFor=kind=>fields.filter(e=>{
        const label=[e.getAttribute('formcontrolname'),e.getAttribute('placeholder'),e.getAttribute('aria-label')].filter(Boolean).join(' ').toLowerCase();
        return kind==='origin' ? /\borigin\b|\bfrom\b/.test(label) : /\bdestination\b|\bto\b/.test(label);
      }).map(e=>e.value || '').filter(Boolean).slice(0,2);
      const codeFrom=value=>{const m=value.match(/(?:\(|\b)([A-Z]{3})(?:\)|\b)/);return m?m[1]:'';};
      const origins=valueFor('origin').map(codeFrom).filter(Boolean);
      const destinations=valueFor('destination').map(codeFrom).filter(Boolean);
      const routePairs=Array.from(body.slice(0,7000).matchAll(/\b([A-Z]{3})\s*(?:→|↔|to|–|-)\s*([A-Z]{3})\b/g)).slice(0,6).map(m=>[m[1],m[2]]);
      return {
        url:location.href, origins, destinations, routePairs,
        priceReady:/(?:PHP|₱)\s*[0-9]/i.test(body),
        codeReady:/(?:promo(?:tion)?\s*code|coupon\s*code|use\s*code|code\s*:)/i.test(body),
        unavailable:/no (?:available )?flights|no flights available|no rooms available|no results found|no activities found/i.test(body),
        blocked:/verify you are human|unusual traffic|access denied|too many requests|complete the captcha|robot verification/i.test(body)
      };
    })()
    """#
}
