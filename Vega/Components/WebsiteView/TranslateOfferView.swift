// Licensed under GPL-3.0. See LICENSE.
//
//  TranslateOfferView.swift
//  Vega
//
//  The card offering to translate a page in another language, and the invisible host whose
//  .translationTask gives a page a session that can download a language pair.
//

import SwiftUI
import Translation
import VegaDesign
import VegaUI
import VegaWeb

struct TranslateOfferView: View {
    let session: PageSession
    let language: Locale.Language

    private var languageName: String {
        let code = language.languageCode?.identifier ?? language.minimalIdentifier
        return Locale.current.localizedString(forLanguageCode: code) ?? code
    }

    var body: some View {
        HStack(spacing: VegaDesign.Spacing.md) {
            Text("Translate from \(languageName)?")
                .font(VegaDesign.Font.body)
                .foregroundStyle(.primary)
                .padding(.leading, VegaDesign.Spacing.sm)
            HStack(spacing: VegaDesign.Spacing.xxs) {
                Button("Not Now") { session.declineTranslationOffer() }
                Button("Translate") { session.toggleTranslation() }
            }
            .buttonStyle(RectNavButtonStyle())
            .controlSize(.small)
        }
        .padding(VegaDesign.Spacing.xxs)
        .vegaFloatingSurface(in: VegaDesign.Radius.shape(VegaDesign.Radius.md))
    }
}

/// Runs a translation that needs the system's download sheet. Keyed by the page, so switching
/// tabs ends the old page's task and coming back resumes it.
struct TranslationTaskHost: View {
    let session: PageSession

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .translationTask(session.translationRequest) { translator in
                await session.runTranslation(with: translator)
            }
            .id(session.itemID)
    }
}
