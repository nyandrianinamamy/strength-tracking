import Foundation

enum WorkoutStrings {
    static func locale(_ raw: String) -> String { raw.lowercased().hasPrefix("fr") ? "fr" : "en" }
    static func string(_ key: String, locale raw: String) -> String {
        let table = locale(raw) == "fr" ? french : english
        return table[key] ?? english[key] ?? key
    }
    static func setOf(_ current: Int, _ total: Int, locale: String) -> String {
        String(format: string("set_of", locale: locale), current, total)
    }
    static func notificationBody(exercise: String, locale: String) -> String {
        String(format: string("rest_body", locale: locale), exercise)
    }
    private static let english = [
        "set_of": "SET %d/%d", "next": "Next", "last": "Last", "target": "Target",
        "rest": "Rest", "reps": "reps", "session": "Session", "progress": "Progress",
        "ready": "Ready for next set", "exercise_of": "Exercise %d of %d",
        "sync_failed": "Sync failed — try again", "no_active_workout": "No active workout",
        "start_on_iphone": "Start one on your iPhone", "workout_complete": "Workout Complete",
        "rest_complete": "Rest timer complete", "rest_body": "Rest complete. Back to %@.",
    ]
    private static let french = [
        "set_of": "SÉRIE %d/%d", "next": "Suivant", "last": "Dernier", "target": "Objectif",
        "rest": "Repos", "reps": "rép.", "session": "Séance", "progress": "Progression",
        "ready": "Prêt pour la prochaine série", "exercise_of": "Exercice %d sur %d",
        "sync_failed": "Échec de synchronisation — réessayez", "no_active_workout": "Aucune séance active",
        "start_on_iphone": "Lancez-en une sur votre iPhone", "workout_complete": "Séance terminée",
        "rest_complete": "Repos terminé", "rest_body": "Repos terminé. Reprenez %@.",
    ]
}
