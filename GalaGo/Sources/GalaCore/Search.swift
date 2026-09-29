import Foundation

public struct ScanJob: Codable, Identifiable, Equatable {
    public let id:String
    public let provider:Provider
    public let destination:String
    public let departure:String
    public let returning:String
    public let adults:Int
    public let rooms:Int
    public var status = "queued"
    public var attempts = 0
    public var retryAfter:Date? = nil
    public var message = ""
    public init(provider:Provider, destination:String, departure:String, returning:String, adults:Int, rooms:Int) {
        self.provider=provider;self.destination=destination;self.departure=departure;self.returning=returning;self.adults=adults;self.rooms=rooms
        id="\(provider.rawValue)|\(destination)|\(departure)|\(returning)|\(adults)|\(rooms)"
    }
}
public struct PriceCandidate: Codable, Identifiable, Equatable {
    public var id = UUID().uuidString
    public let job:ScanJob
    public let amount:Int
    public let context:String
    public let url:String
    public let capturedAt:Date
    public init(job:ScanJob, amount:Int, context:String, url:String, capturedAt:Date=Date()) {self.job=job;self.amount=amount;self.context=context;self.url=url;self.capturedAt=capturedAt}
}
public enum ScanPlan {
    public static func jobs(settings:SearchSettings, destinations:[String]) -> [ScanJob] {
        guard settings.validation == nil else {return []}
        var result:[ScanJob]=[]
        // Round-robin by date, length and destination; no destination is silently dropped.
        for pair in settings.dates() {
            for dest in Array(Set(destinations)).sorted() where Destination.find(dest) != nil {
                for provider in Provider.allCases { result.append(ScanJob(provider:provider,destination:dest,departure:pair.0,returning:pair.1,adults:settings.adults,rooms:settings.rooms)) }
            }
        }
        return result
    }
    public static func retryDelay(attempt:Int, retryAfter:String?, now:Date=Date(), jitter:Double=0.5) -> TimeInterval {
        if let h=retryAfter, let seconds=Double(h), seconds.isFinite {return max(5,seconds)}
        if let h=retryAfter {let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.timeZone=TimeZone(secondsFromGMT:0);f.dateFormat="EEE, dd MMM yyyy HH:mm:ss z";if let d=f.date(from:h){return max(5,d.timeIntervalSince(now))}}
        return min(3600,pow(2,Double(min(10,max(0,attempt))))*15 + max(0,min(1,jitter))*10)
    }
}
public enum ProviderLinks {
    public static func url(_ provider:Provider,destination:String,departure:String,returning:String,adults:Int,rooms:Int) -> URL {
        let name=Destination.find(destination)?.name.components(separatedBy:" · ").first ?? destination
        var c:URLComponents
        switch provider {
        case .flight:
            c=URLComponents(string:"https://www.cebupacificair.com/en-PH/booking/select-flight")!
            c.queryItems=[.init(name:"isRoundTrip",value:"true"),.init(name:"o1",value:"MNL"),.init(name:"d1",value:destination),.init(name:"dd1",value:departure),.init(name:"o2",value:destination),.init(name:"d2",value:"MNL"),.init(name:"dd2",value:returning),.init(name:"ADT",value:String(adults)),.init(name:"CHD",value:"0"),.init(name:"INF",value:"0"),.init(name:"mon",value:"true")]
        case .hotel:
            c=URLComponents(string:"https://www.agoda.com/search")!
            c.queryItems=[.init(name:"textToSearch",value:name+", Philippines"),.init(name:"checkIn",value:departure),.init(name:"checkOut",value:returning),.init(name:"adults",value:String(adults)),.init(name:"rooms",value:String(rooms)),.init(name:"children",value:"0"),.init(name:"currencyCode",value:"PHP")]
        case .activity:
            c=URLComponents(string:"https://www.klook.com/en-PH/search/result/")!
            c.queryItems=[.init(name:"query",value:name),.init(name:"currency",value:"PHP")]
        }
        return c.url!
    }
    public static func allowed(_ url:URL) -> Bool {
        guard url.scheme=="https",let host=url.host?.lowercased() else{return false}
        return ["cebupacificair.com","agoda.com","klook.com"].contains {host == $0 || host.hasSuffix("."+$0)}
    }
}
public enum CaptureScript {
    // Read rendered text only. Never inspect cookies, storage, form values or network credentials.
    // A candidate is deliberately not a bookable quote: date, party, inclusions and units need review.
    public static let javascript = #"""
    (() => {
      const text = (document.body?.innerText || '').slice(0, 700000);
      const blocked = /verify you are human|unusual traffic|access denied|too many requests|complete the captcha|robot verification/i.test(text);
      const out = []; const seen = new Set();
      const re = /(?:PHP|₱)\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)/gi;
      let m;
      while ((m = re.exec(text)) !== null && out.length < 60) {
        const cents = Math.round(Number(m[1].replace(/,/g,'')) * 100);
        const context = text.slice(Math.max(0,m.index-70), Math.min(text.length,re.lastIndex+100)).replace(/\s+/g,' ').trim();
        if (cents > 0 && cents <= 1000000000 && !seen.has(context)) { seen.add(context); out.push({amount:cents,context}); }
      }
      return {blocked, prices:out, title:document.title, url:location.href};
    })()
    """#
}
