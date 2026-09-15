import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "battery.100.bolt")
                .font(.system(size: 56))
                .foregroundStyle(.mint)
            Text("Glide")
                .font(.title.bold())
            Text("v2 skeleton — battery UI lands in the next step")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(48)
        .frame(minWidth: 380, minHeight: 260)
    }
}
