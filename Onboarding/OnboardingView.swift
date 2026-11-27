// Licensed under GPL-3.0. See LICENSE.
//
//  OnboardingView.swift
//  Nook
//
//  Created by Maciek Bagiński on 19/02/2026.
//

import NookDesign
import SwiftUI
import NookSettings

struct OnboardingView: View {
    @Environment(\.nookSettings) var nookSettings
    @EnvironmentObject var browserManager: BrowserManager
    @ObservedObject private var extensionManager = ExtensionManager.shared

    @State private var currentStage: Int = 0
    @State private var selectedBrowser = ImportSource.firstAvailable
    @State private var isLoading: Bool = false
    @State private var showSafariImportFlow: Bool = false
    @State private var showChromeImport = false
    /// What Chrome brought over, while its finished card shows.
    @State private var chromeSummary: String?
    @State private var extensionChoices: [ExtensionChoice] = []
    @State private var isFindingExtensions = false

    var body: some View {
        ZStack {
            // A fixed dark backdrop: the stages draw white text. The old blur showed glass while
            // the window was key and plain white once it was not.
            NookDesign.Surface.onboardingBackdrop
                .overlay {
                    Image("noise_texture")
                        .resizable(resizingMode: .tile)
                        .opacity(NookDesign.Surface.grainOpacity)
                        .blendMode(.overlay)
                }
                .ignoresSafeArea()

            VStack {
                StageIndicator(stages: 5, activeStage: currentStage)
                Spacer()
                stageView
                    .transition(.slideAndBlur)
                Spacer()
                if !showsOwnButtons {
                    StageFooter(
                        currentStage: currentStage,
                        totalStages: 5,
                        isLoading: isLoading,
                        canGoBack: !isInstallingExtensions,
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
            if !isLoading && !showsOwnButtons {
                advance()
                return .handled
            }
            return .ignored
        }
    }

    private var showsOwnButtons: Bool {
        showSafariImportFlow || showChromeImport || currentStage == 3
    }

    private var isInstallingExtensions: Bool {
        extensionManager.listInstallProgress.map { !$0.isDone } ?? false
    }

    @ViewBuilder
    private var stageView: some View {
        if showChromeImport {
            DialogCard {
                ImportScroll {
                    if let chromeSummary {
                        ImportFinishedPanel(source: .chrome, summary: chromeSummary, hasExtensions: !extensionChoices.isEmpty,
                                            onDone: { closeChromeImport(review: false) }, onReview: { closeChromeImport(review: true) })
                    } else {
                        ChromeImportPanel(onBack: { withAnimation(.easeInOut(duration: 0.25)) { showChromeImport = false } }) { summary, choices in
                            extensionChoices = choices
                            chromeSummary = summary
                        }
                    }
                }
            }
            .environmentObject(browserManager.gradientColorManager)
        } else if showSafariImportFlow {
            SafariImportFlow(
                isLoading: $isLoading,
                onBack: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSafariImportFlow = false
                    }
                },
                onComplete: {
                    showExtensions(includingArc: false)
                }
            )
        } else {
            switch currentStage {
            case 0: HelloStage()
            case 1: AccountStage()
            case 2: ImportStage(selectedBrowser: $selectedBrowser)
            case 3: ExtensionsStage(
                choices: extensionChoices,
                preview: { await extensionManager.consentPreview(of: $0) },
                onDone: finishExtensions
            )
            case 4: FinalStage(extensionManager: extensionManager)
            default: EmptyView()
            }
        }
    }

    private func advance() {
        guard currentStage < 5, !isFindingExtensions else { return }
        if currentStage == 4 {
            nookSettings.didFinishOnboarding = true
            // FORK: then a short tour of what Vega can do.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [browserManager] in browserManager.showFeatureTour() }
            return
        }

        if currentStage == 2 && selectedBrowser == .chrome {
            withAnimation(.easeInOut(duration: 0.25)) {
                chromeSummary = nil
                showChromeImport = true
            }
        } else if currentStage == 2 && selectedBrowser == .safari {
            withAnimation(.easeInOut(duration: 0.25)) {
                showSafariImportFlow = true
            }
        } else if currentStage == 2 {
            withAnimation(.easeInOut(duration: 0.25)) {
                isLoading = true
            }
            performImport {
                showExtensions(includingArc: selectedBrowser == .arc)
            }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentStage += 1
            }
        }
    }

    private func performImport(completion: @escaping () -> Void) {
        let browser = selectedBrowser
        Task {
            let summary: String? = switch browser {
            case .arc: await browserManager.importArcData()
            case .dia: await browserManager.importDiaData()
            default: ""
            }
            await MainActor.run {
                // The menu's import says this; the first launch moved on as if it had worked.
                if summary == nil {
                    SystemAlert.present(SystemAlert.make("Couldn't import", "Vega didn't find anything to import from \(browser.name).",
                                                         style: .warning, buttons: ["OK"])) { _ in }
                }
                completion()
            }
        }
    }

    private func closeChromeImport(review: Bool) {
        withAnimation(.easeInOut(duration: 0.25)) {
            showChromeImport = false
            currentStage = review ? 3 : 4
        }
    }

    /// Skip moves past the sign-in step, or from the import step on to the extensions.
    private func skipImport() {
        guard !isFindingExtensions else { return }
        if currentStage == 2 {
            showExtensions(includingArc: false)
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { currentStage += 1 }
        }
    }

    private func showExtensions(includingArc: Bool) {
        isFindingExtensions = true
        Task {
            let choices = await browserManager.extensionChoices(includingArc: includingArc)
            isFindingExtensions = false
            withAnimation(.easeInOut(duration: 0.25)) {
                showSafariImportFlow = false
                isLoading = false
                extensionChoices = choices
                currentStage = choices.isEmpty ? 4 : 3
            }
        }
    }

    private func finishExtensions(_ chosen: [ExtensionOffer]) {
        guard currentStage == 3 else { return }
        extensionManager.install(chosen)
        withAnimation(.easeInOut(duration: 0.25)) {
            currentStage = 4
        }
    }

    private func goBack() {
        guard currentStage > 0 else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentStage = currentStage == 4 ? 2 : currentStage - 1
        }
    }

}
