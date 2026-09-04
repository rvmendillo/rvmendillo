import SwiftUI
import WebKit

enum ServerAddress {
    static func base(_ raw: String) -> URL? {
        guard let url = URL(string:raw.trimmingCharacters(in:.whitespacesAndNewlines)),
              url.scheme == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { return nil }
        return url
    }
}

struct ServerSettingsView: View {
    @AppStorage("flaskServer") private var server = ""
    @State private var status = ""
    @State private var busy = false
    var body: some View {
        Form {
            Section("Your Flask server") {
                TextField("https://your-server.example",text:$server).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("Python execution, the trained MBTI model and shared chat use the backend from your rvmendillo repository. Enter its deployed HTTPS address. These features send only the input you submit to that server.").font(.footnote)
                Button("Test connection") { Task { await test() } }.disabled(busy)
                if busy { ProgressView() }
                if !status.isEmpty { Text(status).font(.footnote) }
            }
            Section("On this device") {
                Text("Image conversion, MIDI conversion, knapsack and skirt patterns work offline. Exports are available in Files → On My iPhone → Rey Lab.")
                Text("No JIT is required. The app does not include a Python interpreter or substitute predictions for the original trained model.").font(.footnote)
            }
            Section("Project") { Link("View original server source",destination:URL(string:"https://github.com/rvmendillo/rvmendillo")!) }
        }.navigationTitle("Settings")
    }
    func test() async {
        guard let base = ServerAddress.base(server) else { status = "Enter an HTTPS server address without a username, password, query or fragment."; return }
        busy = true; defer { busy = false }
        do {
            let (_, response) = try await URLSession.shared.data(for:URLRequest(url:base,timeoutInterval:15))
            if let response = response as? HTTPURLResponse, (200..<400).contains(response.statusCode) { status = "Server responded. Individual tools also need their original routes, database and dependencies." }
            else { status = "Server returned HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)." }
        } catch { status = error.localizedDescription }
    }
}

struct PythonRunnerView: View {
    @AppStorage("flaskServer") private var server = ""
    @State private var code = "for i in range(1, 6):\n    print('Rey Lab', i)"
    @State private var output = ""
    @State private var busy = false
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:18) {
                Text("Run Python using your original /api/python_compiler endpoint.").font(.subheadline).foregroundStyle(.secondary)
                if ServerAddress.base(server) == nil { NavigationLink("Set up your server") { ServerSettingsView() } }
                TextEditor(text:$code).font(.system(.body,design:.monospaced)).textInputAutocapitalization(.never).autocorrectionDisabled().frame(minHeight:260).padding(10).background(Color(uiColor:.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius:14))
                Button("Run on my server",systemImage:"play.fill") { Task { await run() } }.buttonStyle(.borderedProminent).disabled(busy || ServerAddress.base(server) == nil)
                if busy { ProgressView("Running…") }
                Text(output).font(.system(.footnote,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)
                if !output.isEmpty { ShareLink("Share output",item:output) }
            }.padding(22)
        }.navigationTitle("Python runner")
    }
    func run() async {
        guard let base = ServerAddress.base(server) else { return }
        busy = true; defer { busy = false }
        do {
            var request = URLRequest(url:base.appendingPathComponent("api/python_compiler"),timeoutInterval:30)
            request.httpMethod = "POST"; request.setValue("application/json",forHTTPHeaderField:"Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject:["python_code":code])
            let (data,response) = try await URLSession.shared.data(for:request)
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { throw ConversionError.message("The server rejected this request. Check its address and Python API route.") }
            guard let json = try JSONSerialization.jsonObject(with:data) as? [String:Any], let text = json["output"] as? String else { throw ConversionError.message("The server did not return the expected JSON output.") }
            output = text.isEmpty ? "Finished with no output." : text
        } catch { output = error.localizedDescription }
    }
}

struct ConnectedProject: View {
    let path: String, title: String
    @AppStorage("flaskServer") private var server = ""
    @State private var error = ""
    @State private var reload = UUID()
    var body: some View {
        VStack(spacing:12) {
            if let base = ServerAddress.base(server) {
                HStack { Text("Connected to \(base.host ?? "your server")").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Reload") { error = ""; reload = UUID() } }.padding(.horizontal)
                if !error.isEmpty { Text(error).font(.footnote).foregroundStyle(.red).padding() }
                ProjectBrowser(url:base.appendingPathComponent("project/"+path),error:$error).id(reload)
            } else {
                ContentUnavailableView("Connect your server",systemImage:"network",description:Text("This project uses your original Flask backend. Add its HTTPS address in Settings."))
                NavigationLink("Server settings") { ServerSettingsView() }.buttonStyle(.borderedProminent).padding(.bottom,30)
            }
        }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

struct ProjectBrowser: UIViewRepresentable {
    let url: URL
    @Binding var error: String
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context:Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let web = WKWebView(frame:.zero,configuration:configuration)
        web.navigationDelegate = context.coordinator; web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.load(URLRequest(url:url,timeoutInterval:30)); return web
    }
    func updateUIView(_ web:WKWebView,context:Context) {}
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: ProjectBrowser
        init(_ parent:ProjectBrowser) { self.parent = parent }
        func webView(_ webView:WKWebView,didFailProvisionalNavigation navigation:WKNavigation!,withError error:Error) { parent.error = error.localizedDescription }
        func webView(_ webView:WKWebView,didFail navigation:WKNavigation!,withError error:Error) { parent.error = error.localizedDescription }
        func webView(_ webView:WKWebView,decidePolicyFor navigationResponse:WKNavigationResponse,decisionHandler:@escaping(WKNavigationResponsePolicy)->Void) {
            if let response = navigationResponse.response as? HTTPURLResponse, response.statusCode >= 400 { parent.error = "Server returned HTTP \(response.statusCode). This project requires the original route and its dependencies." }
            decisionHandler(.allow)
        }
        func webView(_ webView:WKWebView,createWebViewWith configuration:WKWebViewConfiguration,for navigationAction:WKNavigationAction,windowFeatures:WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }; return nil
        }
    }
}
