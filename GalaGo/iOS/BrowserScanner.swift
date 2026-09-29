import SwiftUI
import WebKit
import Combine

@MainActor final class BrowserScanner:NSObject,ObservableObject,WKNavigationDelegate {
    let webView:WKWebView
    let store:AppStore
    let provider:Provider
    @Published var running=false
    @Published var job:ScanJob?
    @Published var status="Ready"
    @Published var captured:[PriceCandidate]=[]
    @Published var completed=0
    private var deadline:Task<Void,Never>?
    private var probeTask:Task<Void,Never>?
    private var nextTask:Task<Void,Never>?
    private var automatic=false
    private var generation=UUID()
    private var isFinished=true
    private var isProbing=false
    private var isCapturing=false
    private var readySamples=0
    private var seenCodes=0
    init(store:AppStore,provider:Provider) {
        self.store=store;self.provider=provider
        let configuration=WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        webView=WKWebView(frame:.zero,configuration:configuration)
        super.init();webView.navigationDelegate=self;webView.allowsBackForwardNavigationGestures=true
    }
    func startQueue(){guard !running else{return};automatic=true;running=true;next()}
    func open(_ selected:ScanJob){pause();job=selected;automatic=false;running=true;schedule(selected)}
    func refresh(){guard let j=job else{return};let resumeQueue=automatic;open(j);automatic=resumeQueue}
    func pause() {
        running=false;automatic=false;deadline?.cancel();probeTask?.cancel();nextTask?.cancel()
        generation=UUID();isFinished=true;isProbing=false;isCapturing=false;webView.stopLoading()
        if let j=job,let i=store.state.jobs.firstIndex(where:{$0.id==j.id}),store.state.jobs[i].status=="running"{store.state.jobs[i].status="queued";store.save()}
    }
    private func next() {
        guard running else{return}
        if let j=RetrievalPolicy.workerJobs(store.state.jobs,provider:provider).first {
            let cache=RetrievalPolicy.fresh(store.pricingInputs,for:j)
            if !cache.isEmpty {
                job=j;captured=cache;completed+=1
                if let i=store.state.jobs.firstIndex(where:{$0.id==j.id}){store.state.jobs[i].status="done";store.state.jobs[i].message="Matching cached prices reused."}
                store.save();status="Cached prices ready · \(j.destination)"
                nextTask=Task{await Task.yield();guard !Task.isCancelled else{return};self.next()};return
            }
            schedule(j)
        } else if let until=store.state.jobs.filter({$0.provider==provider && $0.status=="queued"}).compactMap(\.retryAfter).min() {
            status="Waiting until \(until.formatted(date:.omitted,time:.shortened)) · progress saved"
            nextTask=Task{try? await Task.sleep(nanoseconds:UInt64(max(1,min(30,until.timeIntervalSinceNow)))*1_000_000_000);guard !Task.isCancelled,self.running else{return};self.next()}
        } else {running=false;status="\(provider.name) finished. Open Prices for calculated totals."}
    }
    private func schedule(_ selected:ScanJob) {
        let delay=RetrievalPolicy.startDelay(lastStart:store.state.lastStarts?[provider.rawValue],cooldown:store.state.cooldowns[provider.rawValue])
        if delay>0 {
            status="\(provider.name) · next request in \(Int(ceil(delay)))s"
            nextTask?.cancel();nextTask=Task{try? await Task.sleep(nanoseconds:UInt64(min(delay,30)*1_000_000_000));guard !Task.isCancelled,self.running else{return};self.schedule(selected)}
        } else {load(selected)}
    }
    private func load(_ selected:ScanJob) {
        guard running else{return}
        if let error=selected.validation{job=selected;isFinished=false;finish(error,retry:false);return}
        generation=UUID();job=selected;captured=[];isFinished=false;isProbing=false;isCapturing=false;readySamples=0;seenCodes=0
        let token=generation
        status="Loading \(selected.voucherScan ? "voucher offers" : "MNL ↔ "+selected.destination)"
        if let i=store.state.jobs.firstIndex(where:{$0.id==selected.id}){store.state.jobs[i].status="running";store.state.jobs[i].attempts+=1}
        if store.state.lastStarts==nil{store.state.lastStarts=[:]};store.state.lastStarts?[provider.rawValue]=Date();store.save()
        let url=selected.overrideURL.flatMap(URL.init(string:)) ?? ProviderLinks.url(provider,destination:selected.destination,departure:selected.departure,returning:selected.returning,adults:selected.adults,rooms:selected.rooms)
        guard ProviderLinks.allowed(url),selected.voucherScan || provider != .flight || ProviderLinks.matchesFlightURL(url,job:selected) else{finish("Invalid route link. Search was not sent.",retry:false);return}
        webView.load(URLRequest(url:url,cachePolicy:.useProtocolCachePolicy,timeoutInterval:30))
        deadline?.cancel();deadline=Task{try? await Task.sleep(nanoseconds:UInt64(RetrievalPolicy.pageDeadline)*1_000_000_000);guard !Task.isCancelled,token==self.generation,self.running else{return};self.finish("This page took too long. Other providers can continue.",retry:true)}
    }
    private func routeProblem(_ result:[String:Any])->String? {
        guard let j=job,provider == .flight,!j.voucherScan else{return nil}
        let origins=result["origins"] as? [String] ?? []
        let destinations=result["destinations"] as? [String] ?? []
        let pairs=result["routePairs"] as? [[String]] ?? []
        if origins.first.map({$0 != "MNL"}) == true || destinations.first.map({$0 != j.destination}) == true || pairs.contains(where:{$0.count==2 && $0[0]=="MNL" && $0[1]=="MNL"}) {
            return "The website shows a different route. Expected MNL ↔ \(j.destination). No prices saved. Tap Reload route."
        }
        if !ProviderLinks.matchesFlightURL(URL(string:result["url"] as? String ?? ""),job:j){return "The flight page lost the requested route or dates. No prices saved. Tap Reload route."}
        return nil
    }
    private func inspectPage() {
        guard running,!isFinished,!isProbing,!isCapturing else{return}
        isProbing=true;let token=generation
        webView.evaluateJavaScript(PageProbe.javascript){[weak self] value,_ in
            guard let self=self,token==self.generation else{return};self.isProbing=false
            guard !self.isFinished,self.running else{return}
            guard let result=value as? [String:Any] else{self.scheduleProbe();return}
            if result["blocked"] as? Bool == true{self.finish("Provider verification required. This provider is paused; other providers continue.",retry:false,block:true);return}
            let hasContent=result["priceReady"] as? Bool == true || result["unavailable"] as? Bool == true
            if hasContent,let problem=self.routeProblem(result){self.finish(problem,retry:false,block:true);return}
            if result["unavailable"] as? Bool == true{self.finish("No availability reported for this search.",retry:false,unavailable:true);return}
            let ready=self.job?.voucherScan == true ? result["codeReady"] as? Bool == true : result["priceReady"] as? Bool == true
            self.readySamples=ready ? self.readySamples+1 : 0
            if self.readySamples>=2{self.capture()}else{self.scheduleProbe()}
        }
    }
    private func scheduleProbe(){probeTask?.cancel();let token=generation;probeTask=Task{try? await Task.sleep(nanoseconds:RetrievalPolicy.readyPollNanoseconds);guard !Task.isCancelled,token==self.generation else{return};self.inspectPage()}}
    func capture() {
        guard !isCapturing,let current=job,let url=webView.url,ProviderLinks.allowed(url) else{return}
        isCapturing=true;let token=generation
        // Route validation and the captured prices come from the same currently rendered document.
        let script="(() => { const probe = "+PageProbe.javascript+"; const capture = "+CaptureScript.javascript+"; return {probe,capture}; })()"
        webView.evaluateJavaScript(script){[weak self] value,_ in
            guard let self=self,token==self.generation else{return};self.isCapturing=false
            guard let both=value as? [String:Any],let probe=both["probe"] as? [String:Any],let result=both["capture"] as? [String:Any] else{self.status="Waiting for readable prices.";self.scheduleProbe();return}
            if result["blocked"] as? Bool == true {self.finish("Provider verification required. Automatic requests are paused for this provider.",retry:false,block:true);return}
            if let problem=self.routeProblem(probe){self.finish(problem,retry:false,block:true);return}
            let source=result["url"] as? String ?? url.absoluteString
            let items=result["prices"] as? [[String:Any]] ?? []
            let candidates=items.compactMap{item -> PriceCandidate? in guard let amount=item["amount"] as? Int,let context=item["context"] as? String else{return nil};var c=PriceCandidate(job:current,amount:amount,context:context,url:source);c.evidence=item["evidence"] as? String;return c}
            self.captured=candidates
            let codes=result["codes"] as? [String] ?? [];self.seenCodes=codes.count
            let offers=result["offers"] as? [[String:Any]] ?? []
            for code in codes {
                let hint=PromoHint(code:code,provider:self.provider,sourceURL:source,capturedAt:Date(),terms:offers.first{($0["code"] as? String)==code}?["terms"] as? String)
                self.store.state.promoHints.removeAll{$0.id==hint.id};self.store.state.promoHints.append(hint)
            }
            self.store.state.promoHints=Array(self.store.state.promoHints.suffix(200))
            if !current.voucherScan && !candidates.isEmpty{self.store.record(candidates,for:current)}else{self.store.save()}
            if candidates.isEmpty && !current.voucherScan && !self.isFinished {self.readySamples=0;self.scheduleProbe();return}
            self.finish(current.voucherScan ? "\(codes.count) voucher codes captured." : "\(candidates.count) prices captured · totals updated",retry:false)
        }
    }
    private func finish(_ message:String,retry:Bool,block:Bool=false,unavailable:Bool=false,delay:TimeInterval?=nil) {
        guard let j=job else{return}
        guard !isFinished else{status=message;return}
        isFinished=true;deadline?.cancel();probeTask?.cancel();status=message
        var attempts=j.attempts+1
        if let i=store.state.jobs.firstIndex(where:{$0.id==j.id}) {
            attempts=store.state.jobs[i].attempts
            let retryAllowed=retry && attempts<3
            store.state.jobs[i].status=unavailable ? "unavailable" : block ? "review" : retryAllowed ? "queued" : (!captured.isEmpty || seenCodes>0) ? "done" : "review"
            store.state.jobs[i].message=message
            if retry{store.state.jobs[i].retryAfter=Date().addingTimeInterval(delay ?? ScanPlan.retryDelay(attempt:attempts,retryAfter:nil))}
        }
        if retry || block {
            webView.stopLoading()
            let until=Date().addingTimeInterval(delay ?? ScanPlan.retryDelay(attempt:attempts,retryAfter:nil))
            store.state.cooldowns[provider.rawValue]=max(store.state.cooldowns[provider.rawValue] ?? .distantPast,until)
        }
        completed+=1;store.save()
        if automatic && !block {nextTask?.cancel();nextTask=Task{await Task.yield();guard !Task.isCancelled,self.running else{return};self.next()}}
        else{running=false}
    }
    func webView(_ webView:WKWebView,didCommit navigation:WKNavigation!){inspectPage()}
    func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!){inspectPage()}
    func webView(_ webView:WKWebView,didFail navigation:WKNavigation!,withError error:Error){handle(error)}
    func webView(_ webView:WKWebView,didFailProvisionalNavigation navigation:WKNavigation!,withError error:Error){handle(error)}
    private func handle(_ error:Error){guard running,(error as NSError).code != NSURLErrorCancelled else{return};finish("Page could not load. Other providers can continue.",retry:true)}
    func webView(_ webView:WKWebView,decidePolicyFor response:WKNavigationResponse,decisionHandler:@escaping(WKNavigationResponsePolicy)->Void) {
        guard response.isForMainFrame,let http=response.response as? HTTPURLResponse else{decisionHandler(.allow);return}
        if http.statusCode==429 || http.statusCode==503 {decisionHandler(.cancel);finish("Provider requested a cooldown. Saved progress is retained.",retry:true,delay:ScanPlan.retryDelay(attempt:job?.attempts ?? 1,retryAfter:http.value(forHTTPHeaderField:"Retry-After")));return}
        if http.statusCode==403 {decisionHandler(.allow);finish("Access restricted for this provider. Automatic requests paused.",retry:false,block:true);return}
        decisionHandler(.allow)
    }
    func webView(_ webView:WKWebView,decidePolicyFor action:WKNavigationAction,decisionHandler:@escaping(WKNavigationActionPolicy)->Void) {
        guard let url=action.request.url else{decisionHandler(.cancel);return}
        if action.targetFrame?.isMainFrame == true || action.targetFrame==nil {
            guard ProviderLinks.allowed(url) || url.absoluteString=="about:blank" else{decisionHandler(.cancel);status="Use the provider’s own app for external login or payment links.";return}
            if action.targetFrame==nil{decisionHandler(.cancel);webView.load(action.request);return}
        }
        decisionHandler(.allow)
    }
}
@MainActor final class ScanSession:ObservableObject {
    let workers:[BrowserScanner]
    @Published var selected:Provider
    private var subscriptions: Set<AnyCancellable> = []
    var current:BrowserScanner{workers.first{$0.provider==selected} ?? workers[0]}
    var running:Bool{workers.contains{$0.running}}
    init(store:AppStore,initial:ScanJob?) {
        let providers=initial.map{[$0.provider]} ?? Provider.allCases
        workers=providers.map{BrowserScanner(store:store,provider:$0)};selected=providers[0]
        for worker in workers {worker.objectWillChange.sink{[weak self] _ in self?.objectWillChange.send()}.store(in:&subscriptions)}
    }
    func start(){workers.forEach{$0.startQueue()}}
    func pause(){workers.forEach{$0.pause()}}
}
struct ProviderWebView:UIViewRepresentable {
    @ObservedObject var scanner:BrowserScanner
    func makeUIView(context:Context)->WKWebView{scanner.webView}
    func updateUIView(_ view:WKWebView,context:Context){}
}
struct ScannerView:View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session:ScanSession
    let initial:ScanJob?
    var picked:((PriceCandidate)->Void)?
    @State private var showPrices=false
    @State private var started=false
    init(store:AppStore,initial:ScanJob?=nil,picked:((PriceCandidate)->Void)?=nil){_session=StateObject(wrappedValue:ScanSession(store:store,initial:initial));self.initial=initial;self.picked=picked}
    var body:some View {
        NavigationStack {
            VStack(spacing:0) {
                VStack(alignment:.leading,spacing:7) {
                    if initial==nil {
                        Picker("Provider",selection:$session.selected){Text("Flights").tag(Provider.flight);Text("Hotels").tag(Provider.hotel);Text("Klook").tag(Provider.activity)}.pickerStyle(.segmented)
                        Text("Three providers run together · one request at a time per provider").font(.caption2).foregroundColor(.secondary)
                    }
                    Text(session.current.status).font(.subheadline.weight(.medium)).lineLimit(3)
                    if let j=session.current.job,!j.voucherScan {Text("MNL ↔ \(j.destination) · \(j.departure) – \(j.returning) · \(j.adults) adult(s)").font(.caption).foregroundColor(Theme.teal)}
                    HStack {
                        if initial==nil{Button(session.running ? "Pause" : "Resume"){if session.running{session.pause()}else{session.start()}}.buttonStyle(.bordered)}
                        Button("Capture"){session.current.capture()}.buttonStyle(.borderedProminent)
                        Button("Prices (\(session.current.captured.count))"){showPrices=true}.disabled(session.current.captured.isEmpty)
                        Button{session.current.refresh()}label:{Image(systemName:"arrow.clockwise")}.accessibilityLabel("Reload route").disabled(session.current.job==nil)
                    }.font(.caption)
                    Text("Prices update as soon as ready. Verify selections and fees before booking.").font(.caption2).foregroundColor(.secondary)
                }.padding(12).background(Theme.paper)
                ZStack {
                    ForEach(session.workers,id:\.provider){worker in
                        ProviderWebView(scanner:worker).opacity(session.selected==worker.provider ? 1 : 0.01).allowsHitTesting(session.selected==worker.provider).accessibilityHidden(session.selected != worker.provider).zIndex(session.selected==worker.provider ? 1 : 0)
                    }
                }
            }.navigationTitle(session.current.provider.name).navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement:.cancellationAction){Button("Done"){session.pause();dismiss()}}
                ToolbarItem(placement:.primaryAction){HStack{
                    Button{session.current.webView.goBack()}label:{Image(systemName:"chevron.left")}.accessibilityLabel("Previous provider page")
                    if let url=session.current.webView.url,ProviderLinks.allowed(url){Link(destination:url){Image(systemName:"safari")}.accessibilityLabel("Open provider in Safari")}
                }}
            }
            .onAppear{guard !started else{return};started=true;if let initial=initial{session.current.open(initial)}else{session.start()}}
            .onDisappear{session.pause()}
            .onReceive(NotificationCenter.default.publisher(for:UIApplication.willResignActiveNotification)){_ in session.pause()}
            .sheet(isPresented:$showPrices){NavigationStack{List(session.current.captured){candidate in Button{picked?(candidate);if picked != nil{session.pause();dismiss()}}label:{VStack(alignment:.leading,spacing:8){Text(Money.php(candidate.amount)).font(.title3.bold());Text(candidate.context).font(.caption).foregroundColor(.secondary);Text(picked==nil ? "Saved · automatic estimate in Prices" : "Use amount, then verify complete group total").font(.caption).foregroundColor(Theme.teal)}}.disabled(picked==nil)}.navigationTitle("Captured prices").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){showPrices=false}}}}}
        }
    }
}
