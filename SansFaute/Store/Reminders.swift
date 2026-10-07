import Foundation
import UserNotifications

/// Daily local reminder. Nothing leaves the phone.
enum Reminders {
    static let id = "sansfaute.daily"

    static func requestAndSchedule(hour: Int, minute: Int, completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted { schedule(hour: hour, minute: minute) }
                completion(granted)
            }
        }
    }

    static func schedule(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        content.title = "Ta séance de français"
        content.body = messages.randomElement() ?? "Une heure aujourd'hui, et le C2 se rapproche."
        content.sound = .default
        var date = DateComponents()
        date.hour = hour
        date.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    private static let messages = [
        "20 minutes d'écoute, c'est ce qui fera passer ton oral au-dessus de 500.",
        "Ton test du jour t'attend. Quinze minutes, pas plus.",
        "Une dictée et dix cartes de vocabulaire : on y va ?",
        "Chaque jour compte avant le 9 novembre.",
        "Bien qu'il soit tard, tu peux encore faire ta séance. (Subjonctif, bien sûr.)"
    ]
}
