import Foundation

/// Legge l'URL e la anon key di Supabase dal bundle (Info.plist),
/// popolati a build time tramite `Secrets.xcconfig`.
///
/// Vedi `Habits/Config/Secrets.example.xcconfig` per il template.
enum SupabaseConfig {
    static var url: URL {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            !raw.isEmpty,
            let url = URL(string: raw.hasPrefix("http") ? raw : "https://\(raw)")
        else {
            fatalError("""
            SUPABASE_URL mancante. Crea `Habits/Config/Secrets.xcconfig` partendo da \
            `Secrets.example.xcconfig` e imposta SUPABASE_URL / SUPABASE_ANON_KEY.
            """)
        }
        return url
    }

    static var anonKey: String {
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !key.isEmpty
        else {
            fatalError("SUPABASE_ANON_KEY mancante. Vedi Secrets.example.xcconfig.")
        }
        return key
    }
}
