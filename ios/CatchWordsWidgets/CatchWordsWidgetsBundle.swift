import WidgetKit
import SwiftUI

@main
struct CatchWordsWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWordWidget()
        ReviewWidget()
        ReviewLiveActivity()
    }
}
