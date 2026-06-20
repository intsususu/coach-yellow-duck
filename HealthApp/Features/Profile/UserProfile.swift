// UserProfile.swift
// 「我的」用户资料模型 + 本地持久化 Store + 头像吸色工具。
// 资料（昵称/身高/年龄/性别/状态）以 JSON 存 UserDefaults；头像图片存 Documents；
// 头像主色调由图片吸色实时计算，驱动顶部沉浸式渐变背景。

import SwiftUI
import UIKit

// MARK: - 性别

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male, female, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .male: return "男"
        case .female: return "女"
        case .other: return "其他"
        }
    }
}

// MARK: - 用户资料

struct UserProfile: Codable, Equatable {
    var nickname: String
    var statusTag: String      // 个性标签，如「减脂中」
    var heightCm: Int
    var age: Int
    var gender: Gender

    static let `default` = UserProfile(
        nickname: "李",
        statusTag: "减脂中",
        heightCm: 178,
        age: 34,
        gender: .male
    )

    /// 头部副标题：178cm · 34 岁 · 男
    var detailLine: String {
        "\(heightCm)cm · \(age) 岁 · \(gender.label)"
    }

    /// 头部主标题：昵称 · 状态标签（状态为空则只显示昵称）
    var headline: String {
        statusTag.isEmpty ? nickname : "\(nickname) · \(statusTag)"
    }
}

// MARK: - 存储位置偏好（隐私与安全，当前仅记录偏好，iCloud 同步后续开放）

enum StorageLocation: String, Codable, CaseIterable, Identifiable {
    case local, iCloud
    var id: String { rawValue }
    var label: String {
        switch self {
        case .local: return "本机存储"
        case .iCloud: return "iCloud 同步"
        }
    }
    var icon: String {
        switch self {
        case .local: return "iphone"
        case .iCloud: return "icloud.fill"
        }
    }
}

// MARK: - Store：单一数据源，本地持久化

@MainActor
final class ProfileStore: ObservableObject {

    private enum Key {
        static let profile = "userProfile"
        static let storage = "storageLocation"
    }
    private static let avatarFileName = "avatar.jpg"

    @Published var profile: UserProfile { didSet { persistProfile() } }
    @Published var storageLocation: StorageLocation { didSet { persistStorage() } }

    /// 已上传的头像（无则为 nil，使用小黄鸡占位图）。
    @Published private(set) var avatarImage: UIImage?
    /// 头像吸取的主色调（无头像时取品牌蓝），用于顶部沉浸式渐变。
    @Published private(set) var avatarColor: Color = .brandBlue

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let data = userDefaults.data(forKey: Key.profile),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = decoded
        } else {
            profile = .default
        }

        if let raw = userDefaults.string(forKey: Key.storage),
           let loc = StorageLocation(rawValue: raw) {
            storageLocation = loc
        } else {
            storageLocation = .local
        }

        loadAvatarFromDisk()
    }

    // MARK: 头像

    /// 顶部沉浸式背景的柔化主色：保留色相、降低饱和提亮，柔和但明显有色（不退成白）。
    var headerTint: Color {
        avatarColor.softTint()
    }

    /// 保存新头像：压缩落盘 + 重新吸色。传 nil 清除头像、回到占位图。
    func updateAvatar(_ image: UIImage?) {
        guard let image else {
            try? FileManager.default.removeItem(at: Self.avatarURL)
            avatarImage = nil
            avatarColor = .brandBlue
            return
        }
        let resized = image.resized(maxDimension: 512)
        if let data = resized.jpegData(compressionQuality: 0.85) {
            try? data.write(to: Self.avatarURL, options: .atomic)
        }
        avatarImage = resized
        avatarColor = resized.dominantColor() ?? .brandBlue
    }

    private func loadAvatarFromDisk() {
        guard let data = try? Data(contentsOf: Self.avatarURL),
              let image = UIImage(data: data) else {
            avatarImage = nil
            avatarColor = .brandBlue
            return
        }
        avatarImage = image
        avatarColor = image.dominantColor() ?? .brandBlue
    }

    private static var avatarURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(avatarFileName)
    }

    // MARK: 持久化

    private func persistProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            userDefaults.set(data, forKey: Key.profile)
        }
    }

    private func persistStorage() {
        userDefaults.set(storageLocation.rawValue, forKey: Key.storage)
    }
}

// MARK: - 头像吸色 / 图片处理

extension UIImage {
    /// 按饱和度加权取主色：彩色像素权重大、灰/黑/白几乎不计，
    /// 避免整图平均把鲜艳色糊成灰。整图近乎无彩色时退回普通平均。
    func dominantColor() -> Color? {
        guard let cgImage else { return nil }
        let w = 48, h = 48
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &data,
                                  width: w, height: h,
                                  bitsPerComponent: 8,
                                  bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        var rW = 0.0, gW = 0.0, bW = 0.0, weightSum = 0.0   // 饱和度加权
        var rP = 0.0, gP = 0.0, bP = 0.0, count = 0.0       // 普通平均（退路）

        for i in stride(from: 0, to: data.count, by: 4) {
            let a = Double(data[i + 3]) / 255
            if a < 0.5 { continue }
            let r = Double(data[i]) / 255
            let g = Double(data[i + 1]) / 255
            let b = Double(data[i + 2]) / 255
            rP += r; gP += g; bP += b; count += 1

            let mx = max(r, g, b), mn = min(r, g, b)
            let sat = mx <= 0 ? 0 : (mx - mn) / mx
            // 跳过近黑、近白；按饱和度平方加权，让鲜艳色主导。
            guard mx > 0.12, mx < 0.98 || sat > 0.15 else { continue }
            let weight = sat * sat
            rW += r * weight; gW += g * weight; bW += b * weight; weightSum += weight
        }

        if weightSum > 0.0005 {
            return Color(.sRGB, red: rW / weightSum, green: gW / weightSum, blue: bW / weightSum, opacity: 1)
        } else if count > 0 {
            return Color(.sRGB, red: rP / count, green: gP / count, blue: bP / count, opacity: 1)
        }
        return nil
    }

    /// 等比缩放，使长边不超过 maxDimension。已足够小则原样返回。
    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

extension Color {
    /// 柔化为头部色调：保留色相，饱和度收敛到可见区间、提高亮度，
    /// 既柔和又明显有色；近乎无彩色时退回中性浅灰，避免凭空注入色相。
    func softTint() -> Color {
        let ui = UIColor(self)
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        guard ui.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha) else { return self }
        guard sat > 0.06 else {
            return Color(hue: 0, saturation: 0, brightness: 0.96)   // 灰白图：中性浅灰
        }
        let softSat = min(max(sat, 0.28), 0.55)
        return Color(hue: Double(hue), saturation: Double(softSat), brightness: 0.96)
    }
}
