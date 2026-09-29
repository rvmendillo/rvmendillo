import SwiftUI
import WebKit

@MainActor final class BrowserScanner: NSObject, ObservableObject, WKNavigationDelegate {
    let webView:WKWebView
    let store:AppStore
    @Published var running=false
    @Published var job:ScanJob?=nil
    @Published var status="Ready to scan public booking pages."
    @Published var captured:[PriceCandidate]=[]
    private var timeout:Task<Void,Never>?
    private var scheduled:Task<Void,Never>?
    private var sessionCount=0
    private var automatic=false
    private var generation=UUID()
    private var isFinished=false
    init(store:AppStore) {
        self.store=store
        let configuration=WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        webView=WKWebView(frame:.zero,configuration:configuration)
        super.init();webView.navigationDelegate=self;webView.allowsBackForwardNavigationGestures=true
    }
    func startQueue() {guard !running else{return};automatic=true;sessionCount=0;running=true;next()}
    func open(_ job:ScanJob) {pause();self.job=job;if let until=store.state.cooldowns[job.provider.rawValue],until>Date(){status="Provider cooling down until \(until.formatted(date:.omitted,time:.shortened)). Your progress is saved.";return};automatic=false;running=true;load(job)}
    func pause() {
        running=false;automatic=false;timeout?.cancel();scheduled?.cancel();generation=UUID();webView.stopLoading()
        if let current=job,let i=store.state.jobs.firstIndex(where:{$0.id==current.id}),store.state.jobs[i].status=="running"{store.state.jobs[i].status="queued";store.save()}
    }
    private func next() {
        guard running else{return}
        if sessionCount>=20 {pause();status="20 pages checked. Progress saved; tap Resume for the next batch.";return}
        let now=Date()
        if let j=store.state.jobs.first(where:{$0.status=="queued" && ($0.retryAfter ?? .distantPast)<=now && (store.state.cooldowns[$0.provider.rawValue] ?? .distantPast)<=now}) {load(j)}
        else {pause();status=store.state.jobs.contains{$0.status=="queued"} ? "Some providers are cooling down. Progress saved; resume later." : "Scan finished. Review captured prices before comparing trip totals."}
    }
    private func load(_ j:ScanJob) {
        generation=UUID();let token=generation;isFinished=false;job=j;captured=[];sessionCount+=1
        status="Opening \(j.provider.name) · \(j.destination) · \(j.departure)"
        if let i=store.state.jobs.firstIndex(where:{$0.id==j.id}){store.state.jobs[i].status="running";store.state.jobs[i].attempts+=1;store.save()}
        let url=ProviderLinks.url(j.provider,destination:j.destination,departure:j.departure,returning:j.returning,adults:j.adults,rooms:j.rooms)
        webView.load(URLRequest(url:url,timeoutInterval:30))
        timeout?.cancel();timeout=Task {try? await Task.sleep(nanoseconds:35_000_000_000);guard !Task.isCancelled,token==self.generation,self.running else{return};self.finish(message:"Page exceeded 35 seconds; progress retained.",retry:true)}
    }
    func capture() {
        guard let current=job,let url=webView.url,ProviderLinks.allowed(url) else{return}
        let token=generation
        webView.evaluateJavaScript(CaptureScript.javascript) {[weak self] value,error in
            guard let self=self,token==self.generation else{return}
            guard let result=value as? [String:Any] else {self.status="No readable page yet. Wait for the page, then capture again.";return}
            if result["blocked"] as? Bool == true {self.finish(message:"Verification page detected. Open the provider normally to continue; automatic scanning is paused.",retry:false,block:true);return}
            let items=result["prices"] as? [[String:Any]] ?? []
            let candidates=items.compactMap { item -> PriceCandidate? in guard let cents=item["amount"] as? Int,let context=item["context"] as? String else{return nil};return PriceCandidate(job:current,amount:cents,context:context,url:url.absoluteString) }
            self.captured=candidates
            let codes=result["codes"] as? [String] ?? []
            for code in codes {
                let hint=PromoHint(code:code,provider:current.provider,sourceURL:url.absoluteString,capturedAt:Date())
                self.store.state.promoHints.removeAll{$0.id==hint.id}
                self.store.state.promoHints.append(hint)
            }
            self.store.state.promoHints=Array(self.store.state.promoHints.suffix(200))
            self.store.state.candidates.removeAll {$0.job.id==current.id}
            self.store.state.candidates.append(contentsOf:candidates)
            if self.store.state.candidates.count>3000 {self.store.state.candidates.removeFirst(self.store.state.candidates.count-3000)}
            self.store.save()
            self.finish(message:candidates.isEmpty ? "No PHP prices captured. Verify search fields, dates and currency on this page." : "\(candidates.count) price candidates captured. Totals need review.",retry:false)
        }
    }
    private func finish(message:String,retry:Bool,block:Bool=false,delay:TimeInterval?=nil) {
        guard let j=job,!isFinished else{status=message;return};isFinished=true;timeout?.cancel();status=message
        if let i=store.state.jobs.firstIndex(where:{$0.id==j.id}) {
            let retryAllowed=retry && store.state.jobs[i].attempts<3
            store.state.jobs[i].status=block ? "review" : retryAllowed ? "queued" : captured.isEmpty ? "review" : "done"
            store.state.jobs[i].message=message
            if retry || block {
                let seconds=delay ?? ScanPlan.retryDelay(attempt:store.state.jobs[i].attempts,retryAfter:nil)
                store.state.jobs[i].retryAfter=Date().addingTimeInterval(seconds)
                store.state.cooldowns[j.provider.rawValue]=Date().addingTimeInterval(seconds)
            }
        }
        store.save()
        if automatic && !block {scheduled?.cancel();scheduled=Task{try? await Task.sleep(nanoseconds:8_000_000_000);guard !Task.isCancelled,self.running else{return};self.next()}}
        else {running=false}
    }
    func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!) {
        guard running else{return};let token=generation
        scheduled?.cancel();scheduled=Task{try? await Task.sleep(nanoseconds:5_000_000_000);guard !Task.isCancelled,token==self.generation,self.running else{return};self.capture()}
    }
    func webView(_ webView:WKWebView,didFail navigation:WKNavigation!,withError error:Error){handle(error)}
    func webView(_ webView:WKWebView,didFailProvisionalNavigation navigation:WKNavigation!,withError error:Error){handle(error)}
    private func handle(_ error:Error){guard running,(error as NSError).code != NSURLErrorCancelled else{return};finish(message:"Could not load this page. Other work is saved.",retry:true)}
    func webView(_ webView:WKWebView,decidePolicyFor navigationResponse:WKNavigationResponse,decisionHandler:@escaping(WKNavigationResponsePolicy)->Void) {
        if let response=navigationResponse.response as? HTTPURLResponse,response.statusCode==429 || response.statusCode==503 {
            decisionHandler(.cancel);let delay=ScanPlan.retryDelay(attempt:job?.attempts ?? 1,retryAfter:response.value(forHTTPHeaderField:"Retry-After"));finish(message:"Provider asked us to wait. Resuming is delayed for \(Int(delay)) seconds.",retry:true,delay:delay);return
        }
        if let response=navigationResponse.response as? HTTPURLResponse,response.statusCode==403 {decisionHandler(.allow);finish(message:"Access is restricted. Automatic scanning paused for review.",retry:false,block:true);return}
        decisionHandler(.allow)
    }
    func webView(_ webView:WKWebView,decidePolicyFor navigationAction:WKNavigationAction,decisionHandler:@escaping(WKNavigationActionPolicy)->Void) {
        guard let url=navigationAction.request.url else{decisionHandler(.cancel);return}
        if navigationAction.targetFrame?.isMainFrame == true || navigationAction.targetFrame == nil {
            guard ProviderLinks.allowed(url) || url.absoluteString=="about:blank" else {decisionHandler(.cancel);status="Open external login or payment links directly in the provider’s app.";return}
            if navigationAction.targetFrame==nil {decisionHandler(.cancel);webView.load(navigationAction.request);return}
        }
        decisionHandler(.allow)
    }
}
struct ProviderWebView:UIViewRepresentable {
    @ObservedObject var scanner:BrowserScanner
    func makeUIView(context:Context)->WKWebView{scanner.webView}
    func updateUIView(_ uiView:WKWebView,context:Context){}
}
struct ScannerView:View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner:BrowserScanner
    let initial:ScanJob?
    var picked:((PriceCandidate)->Void)?
    @State private var showPrices=false
    init(store:AppStore,initial:ScanJob?=nil,picked:((PriceCandidate)->Void)?=nil){_scanner=StateObject(wrappedValue:BrowserScanner(store:store));self.initial=initial;self.picked=picked}
    var body:some View {
        NavigationStack {
            VStack(spacing:0) {
                VStack(alignment:.leading,spacing:6) {
                    Text(scanner.status).font(.subheadline.weight(.medium))
                    if let j=scanner.job {Text("MNL ↔ \(j.destination) · \(j.departure) – \(j.returning) · \(j.adults) adult(s), \(j.rooms) room(s)").font(.caption).foregroundColor(.secondary)}
                    Text("Confirm the website’s fields; links may reset them. Prices here are unverified candidates.").font(.caption2).foregroundColor(.secondary)
                    HStack {
                        if initial==nil {Button(scanner.running ? "Pause" : "Resume"){if scanner.running{scanner.pause()}else{scanner.startQueue()}}.buttonStyle(.bordered)}
                        Button("Capture prices"){scanner.capture()}.buttonStyle(.borderedProminent)
                        Button("Prices (\(scanner.captured.count))"){showPrices=true}.disabled(scanner.captured.isEmpty)
                    }.font(.caption)
                }.padding(12).background(Theme.paper)
                ProviderWebView(scanner:scanner)
            }
            .navigationTitle(scanner.job?.provider.name ?? "Public-page scanner").navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement:.cancellationAction){Button("Done"){scanner.pause();dismiss()}}
                ToolbarItem(placement:.primaryAction){HStack{
                    Button{scanner.webView.goBack()}label:{Image(systemName:"chevron.left")}.accessibilityLabel("Previous provider page")
                    if let url=scanner.webView.url,ProviderLinks.allowed(url){Link(destination:url){Image(systemName:"safari")}.accessibilityLabel("Open provider in Safari")}
                }}
            }
            .onAppear{if let initial=initial{scanner.open(initial)}else{scanner.startQueue()}}
            .onDisappear{scanner.pause()}
            .onReceive(NotificationCenter.default.publisher(for:UIApplication.willResignActiveNotification)){_ in scanner.pause()}
            .sheet(isPresented:$showPrices){NavigationStack{List(scanner.captured){candidate in Button{picked?(candidate);if picked != nil {scanner.pause();dismiss()}}label:{VStack(alignment:.leading,spacing:8){Text(Money.php(candidate.amount)).font(.title3.bold());Text(candidate.context).font(.caption).foregroundColor(.secondary);Text(picked == nil ? "Saved for review in Discover" : "Use this amount, then verify full trip total").font(.caption).foregroundColor(Theme.teal)}}.disabled(picked==nil)}.navigationTitle("Captured prices").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){showPrices=false}}}}}
        }
    }
}
