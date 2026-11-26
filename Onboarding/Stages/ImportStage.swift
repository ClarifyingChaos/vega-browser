// Licensed under GPL-3.0. See LICENSE.
//
//  ImportStage.swift
//  Nook
//
//  Created by Maciek Bagiński on 19/02/2026.
//

import NookDesign
import SwiftUI

struct ImportStage: View {
    @Binding var selectedBrowser: ImportSource

    var body: some View {
        VStack(spacing: 24) {
            Text("Transition to Vega")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            BrowserPicker(selection: $selectedBrowser)
                .frame(maxWidth: NookDesign.Size.sheetSmallWidth)
        }
    }
}
