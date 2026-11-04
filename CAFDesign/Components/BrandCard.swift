import SwiftUI

/// Solid raised surface + hairline + radius 20. Never glass (content layer).
struct BrandCard<Content: View>: View {
    var padding: CGFloat = Space.m
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Color.hairline, lineWidth: 1))
    }
}

extension View {
    /// Card chrome for an existing view (rows in lists).
    func brandCardBackground(radius: CGFloat = Radius.card) -> some View {
        background(Color.surfaceRaised, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.hairline, lineWidth: 1))
    }
}

/// Page ground: surface colour with the optional brand dot grid.
struct BrandBackground: View {
    var dots = false
    var body: some View {
        ZStack { Color.surface; FlowingLinesLayer(); if dots { DotGrid().opacity(0.8) } }.ignoresSafeArea()
    }
}
