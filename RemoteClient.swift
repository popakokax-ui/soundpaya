import Foundation

struct SoundsResponse: Decodable { let sounds: [String] }
struct OkResponse: Decodable { let ok: Bool; let error: String? }
struct PingResponse: Decodable { let ok: Bool; let name: String? }

enum RemoteError: LocalizedError {
    case badAddress, server(String)
    var errorDescription: String? {
        switch self {
        case .badAddress: return "Проверь IP и порт компьютера"
        case .server(let m): return m
        }
    }
}

@MainActor
final class RemoteClient: ObservableObject {
    @Published var host: String {
        didSet { UserDefaults.standard.set(host, forKey: "host") }
    }
    @Published var port: String {
        didSet { UserDefaults.standard.set(port, forKey: "port") }
    }
    @Published var sounds: [String] = []
    @Published var connected = false
    @Published var statusText = "Не подключено"
    @Published var volume: Double = 1.0

    init() {
        host = UserDefaults.standard.string(forKey: "host") ?? ""
        port = UserDefaults.standard.string(forKey: "port") ?? "5566"
    }

    private func base() -> URL? {
        guard !host.trimmingCharacters(in: .whitespaces).isEmpty,
              let p = Int(port) else { return nil }
        return URL(string: "http://\(host.trimmingCharacters(in: .whitespaces)):\(p)")
    }

    func connect() async {
        guard let url = base()?.appendingPathComponent("ping") else {
            statusText = "Проверь IP и порт"
            connected = false
            return
        }
        statusText = "Подключаюсь…"
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let r = try JSONDecoder().decode(PingResponse.self, from: data)
            connected = r.ok
            statusText = r.ok ? "Подключено: \(r.name ?? "компьютер")" : "Сервер ответил с ошибкой"
            if r.ok { await refreshSounds() }
        } catch {
            connected = false
            statusText = "Не удалось подключиться: проверь, что сервер запущен и телефон в той же сети"
        }
    }

    func refreshSounds() async {
        guard let url = base()?.appendingPathComponent("sounds") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let r = try JSONDecoder().decode(SoundsResponse.self, from: data)
            sounds = r.sounds
        } catch {
            statusText = "Не удалось получить список звуков"
        }
    }

    func play(_ name: String) async {
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = base()?.appendingPathComponent("play").appendingPathComponent(encoded) else { return }
        await post(url)
    }

    func stop() async {
        guard let url = base()?.appendingPathComponent("stop") else { return }
        await post(url)
    }

    func setVolume(_ v: Double) async {
        volume = v
        guard let url = base()?.appendingPathComponent("volume").appendingPathComponent(String(format: "%.2f", v)) else { return }
        await post(url)
    }

    private func post(_ url: URL) async {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        do {
            _ = try await URLSession.shared.data(for: req)
        } catch {
            statusText = "Команда не дошла до компьютера"
            connected = false
        }
    }
}
