// Licensed under GPL-3.0. See LICENSE.
//
//  OnboardingView.swift
//  Vega
//
//  Created by Maciek Bagiński on 19/02/2026.
//

import VegaDesign
import SwiftUI

struct OnboardingView: View {
    @Environment(\.vegaSettings) var vegaSettings
    @EnvironmentObject var browserManager: BrowserManager

    @State private var currentStage: Int = 0
    @State private var selectedBrowser: Browsers = .arc
    @State private var isLoading: Bool = false
    @State private var showSafariImportFlow: Bool = false

    var body: some View {
        ZStack {
            // A fixed dark backdrop: the stages draw white text. The old blur showed glass while
            // the window was key and plain white once it was not.
            VegaDesign.Surface.onboardingBackdrop
                .overlay {
                    Image("noise_texture")
                        .resizable(resizingMode: .tile)
                        .opacity(VegaDesign.Surface.grainOpacity)
                        .blendMode(.overlay)
                }
                .ignoresSafeArea()

            VStack {
                StageIndicator(stages: 4, activeStage: currentStage)
                Spacer()
                stageView
                    .transition(.slideAndBlur)
                Spacer()
                if !showSafariImportFlow {
                    StageFooter(
                        currentStage: currentStage,
                        totalStages: 4,
                        isLoading: isLoading,
                        onContinue: advance,
                        onBack: goBack,
                        onSkip: skipImport
                    )
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .dark)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.return) {
            if !isLoading && !showSafariImportFlow {
                advance()
                return .handled
            }
            return .ignored
        }
    }

    @ViewBuilder
    private var stageView: some View {
        if showSafariImportFlow {
            SafariImportFlow(
                isLoading: $isLoading,
                onBack: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSafariImportFlow = false
                    }
                },
                onComplete: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSafariImportFlow = false
                        currentStage += 1
                    }
                }
            )
        } else {
            switch currentStage {
            case 0: HelloStage()
            case 1: AccountStage()
            case 2: ImportStage(selectedBrowser: $selectedBrowser)
            case 3: FinalStage()
            default: EmptyView()
            }
        }
    }

    private func advance() {
        guard currentStage < 4 else { return }
        if currentStage == 3 {
            vegaSettings.didFinishOnboarding = true
            // FORK: then a short tour of what Vega can do.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [browserManager] in browserManager.showFeatureTour() }
            return
        }

        if currentStage == 2 && selectedBrowser == .safari {
            withAnimation(.easeInOut(duration: 0.25)) {
                showSafariImportFlow = true
            }
        } else if currentStage == 2 {
            withAnimation(.easeInOut(duration: 0.25)) {
                isLoading = true
            }
            performImport {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentStage += 1
                    isLoading = false
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentStage += 1
            }
        }
    }

    private func performImport(completion: @escaping () -> Void) {
        Task {
            switch selectedBrowser {
            case .arc:
                await browserManager.importArcData()
            case .dia:
                await browserManager.importDiaData()
            default:
                break
            }
            await MainActor.run {
                completion()
            }
        }
    }

    /// Skip moves past the sign-in step or the import step to the next one.
    private func skipImport() {
        withAnimation(.easeInOut(duration: 0.25)) {
            currentStage += 1
        }
    }

    private func goBack() {
        guard currentStage > 0 else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentStage -= 1
        }
    }

}
