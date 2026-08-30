import SwiftUI

struct DailyPlanNetworkBackdrop: View {
    let reduceMotion: Bool

    var body: some View {
        BootNetworkCore(reduceMotion: DailyPlanPresentationPolicy.pausesNetworkAnimation(reduceMotion: reduceMotion))
            .frame(maxWidth: 860, maxHeight: 680)
            .scaleEffect(1.04)
            .opacity(reduceMotion ? 0.055 : 0.075)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
