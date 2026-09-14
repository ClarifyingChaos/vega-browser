//
//  ProfileRowView.swift
//  Vega
//
//  Row used in Profiles settings list.
//

import SwiftUI

struct ProfileRowView: View {
    let profile: Profile
    let isCurrent: Bool
    let spacesCount: Int
    let tabsCount: Int
    let dataSizeDescription: String
    let pinnedCount: Int
    let onMakeCurrent: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let onManageData: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: VegaDesign.Spacing.lg) {
            // Icon
            ZStack {
                VegaDesign.Radius.shape(VegaDesign.Radius.sm)
                    .fill(VegaDesign.Surface.raised)
                Image(systemName: profile.icon)
                    .font(VegaDesign.Font.heading)
            }
            .frame(
                width: VegaDesign.Size.settingsIcon,
                height: VegaDesign.Size.settingsIcon
            )

            // Info
            VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                HStack(spacing: VegaDesign.Spacing.md) {
                    Text(profile.name)
                        .font(VegaDesign.Font.label)
                        .lineLimit(1)
                    if isCurrent {
                        Label("Current", systemImage: "checkmark.seal.fill")
                            .labelStyle(.titleAndIcon)
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.green)
                    }
                }
                HStack(spacing: VegaDesign.Spacing.md) {
                    Label("\(spacesCount) spaces", systemImage: "rectangle.3.group")
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.secondary)
                    Text("•").font(VegaDesign.Font.caption).foregroundStyle(.secondary)
                    Label("\(tabsCount) tabs", systemImage: "rectangle.stack")
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.secondary)
                    Text("•").font(VegaDesign.Font.caption).foregroundStyle(.secondary)
                    Label("\(pinnedCount) pinned", systemImage: "pin")
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.secondary)
                    Text("•").font(VegaDesign.Font.caption).foregroundStyle(.secondary)
                    Label(dataSizeDescription, systemImage: "internaldrive")
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: VegaDesign.Spacing.sm) {
                Button(action: onManageData) {
                    Label("Manage Data", systemImage: "wrench.and.screwdriver")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Manage data for this profile")

                Button(action: onRename) {
                    Label("Rename", systemImage: "pencil")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Rename profile")

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Delete profile")

                if !isCurrent {
                    Button(action: onMakeCurrent) {
                        Label("Make Current", systemImage: "checkmark.circle")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(VegaDesign.Spacing.md)
        .background(
            VegaDesign.Radius.shape(VegaDesign.Radius.md)
                .fill(isHovering ? VegaDesign.Surface.fill : Color.clear)
        )
        .onHoverTracking { hovering in
            withAnimation(VegaDesign.Motion.quick) { isHovering = hovering }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Profile row: \(profile.name)")
        .accessibilityHint(isCurrent ? "Current profile" : "Inactive profile")
    }
}
