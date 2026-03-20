import Foundation

struct WatchL10n {
    static func string(_ key: String, locale: String) -> String {
        return strings[locale]?[key] ?? strings["en"]![key] ?? key
    }

    static func setOf(_ current: Int, _ total: Int, locale: String) -> String {
        let template = string("set_of", locale: locale)
        return String(format: template, current, total)
    }

    private static let strings: [String: [String: String]] = [
        "en": [
            "resting": "Resting",
            "set_of": "SET %d/%d",
            "log_set": "LOG SET",
            "log": "LOG",
            "confirm_weight_reps": "CONFIRM WEIGHT & REPS",
            "next": "NEXT",
            "session": "SESSION",
            "reps": "reps",
            "force_sync": "Force Sync",
            "sync_failed": "Sync failed — try again",
            "no_active_workout": "No active workout",
            "start_on_iphone": "Start one on your iPhone",
            "workout_complete": "Workout Complete",
            "start": "START",
            "stop": "STOP",
            "open_on_iphone": "Open StrengthApp on your iPhone",
            "install_on_iphone": "Install StrengthApp on your iPhone",
        ],
        "fr": [
            "resting": "Repos",
            "set_of": "SERIE %d/%d",
            "log_set": "VALIDER",
            "log": "OK",
            "confirm_weight_reps": "CONFIRMER POIDS & REPS",
            "next": "SUIVANT",
            "session": "SESSION",
            "reps": "reps",
            "force_sync": "Forcer la synchro",
            "sync_failed": "Echec synchro — reessayer",
            "no_active_workout": "Aucun entrainement actif",
            "start_on_iphone": "Lancez-en un sur votre iPhone",
            "workout_complete": "Entrainement termine",
            "start": "DEMARRER",
            "stop": "STOP",
            "open_on_iphone": "Ouvrez StrengthApp sur votre iPhone",
            "install_on_iphone": "Installez StrengthApp sur votre iPhone",
        ],
    ]
}
