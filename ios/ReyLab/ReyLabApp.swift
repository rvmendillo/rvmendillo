import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import ImageIO
import PDFKit
import AVFoundation
import WebKit

@main
struct ReyLabApp: App {
    var body: some Scene { WindowGroup { LabHome().tint(.indigo) } }
}

struct LabHome: View {
    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("REY VICTOR MENDILLO").font(.caption.bold()).tracking(2)
                            Text("Ideas, made\ninteractive.").font(.system(size: 42, weight: .bold, design: .rounded))
                            Text("Code · music · creative computation").foregroundStyle(.secondary)
                        }.frame(maxWidth:.infinity,alignment:.leading).padding(26).background(.indigo.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius:28))
                        Text("Your project lab").font(.title2.bold())
                        NavigationLink { ImageASCIIView() } label: { ToolCard(title:"Image to ASCII",detail:"Turn an image into colored characters",icon:"character.textbox",badge:"OFFLINE") }
                        NavigationLink { MIDIToolView() } label: { ToolCard(title:"MIDI relative scale",detail:"Reimagine a melody in its relative mode",icon:"pianokeys",badge:"OFFLINE") }
                        NavigationLink { KnapsackView() } label: { ToolCard(title:"Knapsack solver",detail:"Find the most valuable combination",icon:"backpack",badge:"OFFLINE") }
                        NavigationLink { SloperView() } label: { ToolCard(title:"Skirt sloper",detail:"Draft and export a measured PDF pattern",icon:"scissors",badge:"OFFLINE") }
                        Text("Connected projects").font(.title2.bold())
                        NavigationLink { PythonRunnerView() } label: { ToolCard(title:"Python runner",detail:"Run code on your configured Flask server",icon:"terminal",badge:"SERVER") }
                        NavigationLink { ConnectedProject(path:"mbti_personality_predictor",title:"MBTI predictor") } label: { ToolCard(title:"MBTI predictor",detail:"Use the original trained model on your server",icon:"brain",badge:"SERVER") }
                        NavigationLink { ConnectedProject(path:"realtime_chat",title:"Realtime chat") } label: { ToolCard(title:"Realtime chat",detail:"Connect to your original shared chat",icon:"bubble.left.and.bubble.right",badge:"SERVER") }
                    }.padding(20)
                }.navigationTitle("Rey Lab")
            }.tabItem { Label("Projects",systemImage:"square.grid.2x2") }
            NavigationStack { AboutView() }.tabItem { Label("About",systemImage:"person.crop.circle") }
            NavigationStack { ServerSettingsView() }.tabItem { Label("Settings",systemImage:"gearshape") }
        }
    }
}

struct ToolCard: View {
    let title: String, detail: String, icon: String, badge: String
    var body: some View {
        HStack(spacing:16) {
            Image(systemName:icon).font(.title2).frame(width:44,height:50).foregroundStyle(.indigo)
            VStack(alignment:.leading,spacing:5) { Text(title).font(.headline).foregroundStyle(.primary); Text(detail).font(.subheadline).foregroundStyle(.secondary) }
            Spacer(minLength:0)
            Text(badge).font(.system(size:9,weight:.bold)).foregroundStyle(.secondary)
            Image(systemName:"chevron.right").font(.caption).foregroundStyle(.tertiary)
        }.padding(14).background(Color(uiColor:.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius:18))
    }
}

enum LabFiles {
    static func save(_ data: Data, name: String) throws -> URL {
        let folder = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        let url = folder.appendingPathComponent(UUID().uuidString.prefix(6) + "-" + name)
        try data.write(to:url,options:.atomic); return url
    }
    static func read(_ url: URL) throws -> Data {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
        guard size <= 50_000_000 else { throw ConversionError.message("Choose a file smaller than 50 MB.") }
        return try Data(contentsOf:url)
    }
}

