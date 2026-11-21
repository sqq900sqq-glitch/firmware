import SwiftUI

struct ContentView: View {
    @AppStorage("deviceURL") private var deviceURL: String = "http://bruce.local"
    @State private var addressField: String = ""
    @State private var reloadToken = UUID()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("http://bruce.local", text: $addressField)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit(go)
                Button("Go", action: go)
                Button {
                    reloadToken = UUID()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .padding(8)

            if let url = URL(string: deviceURL) {
                WebView(url: url, reloadToken: reloadToken)
            } else {
                Spacer()
                Text("Invalid address").foregroundColor(.secondary)
                Spacer()
            }
        }
        .onAppear { addressField = deviceURL }
    }

    private func go() {
        var text = addressField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if !text.lowercased().hasPrefix("http://") && !text.lowercased().hasPrefix("https://") {
            text = "http://" + text
        }
        addressField = text
        deviceURL = text
        reloadToken = UUID()
    }
}
