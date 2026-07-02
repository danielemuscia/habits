import Foundation
import UserNotifications

/// Gestisce il reminder giornaliero per inserire le abitudini del giorno.
///
/// Si tratta di una notifica **locale** (`UNUserNotificationCenter`), pianificata
/// sul device: l'app è local-first e non ha un server, quindi non esistono
/// notifiche push remote — la notifica è schedulata a ripetizione giornaliera
/// dal sistema operativo all'orario scelto dall'utente.
@MainActor
final class ReminderManager: NSObject, ObservableObject {
    static let shared = ReminderManager()

    private static let notificationIdentifier = "daily-habit-reminder"
    private static let enabledKey = "reminder.enabled"
    private static let hourKey = "reminder.hour"
    private static let minuteKey = "reminder.minute"

    @Published private(set) var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            scheduleOrCancel()
        }
    }

    /// Solo ora/minuti contano: giorno/mese/anno del `Date` sono ignorati.
    @Published var time: Date {
        didSet {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
            UserDefaults.standard.set(comps.hour, forKey: Self.hourKey)
            UserDefaults.standard.set(comps.minute, forKey: Self.minuteKey)
            scheduleOrCancel()
        }
    }

    private override init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        let hour = defaults.object(forKey: Self.hourKey) as? Int ?? 20
        let minute = defaults.object(forKey: Self.minuteKey) as? Int ?? 0
        time = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Da chiamare all'avvio dell'app: riallinea la notifica pianificata con lo
    /// stato salvato, così sopravvive a riavvii/reinstall (idempotente).
    func syncOnLaunch() {
        guard isEnabled else { return }
        scheduleOrCancel()
    }

    /// Attiva/disattiva il reminder. Se attivato, richiede il permesso di notifica
    /// (se non è già stato concesso o negato). Ritorna `false` se l'utente nega.
    @discardableResult
    func setEnabled(_ enabled: Bool) async -> Bool {
        guard enabled else {
            isEnabled = false
            return true
        }
        let granted = await requestAuthorization()
        isEnabled = granted
        return granted
    }

    /// Stato corrente del permesso di sistema, usato in UI per spiegare perché
    /// il reminder non si attiva (es. notifiche negate dalle Impostazioni).
    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    private func scheduleOrCancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        guard isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Abitudini di oggi"
        content.body = "Ricordati di registrare le tue abitudini di oggi."
        content.sound = .default

        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
}

extension ReminderManager: UNUserNotificationCenterDelegate {
    /// Mostra la notifica (banner + suono) anche quando l'app è in foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
