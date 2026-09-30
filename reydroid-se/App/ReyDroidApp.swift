// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import UniformTypeIdentifiers

@main
struct ReyDroidApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            HomeView(model: model)
                .preferredColorScheme(.dark)
                .tint(Color(red: 0.58, green: 0.48, blue: 1))
                .onOpenURL { model.importFiles([$0]) }
        }
    }
}

private let ink = Color(red: 0.055, green: 0.065, blue: 0.105)
private let card = Color(red: 0.105, green: 0.12, blue: 0.18)
private let accent = Color(red: 0.65, green: 0.59, blue: 1)

struct HomeView: View {
    @ObservedObject var model: AppModel
    @State private var importer = false
    @State private var logs = false
    @State private var about = false
    @State private var log = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("REYDROID SE").font(.caption.weight(.bold)).tracking(3).foregroundStyle(accent)
                            Text("Your Android\nspace.").font(.system(size: 37, weight: .bold, design: .rounded))
                        }
                        Spacer()
                        Image(systemName: "square.stack.3d.up.fill").font(.system(size: 45)).foregroundStyle(accent)
                            .frame(width: 85, height: 95).background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 26))
                    }
                    HStack(spacing: 7) {
                        badge("NO JIT", symbol: "checkmark.shield")
                        badge("ON DEVICE", symbol: "iphone")
                        badge("EXPERIMENTAL", symbol: "flask")
                    }
                    runtimeCard
                    if !model.apps.isEmpty {
                        sectionTitle("Installed apps", trailing: "\(model.apps.count)")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                            ForEach(model.apps) { app in
                                Button { model.launch(app) } label: {
                                    VStack(spacing: 12) {
                                        Image(systemName: "app.dashed").font(.system(size: 29)).foregroundStyle(accent)
                                        Text(app.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                                    }.frame(maxWidth: .infinity, minHeight: 100).padding(10).background(card, in: RoundedRectangle(cornerRadius: 18))
                                }.buttonStyle(.plain).disabled(!model.ready || model.busy)
                            }
                        }
                    }
                    HStack {
                        sectionTitle("APK library", trailing: "\(model.files.count)")
                        Button { importer = true } label: { Image(systemName: "plus.circle.fill").font(.title2) }.disabled(model.busy)
                    }
                    if model.files.isEmpty {
                        VStack(spacing: 13) {
                            Image(systemName: "square.and.arrow.down.on.square").font(.system(size: 33)).foregroundStyle(accent)
                            Text("Bring your first APK").font(.headline)
                            Text("Import an Android app from Files.\nStart Android, then tap Install.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            Button("Import APK") { importer = true }.buttonStyle(.borderedProminent).controlSize(.large)
                        }.frame(maxWidth: .infinity).padding(26).background(card, in: RoundedRectangle(cornerRadius: 22))
                    } else {
                        ForEach(model.files) { file in
                            HStack(spacing: 12) {
                                Image(systemName: "shippingbox.fill").font(.title2).foregroundStyle(accent).frame(width: 44)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(file.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Button("Install") { model.install(file) }.buttonStyle(.bordered).disabled(!model.ready || model.busy)
                            }.padding(15).background(card, in: RoundedRectangle(cornerRadius: 18))
                                .contextMenu { Button("Remove imported file", role: .destructive) { model.remove(file) }.disabled(model.busy) }
                        }
                    }
                    Text("Android runs through a CPU interpreter. First boot and app installation can take a long time. Some APKs will be incompatible.")
                        .font(.footnote).foregroundStyle(.secondary).lineSpacing(3)
                    Button { about = true } label: { Label("About this build & source credits", systemImage: "info.circle") }.font(.footnote)
                }.padding(22)
            }.background(ink)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Refresh installed apps", systemImage: "arrow.clockwise") { model.refresh() }.disabled(!model.ready)
                            Button("View runtime logs", systemImage: "doc.text") { log = model.logText(); logs = true }
                            Button("About ReyDroid SE", systemImage: "info.circle") { about = true }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
                .fileImporter(isPresented: $importer, allowedContentTypes: [UTType(filenameExtension: "apk") ?? .data, .data], allowsMultipleSelection: true) {
                    switch $0 { case .success(let files): model.importFiles(files); case .failure(let error): model.problem = error.localizedDescription }
                }
                .fullScreenCover(isPresented: $model.showAndroid) { PlayerView(model: model) }
                .sheet(isPresented: $logs) {
                    NavigationStack {
                        ScrollView { Text(log).font(.system(size: 11, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).padding().textSelection(.enabled) }
                            .navigationTitle("Runtime logs").toolbar {
                                ToolbarItem(placement: .topBarLeading) { Button("Refresh") { log = model.logText() } }
                                ToolbarItem(placement: .topBarTrailing) { Button("Done") { logs = false } }
                            }
                    }
                }
                .sheet(isPresented: $about) { AboutView() }
                .alert("ReyDroid SE", isPresented: Binding(get: { model.problem != nil }, set: { if !$0 { model.problem = nil } })) {
                    Button("OK") { model.problem = nil }
                } message: { Text(model.problem ?? "") }
        }
    }
    private var runtimeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: model.ready ? "circle.fill" : "cpu").foregroundStyle(model.ready ? Color.green : accent)
                Text(model.ready ? "Android is running" : model.running ? "Android is starting" : "Android runtime").font(.headline)
                Spacer()
                if model.busy || model.downloading { ProgressView().tint(accent) }
            }
            Text(model.status).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if model.downloading {
                ProgressView(value: model.progress).tint(accent)
                HStack {
                    Text("\(Int(model.progress * 100))% · Keep ReyDroid open").font(.caption)
                    Spacer(); Button("Pause") { model.downloader.pause() }.font(.caption)
                }
            } else if model.running {
                Button { model.showAndroid = true } label: { Label("Open Android", systemImage: "play.rectangle.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            } else if model.downloaded && !model.usedSession {
                Button { model.start() } label: { Label("Start Android", systemImage: "play.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            } else if !model.usedSession {
                Text("One-time 2.06 GB download · Allow 8 GB free space\nNo debugger or JIT activation is required.").font(.caption).foregroundStyle(.secondary)
                Button { model.prepare() } label: { Label("Prepare Android", systemImage: "arrow.down.circle.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
        }.padding(20).background(card, in: RoundedRectangle(cornerRadius: 22))
    }
    private func badge(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.system(size: 8, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 8).background(.white.opacity(0.055), in: Capsule())
    }
    private func sectionTitle(_ title: String, trailing: String) -> some View {
        HStack { Text(title).font(.title3.weight(.bold)); Text(trailing).font(.caption.weight(.bold)).foregroundStyle(.secondary); Spacer(minLength: 0) }
    }
}

struct PlayerView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var display: AndroidDisplay
    @State private var text = ""
    @State private var typing = false
    @State private var stop = false
    init(model: AppModel) { self.model = model; self.display = model.display }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { model.showAndroid = false } label: { Image(systemName: "chevron.down").frame(width: 42, height: 42) }
                VStack(alignment: .leading) {
                    Text("REYDROID SE").font(.caption.weight(.bold)).tracking(2)
                    Text(model.ready ? "Android · interpreter" : "Starting Android…").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button { stop = true } label: { Image(systemName: "power").frame(width: 42, height: 42) }
            }.padding(.horizontal, 10)
            ZStack {
                AndroidSurface(display: display)
                if display.image == nil {
                    VStack(spacing: 16) { ProgressView(); Text("Waiting for the Android display").font(.subheadline); Text("The first boot can be very slow.").font(.caption).foregroundStyle(.secondary) }.padding()
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            if !model.ready {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = Int(context.date.timeIntervalSince(model.started ?? context.date))
                    Text("Cold boot · \(elapsed / 60)m \(elapsed % 60)s · Keep this app open")
                        .font(.caption2).foregroundStyle(.secondary).padding(.vertical, 8)
                }
            }
            HStack {
                Button { model.key(4) } label: { Image(systemName: "chevron.left").frame(maxWidth: .infinity, minHeight: 48) }
                Button { model.key(3) } label: { Image(systemName: "circle").frame(maxWidth: .infinity, minHeight: 48) }
                Button { model.key(187) } label: { Image(systemName: "square").frame(maxWidth: .infinity, minHeight: 48) }
                Button { typing = true } label: { Image(systemName: "keyboard").frame(maxWidth: .infinity, minHeight: 48) }
            }.disabled(!model.ready || model.busy).background(card)
        }.background(ink).preferredColorScheme(.dark)
            .alert("Send text to Android", isPresented: $typing) {
                TextField("Text", text: $text)
                Button("Send") { model.type(text); text = "" }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Tap an Android text field first. Basic Latin text is supported.") }
            .confirmationDialog("Stop Android? Reopen ReyDroid SE to start another session.", isPresented: $stop, titleVisibility: .visible) {
                Button("Stop Android", role: .destructive) { model.shutdown(); model.showAndroid = false }
            }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("ReyDroid SE · 0.1") {
                    Text("A custom SwiftUI APK launcher using the UTM SE ARM64 threaded interpreter. Local Android emulation requires ordinary IPA signing, but no JIT entitlement, StikDebug, pairing file, or remote Android service.")
                    Text("Experimental: this build has not completed a physical-iPhone Android boot test. Expect long startup times. ARM64 APKs are the intended target; 32-bit-only apps, apps needing Google Play services, and demanding games may not work. Audio and split-APK installation are not implemented.")
                }
                Section("Open-source foundations") {
                    Link("UTM SE 4.7.5 / QEMU — interpreter engine", destination: URL(string: "https://github.com/utmapp/UTM/tree/v4.7.5")!)
                    Link("Husk — Android image and guest shell service", destination: URL(string: "https://github.com/Leviidev/Husk")!)
                    Link("Android Lineage QEMU — guest disk templates", destination: URL(string: "https://github.com/jqssun/android-lineage-qemu")!)
                    Text("ReyDroid SE source is GPL-2.0-or-later. Third-party software retains its own licenses. Source links and build scripts are included with the project.")
                }
            }.navigationTitle("About").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
