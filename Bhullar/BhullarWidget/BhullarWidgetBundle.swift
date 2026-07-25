import SwiftUI
import WidgetKit

@main
struct BhullarWidgetBundle: WidgetBundle {
    var body: some Widget {
        BhullarDayWidget()
        BhullarYearWidget()
        BhullarScaleWidget()
    }
}
