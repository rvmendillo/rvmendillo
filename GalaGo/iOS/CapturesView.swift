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
                Text("Captured prices feed your totals").font(.headline)
                Text("Recognized rate units are multiplied automatically in Prices. Tap a capture to confirm its unit, or exclude a teaser, discount or mismatched offer.").font(.caption).foregroundColor(.secondary)
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
        .sheet(item:$picked){CaptureReviewView(candidate:$0)}
    }
}
