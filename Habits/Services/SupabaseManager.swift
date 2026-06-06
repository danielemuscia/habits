import Foundation
import Supabase

/// Singleton che espone il client Supabase condiviso.
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        let options = SupabaseClientOptions(
            db: SupabaseClientOptions.DatabaseOptions(decoder: SupabaseManager.decoder),
            auth: SupabaseClientOptions.AuthOptions(emitLocalSessionAsInitialSession: true)
        )
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: options
        )
    }

    /// Formatter per le colonne `date` (yyyy-MM-dd).
    /// Usa il fuso locale: il "giorno" salvato coincide con quello che vede l'utente,
    /// e il parsing restituisce la mezzanotte locale (coerente coi confronti di calendario).
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Decoder che gestisce sia i `timestamptz` ISO8601 (con/senza frazioni di secondo)
    /// sia le colonne `date` in formato `yyyy-MM-dd`.
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            let string = try container.decode(String.self)

            if let date = isoWithFractional.date(from: string) { return date }
            if let date = isoPlain.date(from: string) { return date }
            if let date = dateFormatter.date(from: string) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Formato data non riconosciuto: \(string)"
            )
        }
        return decoder
    }()

    private static let isoWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
