import SwiftUI

struct C2PAStatusView: View {
    let mediaItem: MediaItem

    var body: some View {
        VStack {
            Text("C2PA Status")
                .font(.headline)

            if let manifest = mediaItem.c2paManifest {
                Text("C2PA Manifest Found")
                    .foregroundColor(.green)
                Text("Format: \(manifest.format)")
                Text("Title: \(manifest.title)")
            } else {
                Text("No C2PA Manifest")
                    .foregroundColor(.gray)
            }
        }
        .padding()
    }
}
