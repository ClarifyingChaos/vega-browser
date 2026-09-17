//
//  CopyURLToast.swift
//  Vega
//
//  Created on 2025-01-XX.
//

import SwiftUI
import VegaDesign
import VegaWeb

struct CopyURLToast: View {
    @Environment(BrowserWindowState.self) private var windowState

    var body: some View {
        ToastView {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(VegaDesign.Font.secondary)
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .padding(4)
                    .background(Color.white.opacity(0.2))
                    .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.sm))
                    .overlay {
                        VegaDesign.Radius.shape(VegaDesign.Radius.sm)
                            .stroke(.white.opacity(0.4), lineWidth: 1)
                    }

                Text("Copied Current URL")
                    .font(VegaDesign.Font.secondary)
                    .foregroundStyle(.white)
            }
        }
        .transition(.toast)
        .onAppear {
            // Auto-dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                windowState.isShowingCopyURLToast = false
            }
        }
        .onTapGesture {
            windowState.isShowingCopyURLToast = false
        }
    }
}

