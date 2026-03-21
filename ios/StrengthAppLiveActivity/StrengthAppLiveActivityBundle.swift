import SwiftUI
import WidgetKit

@main
struct StrengthAppLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOSApplicationExtension 16.2, *) {
            StrengthAppWorkoutLiveActivity()
        }
    }
}