struct ImageASCIIView: View {
    @State private var picker: PhotosPickerItem?
    @State private var importing = false
    @State private var source: CGImage?
    @State private var rendered: UIImage?
    @State private var settings = ASCIISettings()
    @State private var urls: [URL] = []
    @State private var status = "Choose a photo or image file."
    @State private var busy = false
    @State private var imageURL = ""
    var body: some View {
        ScrollView {
            VStack(spacing:18) {
                if let rendered = rendered { Image(uiImage:rendered).resizable().scaledToFit().frame(maxHeight:400).background(.black).clipShape(RoundedRectangle(cornerRadius:16)) }
                HStack {
                    PhotosPicker(selection:$picker,matching:.images) { Label("Photos",systemImage:"photo") }
                    Button("Files",systemImage:"folder") { importing = true }
                }.buttonStyle(.bordered)
                HStack {
                    TextField("https://… image URL",text:$imageURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Load") { Task { await loadURL() } }
                }
                LabeledContent("Columns",value:"\(settings.columns)")
                Slider(value:Binding(get:{Double(settings.columns)},set:{settings.columns = Int($0)}),in:30...200,step:10)
                TextField("Characters: dark → light",text:$settings.charset).font(.system(.body,design:.monospaced)).textInputAutocapitalization(.never).autocorrectionDisabled()
                Toggle("Dark background",isOn:$settings.darkBackground)
                Toggle("Original colors",isOn:$settings.color)
                Button("Generate ASCII",systemImage:"sparkles") { Task { await generate() } }.buttonStyle(.borderedProminent).disabled(source == nil)
                Text(status).font(.footnote).foregroundStyle(.secondary)
                ForEach(urls,id:\.self) { url in ShareLink(item:url) { Label(url.pathExtension == "png" ? "Share PNG image" : "Share ASCII text",systemImage:"square.and.arrow.up") } }
            }.padding(22).disabled(busy)
            if busy { ProgressView().padding() }
        }.navigationTitle("Image to ASCII")
            .onChange(of:picker) { _, item in Task { do { if let data = try await item?.loadTransferable(type:Data.self) { try accept(data) } } catch { status = error.localizedDescription } } }
            .fileImporter(isPresented:$importing,allowedContentTypes:[.image]) { result in do { try accept(LabFiles.read(result.get())) } catch { status = error.localizedDescription } }
    }
    func accept(_ data: Data) throws {
        guard data.count <= 50_000_000, let source = CGImageSourceCreateWithData(data as CFData,nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:2048,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary) else { throw ConversionError.message("Could not decode this image. Choose JPEG, PNG, HEIC or another supported image under 50 MB.") }
        self.source = cg; rendered = UIImage(cgImage:cg); urls = []; status = "Ready to convert."
    }
    func loadURL() async {
        guard let url = URL(string:imageURL), url.scheme == "https", url.host != nil else { status = "Enter a valid HTTPS image URL."; return }
        busy = true; defer { busy = false }
        do {
            let request = URLRequest(url:url,timeoutInterval:30)
            let (local,response) = try await URLSession.shared.download(for:request)
            defer { try? FileManager.default.removeItem(at:local) }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ConversionError.message("The image server returned an error.") }
            try accept(LabFiles.read(local))
        } catch { status = error.localizedDescription }
    }
    func generate() async {
        guard let source = source else { return }
        busy = true; defer { busy = false }
        do {
            let config = settings
            let frame = try await Task.detached { try ASCIIEngine.render(source,settings:config) }.value
            let image = UIImage(cgImage:frame.image)
            guard let png = image.pngData() else { throw ConversionError.message("PNG export failed.") }
            let imageFile = try LabFiles.save(png,name:"ascii.png"), textFile = try LabFiles.save(Data(frame.text.utf8),name:"ascii.txt")
            rendered = image; urls = [imageFile,textFile]; status = "Saved PNG and plain-text exports."
        } catch { status = error.localizedDescription }
    }
}

struct MIDIToolView: View {
    @State private var importing = false
    @State private var source: Data?
    @State private var sourceName = "No MIDI selected"
    @State private var mode = "Auto"
    @State private var output: URL?
    @State private var status = "Key detection uses the Krumhansl profiles. Percussion, timing and instrument events are preserved."
    @State private var player: AVMIDIPlayer?
    @State private var busy = false
    var body: some View {
        Form {
            Section("Input") {
                Text(sourceName)
                Button("Import MIDI",systemImage:"doc.badge.plus") { importing = true }
                ForEach(["A Lovely Dream","Nightmare"],id:\.self) { name in
                    Button("Try \(name)") { if let url = Bundle.main.url(forResource:name,withExtension:"mid") { load(url) } else { status = "Example MIDI is not bundled." } }
                }
                Picker("Source mode",selection:$mode) { ForEach(["Auto","Major","Minor"],id:\.self) { Text($0) } }
            }
            Section("Convert to relative mode") {
                Text("Major moves down two scale degrees; minor moves up two. Use a mode override if automatic key detection is ambiguous.").font(.footnote)
                Button("Convert MIDI") { Task { await convert() } }.disabled(source == nil || busy)
                if busy { ProgressView() }
                Text(status).font(.footnote)
                if let output = output {
                    ShareLink("Share converted MIDI",item:output)
                    Button("Play conversion") { do { player?.stop(); player = try AVMIDIPlayer(contentsOf:output,soundBankURL:nil); player?.prepareToPlay(); player?.play(nil) } catch { status = "Playback unavailable: \(error.localizedDescription). The MIDI can still be shared." } }
                    Button("Stop playback") { player?.stop() }
                }
            }
        }.navigationTitle("MIDI relative scale").onDisappear { player?.stop() }
            .fileImporter(isPresented:$importing,allowedContentTypes:[UTType(filenameExtension:"mid") ?? .data,UTType(filenameExtension:"midi") ?? .data]) { result in do { load(try result.get()) } catch { status = error.localizedDescription } }
    }
    func load(_ url: URL) { do { source = try LabFiles.read(url); sourceName = url.lastPathComponent; output = nil; player?.stop(); status = "MIDI loaded." } catch { status = error.localizedDescription } }
    func convert() async {
        guard let source = source else { return }; busy = true; defer { busy = false }
        let override: Bool? = mode == "Auto" ? nil : mode == "Minor"
        do {
            let result = try await Task.detached { try MIDIRelative.convert(source,forcedMinor:override) }.value
            output = try LabFiles.save(result.data,name:"relative.mid")
            status = "\(result.sourceKey) → \(result.targetKey) · \(result.noteCount) notes. Saved to Files."
        } catch { status = error.localizedDescription }
    }
}

