import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ScanResultSectionView: View {
    let flowModel: ScanFlowModel

    var body: some View {
        Group {
            if flowModel.isProcessing {
                contentCard {
                    ProcessingStateView(phase: flowModel.phase)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let analysis = flowModel.analysis, flowModel.normalizedText.isEmpty == false {
                contentCard {
                    detectionResultView(analysis: analysis)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: flowModel.isProcessing)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: flowModel.analysis?.verdict)
    }

    private func contentCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveCardSurface(cornerRadius: 24)
    }

    private func detectionResultView(analysis: ScanAnalysis) -> some View {
        DetectionResultView(
            analysis: analysis,
            capturedImage: capturedImage,
            detectionBoxes: flowModel.highlightedBoxes,
            isShowingFullText: Binding(
                get: { flowModel.isShowingFullText },
                set: { flowModel.isShowingFullText = $0 }
            )
        )
    }

#if os(iOS)
    private var capturedImage: UIImage? {
        flowModel.analysis?.capturedImageData.flatMap(UIImage.init(data:))
    }
#else
    private var capturedImage: UIImage? { nil }
#endif
}
