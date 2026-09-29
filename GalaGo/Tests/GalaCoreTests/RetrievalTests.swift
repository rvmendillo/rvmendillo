import XCTest
@testable import GalaCore

final class RetrievalTests:XCTestCase {
    let now=ManilaDate.parse("2026-09-29")!
    func job(_ code:String="CEB",adults:Int=1)->ScanJob{ScanJob(provider:.flight,destination:code,departure:"2026-10-13",returning:"2026-10-15",adults:adults,rooms:1)}
    func url(_ j:ScanJob)->URL{ProviderLinks.url(j.provider,destination:j.destination,departure:j.departure,returning:j.returning,adults:j.adults,rooms:j.rooms)}
    func testAllAirportLinksAreRoundTripsNotMultiCity() {
        for d in Destination.all {for adults in [1,4,9] {
            let j=job(d.code,adults:adults),u=url(j)
            XCTAssertTrue(ProviderLinks.matchesFlightURL(u,job:j))
            let q=Dictionary(URLComponents(url:u,resolvingAgainstBaseURL:false)!.queryItems!.map{($0.name,$0.value!)},uniquingKeysWith:{a,_ in a})
            // Matches Cebu's public deep-link parser: o2 => multi-city, otherwise d1+dd2 => round trip.
            XCTAssertNil(q["o2"]);XCTAssertNil(q["d2"]);XCTAssertNil(q["isRoundTrip"]);XCTAssertNil(q["ADT"])
            XCTAssertEqual(q["d1"],d.code);XCTAssertNotEqual(q["d1"],q["o1"]);XCTAssertEqual(q["adt"],String(adults));XCTAssertEqual(q["inl"],"0");XCTAssertEqual(q["inf"],"0");XCTAssertEqual(q["chd"],"0")
        }}
    }
    func testLegacyAndSameAirportLinksAreRejected(){let j=job();let legacy=URL(string:"https://www.cebupacificair.com/en-PH/booking/select-flight?isRoundTrip=true&o1=MNL&d1=CEB&dd1=2026-10-13&o2=CEB&d2=MNL&dd2=2026-10-15&ADT=1&CHD=0&INF=0")!;XCTAssertFalse(ProviderLinks.matchesFlightURL(legacy,job:j));XCTAssertNotNil(job("MNL").validation);XCTAssertFalse(ProviderLinks.matchesFlightURL(url(j),job:job("NRT")))}
    func testDuplicateParametersAndWrongDatesCannotPass(){let j=job();XCTAssertFalse(ProviderLinks.matchesFlightURL(URL(string:url(j).absoluteString+"&d1=MNL"),job:j));XCTAssertFalse(ProviderLinks.matchesFlightURL(URL(string:url(j).absoluteString.replacingOccurrences(of:"2026-10-15",with:"2026-10-16")),job:j))}
    func testQuickModeReducesRequestsWithoutDroppingDestinationsOrLengths(){var s=SearchSettings();s.firstDeparture="2026-10-01";s.lastDeparture="2026-10-31";let quick=ScanPlan.jobs(settings:s,destinations:Destination.all.map(\.code));XCTAssertEqual(quick.count,3*5*65*3);XCTAssertEqual(Set(quick.map(\.destination)).count,65);XCTAssertEqual(Set(quick.map{ManilaDate.days($0.departure,$0.returning)!+1}),Set(3...7));XCTAssertEqual(Set(quick.map(\.departure)),Set(["2026-10-01","2026-10-16","2026-10-31"]));s.searchMode = .everyDate;XCTAssertEqual(ScanPlan.jobs(settings:s,destinations:Destination.all.map(\.code)).count,31*5*65*3)}
    func testQuickModeDeduplicatesShortWindows(){var s=SearchSettings();s.firstDeparture="2026-10-01";s.lastDeparture=s.firstDeparture;XCTAssertEqual(s.scanDates().count,5);s.lastDeparture="2026-10-02";XCTAssertEqual(s.scanDates().count,10)}
    func testCacheRequiresExactRoutePartyAndFreshness(){let j=job();let c=PriceCandidate(job:j,amount:100000,context:"Round-trip per adult",url:url(j).absoluteString,capturedAt:now);XCTAssertEqual(RetrievalPolicy.fresh([c],for:j,now:now).count,1);XCTAssertTrue(RetrievalPolicy.fresh([c],for:job("NRT"),now:now).isEmpty);XCTAssertTrue(RetrievalPolicy.fresh([c],for:job(adults:2),now:now).isEmpty);XCTAssertTrue(RetrievalPolicy.fresh([c],for:j,now:now.addingTimeInterval(3601)).isEmpty);let bad=PriceCandidate(job:j,amount:100000,context:"Round-trip",url:"https://www.cebupacificair.com/en-PH/booking/select-flight?o1=MNL&d1=MNL",capturedAt:now);XCTAssertTrue(RetrievalPolicy.fresh([bad],for:j,now:now).isEmpty)}
    func testProviderTimingUsesStartTimeAndHonorsLongCooldown(){XCTAssertEqual(RetrievalPolicy.startDelay(lastStart:now.addingTimeInterval(-6),cooldown:nil,now:now),2);XCTAssertEqual(RetrievalPolicy.startDelay(lastStart:now.addingTimeInterval(-20),cooldown:nil,now:now),0);XCTAssertEqual(RetrievalPolicy.startDelay(lastStart:now,cooldown:now.addingTimeInterval(7200),now:now),7200)}
    func testProviderWorkersCannotTakeEachOthersJobs(){var flight=job();let hotel=ScanJob(provider:.hotel,destination:"CEB",departure:flight.departure,returning:flight.returning,adults:1,rooms:1);XCTAssertEqual(RetrievalPolicy.workerJobs([flight,hotel],provider:.hotel,now:now).map(\.id),[hotel.id]);flight.retryAfter=now.addingTimeInterval(30);XCTAssertTrue(RetrievalPolicy.workerJobs([flight,hotel],provider:.flight,now:now).isEmpty);flight.retryAfter=nil;flight.status="running";XCTAssertTrue(RetrievalPolicy.workerJobs([flight],provider:.flight,now:now).isEmpty)}
    func testOldSettingsMigrateToQuickMode()throws{let e=JSONEncoder();let d=JSONDecoder();var object=try JSONSerialization.jsonObject(with:e.encode(SearchSettings())) as! [String:Any];object.removeValue(forKey:"searchMode");let restored=try d.decode(SearchSettings.self,from:JSONSerialization.data(withJSONObject:object));XCTAssertEqual(restored.retrievalMode,.quick)}
}
