//
//  ToastCenter.swift
//  MusicAI
//
//  Created by 林恩佑 on 2025/11/11.
//

import SwiftUI
import UIKit

// 單例資料中心
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()
    @Published var toast: Toast? = nil
    private init() {}

    struct Toast: Identifiable {
        let id       = UUID()
        let title    : String
        let message  : String
        let symbolName: String?
        let duration : TimeInterval
    }

    /// 顯示 Toast。若 haptic = true 則震動觸發。
    func show(title: String,
              message: String,
              symbolName: String? = nil,
              duration: TimeInterval = 3.1,
              haptic: Bool = true)
    {
        DispatchQueue.main.async {
            if haptic {
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                generator.notificationOccurred(.success)
            }

            // 出現：彈性淡入
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                self.toast = Toast(title: title,
                                   message: message,
                                   symbolName: symbolName,
                                   duration: duration)
            }

            // 消失：平滑淡出
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                withAnimation(.easeOut(duration: 0.28)) {
                    self.toast = nil
                }
            }
        }
    }
}

// MARK: -- Liquid Glass 材質 Modifier
private struct LiquidGlass: ViewModifier {
    var cornerRadius: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .padding(0)
            // 基底：霧面材質
            .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius, style: .continuous))
            // 內層霧白柔光，提升對比
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.22), location: 0.0),
                                .init(color: .white.opacity(0.06), location: 0.5),
                                .init(color: .clear,             location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.softLight)
            )
            // 高光描邊
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.36),
                                     Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            // 微內陰影
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    .blur(radius: 2)
                    .mask(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.black, Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            // 投影：漂浮感
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
    }
}

private extension View {
    func liquidGlass(cornerRadius: CGFloat = 14) -> some View {
        modifier(LiquidGlass(cornerRadius: cornerRadius))
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
                Text(toast.title)
                    .font(.headline)
                Text(toast.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .foregroundStyle(.primary) // 文字用標準前景色，適應淺/深模式
        .background(Color(uiColor: .systemBackground).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
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
                        .id(toast.id) // 確保插入/移除對應同一個視圖
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal:   .move(edge: .bottom).combined(with: .opacity)
                            )
                        )
                        .padding(.bottom, 24)
                }
            }
        }
    }
}

extension View {
    func toastOverlay() -> some View {
        modifier(ToastOverlay())
    }
}
