import SwiftUI

struct VoucherListView:View {
    @EnvironmentObject var store:AppStore
    @State private var adding=false
    @State private var hint:PromoHint?
    @State private var editing:Voucher?
    @State private var browserJob:ScanJob?
    @State private var query=""
    private var hints:[PromoHint] {store.codeHints.filter{query.isEmpty || "\($0.code) \($0.provider.name) \($0.terms ?? "")".localizedCaseInsensitiveContains(query)}}
    var body:some View {
        NavigationStack {
            List {
                Section {
                    Text("Copy a code.\nKeep the savings.").font(.system(size:30,weight:.bold,design:.rounded)).foregroundColor(Theme.ink)
                    Text("Actual voucher strings, offer terms and sources. The best confirmed code for each provider is deducted automatically on Prices and Compare.").font(.subheadline).foregroundColor(.secondary)
                }
                Section("Find current codes on official pages") {
                    ForEach(Provider.allCases){p in
                        Button{let s=store.state.settings;browserJob=ScanJob(provider:p,destination:"CEB",departure:s.firstDeparture,returning:ManilaDate.add(s.firstDeparture,days:s.minDays-1),adults:s.adults,rooms:s.rooms,overrideURL:ProviderLinks.promoURL(p).absoluteString)}label:{HStack{Label(p.name,systemImage:"ticket");Spacer();Text("Find codes").font(.caption)}}
                    }
                    Text("Browse the offer page and tap Capture. Seat-sale fares and claimed coupons may have no code. Account-specific codes appear only when the provider shows them.").font(.caption).foregroundColor(.secondary)
                }
                Section("Published / captured voucher codes") {
                    ForEach(hints){h in
                        VStack(alignment:.leading,spacing:9) {
                            HStack{Text(h.code).font(.system(.headline,design:.monospaced)).textSelection(.enabled);Spacer();Button{copy(h.code)}label:{Image(systemName:"doc.on.doc")}.buttonStyle(.borderless).accessibilityLabel("Copy \(h.code)")}
                            Text(h.provider.name).font(.subheadline.weight(.semibold)).foregroundColor(Theme.teal)
                            if let terms=h.terms{Text(terms).font(.caption).foregroundColor(.secondary)}
                            Text("Observed \(h.capturedAt.formatted(date:.abbreviated,time:.omitted)) · eligibility unverified").font(.caption2).foregroundColor(.secondary)
                            HStack{
                                Button("Check & link to trip"){hint=h}.buttonStyle(.bordered)
                                if let url=URL(string:h.sourceURL),ProviderLinks.allowed(url){Link("Source",destination:url).buttonStyle(.borderless)}
                            }.font(.caption)
                        }.padding(.vertical,6)
                    }
                }
                Section("Your voucher codes") {
                    if store.state.vouchers.isEmpty{Text("Link a code to an exact quote after checking its checkout saving. No code has been subtracted yet.").font(.caption).foregroundColor(.secondary)}
                    ForEach(store.state.vouchers){v in
                        VStack(alignment:.leading,spacing:8) {
                            HStack{Text(v.code).font(.system(.headline,design:.monospaced));Spacer();Button{copy(v.code)}label:{Image(systemName:"doc.on.doc")}.buttonStyle(.borderless)}
                            HStack{Pill(text:v.provider.name);Pill(text:v.confirmed ? "Confirmed" : "Unverified",color:v.confirmed ? Theme.teal : Theme.coral)}
                            Text(v.percentage ? String(format:"%.2f%% off",Double(v.value)/100) : "\(Money.php(v.value)) off").font(.subheadline)
                            Text("Minimum \(Money.php(v.minSpend)) · cap \(v.cap>0 ? Money.php(v.cap) : "none entered")").font(.caption).foregroundColor(.secondary)
                            Text("Book by \(v.bookingEnd) · \(v.eligibleQuoteIDs.count) linked trip(s)").font(.caption).foregroundColor(.secondary)
                            Button("Edit code & eligibility"){editing=v}.font(.caption).buttonStyle(.borderless)
                        }.padding(.vertical,5)
                    }.onDelete{store.state.vouchers.remove(atOffsets:$0);store.save()}
                }
                Section {
                    Text("One best code per provider. Minimum spend, caps, booking dates, travel dates, card, channel and new-customer restrictions are checked. Already-included discounts are not deducted again. Cashback is excluded from payable totals.").font(.caption).foregroundColor(.secondary)
                }
            }.navigationTitle("Voucher codes").searchable(text:$query,prompt:"Code, provider or offer")
            .toolbar{ToolbarItem(placement:.primaryAction){Button{adding=true}label:{Image(systemName:"plus")}}}
            .sheet(isPresented:$adding){VoucherEditor()}
            .sheet(item:$hint){VoucherEditor(hint:$0)}
            .sheet(item:$editing){VoucherEditor(existing:$0)}
            .sheet(item:$browserJob){ScannerView(store:store,initial:$0)}
        }
    }
    private func copy(_ code:String){UIPasteboard.general.string=code;store.toast="Copied \(code)."}
}
