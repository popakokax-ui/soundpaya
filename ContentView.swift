import SwiftUI

struct ContentView: View {
    @EnvironmentObject var client: RemoteClient
    @State private var playing: String?

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                connectionBar
                if client.connected {
                    if client.sounds.isEmpty {
                        Spacer()
                        Text("Папка sounds на компьютере пуста.\nДобавь туда .mp3/.wav/.ogg и обнови.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding()
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(client.sounds, id: \.self) { name in
                                    SoundButton(name: name, isPlaying: playing == name) {
                                        playing = name
                                        Task {
                                            await client.play(name)
                                            try? await Task.sleep(nanoseconds: 300_000_000)
                                            if playing == name { playing = nil }
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        volumeBar
                    }
                } else {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(client.statusText)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 32)
                    }
                    Spacer()
                }
            }
            .navigationTitle("Пульт звуков")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await client.refreshSounds() }
                    } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(!client.connected)
                }
            }
        }
    }

    private var connectionBar: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("IP компьютера, напр. 192.168.1.5", text: $client.host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                TextField("Порт", text: $client.port)
                    .frame(width: 70)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                Button("Подключить") { Task { await client.connect() } }
                    .buttonStyle(.borderedProminent)
            }
            HStack {
                Circle()
                    .fill(client.connected ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(client.statusText).font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var volumeBar: some View {
        HStack {
            Image(systemName: "speaker.fill")
            Slider(value: Binding(get: { client.volume }, set: { v in
                client.volume = v
                Task { await client.setVolume(v) }
            }), in: 0...1)
            Image(systemName: "speaker.wave.3.fill")
            Button(role: .destructive) { Task { await client.stop() } } label: {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

struct SoundButton: View {
    let name: String
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: isPlaying ? "waveform" : "play.circle.fill")
                    .font(.system(size: 26))
                Text(displayName)
                    .font(.footnote.bold())
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isPlaying ? Color.accentColor.opacity(0.25) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var displayName: String {
        (name as NSString).deletingPathExtension
    }
}
