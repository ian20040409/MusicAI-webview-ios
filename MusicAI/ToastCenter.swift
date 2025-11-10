//
//  ToastCenter.swift
//  MusicAI
//
//  Created by 林恩佑 on 2025/11/11.
//


import SwiftUI

// 單例資料中心
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()
    @Published var toast: Toast? = nil
    private init() {}

    struct Toast: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let symbolName: String?
        let duration: TimeInterval
    }

    func show(title: String, message: String, symbolName: String? = nil, duration: TimeInterval = 2.5) {
        DispatchQueue.main.async {
            self.toast = Toast(title: title, message: message, symbolName: symbolName, duration: duration)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                if self.toast?.id != nil { self.toast = nil }
            }
        }
    }
}

// Toast 視圖
private struct ToastView: View {
    let toast: ToastCenter.Toast
    var body: some View {
        HStack(spacing: 12) {
            if let symbol = toast.symbolName {
                Image(systemName: symbol)
                    .imageScale(.large)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title).font(.headline)
                Text(toast.message).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(radius: 8, y: 6)
        .padding(.horizontal, 16)
    }
}

// 方便掛在任何 View 上
struct ToastOverlay: ViewModifier {
    @ObservedObject var center = ToastCenter.shared
    func body(content: Content) -> some View {
        ZStack {
            content
            if let toast = center.toast {
                VStack {
                    Spacer()
                    ToastView(toast: toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 24)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.88), value: toast.id)
            }
        }
    }
}

extension View {
    func toastOverlay() -> some View {
        modifier(ToastOverlay())
    }
}
