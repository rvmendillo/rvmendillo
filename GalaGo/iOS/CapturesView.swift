import SwiftUI

struct CapturesView:View {
    @EnvironmentObject var store:AppStore
    @State private var query=""
    @State private var picked:PriceCandidate?
    private var items:[PriceCandidate] {
        store.state.candidates.reversed().filter { item in
            query.isEmpty || "\(Destination.find(item.job.destination)?.name ?? item.job.destination) \(item.job.destination) \(item.job.provider.name) \(item.job.departure) \(item.context)".localizedCaseInsensitiveContains(query)
        }
    }
    var body:some View {
        List {
            Section {
                Text("Raw prices need a complete quote").font(.headline)
                Text("A captured number may be per person, per night, a starting fare or a discount. Tap it to review and add the complete trip totals. Only confirmed full quotes appear in Compare.").font(.caption).foregroundColor(.secondary)
            }
            Section("\(items.count) price candidates") {
                ForEach(items) { item in
                    Button{picked=item}label:{
                        VStack(alignment:.leading,spacing:7) {
                            HStack{Text("\(item.job.destination) · \(item.job.provider.name)").font(.headline);Spacer();Text(Money.php(item.amount)).font(.headline).foregroundColor(Theme.teal)}
                            Text("\(item.job.departure) – \(item.job.returning) · \(item.job.adults) adult(s)").font(.caption).foregroundColor(.secondary)
                            Text(item.context).font(.caption).foregroundColor(.secondary).lineLimit(4)
                            Pill(text:"UNVERIFIED PRICE",color:Theme.coral)
                        }.padding(.vertical,5)
                    }
                }
            }
        }
        .navigationTitle("Captured prices")
        .searchable(text:$query,prompt:"Destination, provider or date")
        .sheet(item:$picked){QuoteEditor(candidate:$0)}
    }
}
