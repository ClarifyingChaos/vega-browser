// Licensed under GPL-3.0. See LICENSE.
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
                VegaSymbol("arrow.counterclockwise", size: 15)
                    .font(VegaDesign.Font.secondary)
                    .foregroundStyle(.primary)
                    .frame(width: 14, height: 14)
                    .padding(4)
                    .background(VegaDesign.Surface.fill)
                    .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.sm))
                    .overlay {
                        VegaDesign.Radius.shape(VegaDesign.Radius.sm)
                            .stroke(VegaDesign.Surface.hairline, lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) tab\(count > 1 ? "s" : "") closed")
                        .font(VegaDesign.Font.secondary)
                        .foregroundStyle(.primary)

                    Text("Press ⌘Z to undo")
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.secondary)
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