struct KnapsackView: View {
    @State private var items = [PackItem(name:"Camera",value:60,weight:10),PackItem(name:"Laptop",value:100,weight:20),PackItem(name:"Books",value:120,weight:30)]
    @State private var capacity = 50
    @State private var result: [PackItem] = []
    @State private var solved = false
    @State private var error = ""
    var body: some View {
        Form {
            Section("Capacity") { TextField("Weight limit",value:$capacity,format:.number).keyboardType(.numberPad); Text("Weights use any consistent unit. The app finds an exact optimum using dynamic programming.").font(.footnote) }
            Section("Items") {
                ForEach($items) { $item in
                    VStack(alignment:.leading) {
                        TextField("Item name",text:$item.name)
                        HStack { Text("Value"); TextField("Value",value:$item.value,format:.number).keyboardType(.numberPad); Text("Weight"); TextField("Weight",value:$item.weight,format:.number).keyboardType(.numberPad) }.font(.subheadline)
                    }
                }.onDelete { items.remove(atOffsets:$0); solved = false }
                Button("Add item") { items.append(PackItem(name:"Item \(items.count+1)",value:10,weight:5)); solved = false }.disabled(items.count >= 100)
            }
            Section {
                Button("Find best combination") { do { result = try Knapsack.solve(items,capacity:capacity); solved = true; error = "" } catch { self.error = error.localizedDescription } }
                if !error.isEmpty { Text(error).foregroundStyle(.red) }
            }
            if solved {
                Section("Solution") {
                    LabeledContent("Total value",value:"\(result.reduce(0){$0+$1.value})")
                    LabeledContent("Total weight",value:"\(result.reduce(0){$0+$1.weight}) / \(capacity)")
                    if result.isEmpty { Text("No positive-value item fits.") }
                    ForEach(result) { Text($0.name) }
                }
            }
        }.navigationTitle("Knapsack solver")
    }
}

struct SloperView: View {
    @State private var m = SloperMeasurements()
    @State private var output: URL?
    @State private var status = "Measurements are in centimeters. Export produces a full-size pattern PDF."
    var body: some View {
        Form {
            Section("Body measurements · cm") {
                number("Waist",$m.waist); number("Hip",$m.hip); number("Hip height",$m.hipHeight); number("Length",$m.length)
            }
            Section("Ease and darts · cm") {
                number("Waist ease",$m.waistEase); number("Hip ease",$m.hipEase); number("Back dart",$m.backDart); number("Front dart",$m.frontDart)
            }
            Section {
                Button("Generate pattern PDF") { do { output = try LabFiles.save(m.pdf(),name:"skirt-sloper.pdf"); status = "Pattern saved. Print at actual size (100%); use poster tiling or a large-format printer." } catch { status = error.localizedDescription } }
                Text(status).font(.footnote)
                if let output = output { NavigationLink("Preview pattern") { PDFScreen(url:output).navigationTitle("Pattern") }; ShareLink("Share PDF",item:output) }
            }
        }.navigationTitle("Skirt sloper")
    }
    func number(_ title: String,_ value: Binding<Double>) -> some View { HStack { Text(title); Spacer(); TextField(title,value:value,format:.number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width:100) } }
}

struct PDFScreen: UIViewRepresentable {
    let url: URL
    func makeUIView(context:Context) -> PDFView { let view = PDFView(); view.autoScales = true; view.document = PDFDocument(url:url); return view }
    func updateUIView(_ view:PDFView,context:Context) {}
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                Text("Rey Victor Mendillo").font(.title.bold())
                Text("Software engineer · Computer Science graduate of Mapúa University, specializing in Artificial Intelligence.")
                Text("A native edition of the projects in the rvmendillo repository: making algorithms and creative tools accessible on iPhone and iPad.")
            }
            Section("From the original repository") {
                if let resume = Bundle.main.url(forResource:"Resume",withExtension:"pdf") { NavigationLink("View original résumé") { PDFScreen(url:resume).navigationTitle("Résumé") } }
                if let paper = Bundle.main.url(forResource:"Rome 2022 Paper",withExtension:"pdf") { NavigationLink("View research paper") { PDFScreen(url:paper).navigationTitle("Research") } }
                Text("The bundled résumé and paper are the repository's archived originals.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Connect") {
                Link("GitHub",destination:URL(string:"https://github.com/rvmendillo/rvmendillo")!)
                Link("LinkedIn",destination:URL(string:"https://www.linkedin.com/in/rvmendillo")!)
                Link("Email",destination:URL(string:"mailto:rvmendillo@gmail.com")!)
            }
        }.navigationTitle("About")
    }
}
