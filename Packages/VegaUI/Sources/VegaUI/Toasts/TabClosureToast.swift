// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
//
//  TabClosureToast.swift
//  Vega
//
//  Created by Jonathan Caudill on 02/10/2025.
//

import SwiftUI
import VegaDesign

public struct TabClosureToast: View {
    @Environment(\.tabActions) private var actions

    private var count: Int { actions?.tabClosureToastCount ?? 0 }

    public init() {}

    public var body: some View {
        ToastView {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise")
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

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) tab\(count > 1 ? "s" : "") closed")
                        .font(VegaDesign.Font.secondary)
                        .foregroundStyle(.white)

                    Text("Press ⌘Z to undo")
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .transition(.toast)
        .onAppear {
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                actions?.hideTabClosureToast()
            }
        }
        .onTapGesture {
            actions?.hideTabClosureToast()
        }
    }
}
