// EventTagStore.swift
// 事件小标签的本机持久化：各类型在默认标签之外，记录用户自建的标签，便于复用。
// 默认标签来自 EventType.defaultTags；自定义标签按类型 rawValue 存于 UserDefaults。

import Foundation
import SwiftUI

final class EventTagStore: ObservableObject {
    private let userDefaults: UserDefaults
    private let storageKey: String

    /// 各类型用户自建的标签（rawValue -> 标签列表）。
    @Published private var customTags: [String: [String]]

    init(userDefaults: UserDefaults = .standard,
         storageKey: String = "com.xltc.sdlyc.eventTags.v1") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            customTags = decoded
        } else {
            customTags = [:]
        }
    }

    /// 某类型可用的全部标签：默认标签在前，用户自建标签在后（去重）。
    func tags(for type: EventType) -> [String] {
        var result = type.defaultTags
        for tag in customTags[type.rawValue] ?? [] where !result.contains(tag) {
            result.append(tag)
        }
        return result
    }

    /// 新增一个自定义标签；与默认或已有标签重复、或为空时忽略。返回是否实际新增。
    @discardableResult
    func addTag(_ tag: String, for type: EventType) -> Bool {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags(for: type).contains(trimmed) else { return false }
        customTags[type.rawValue, default: []].append(trimmed)
        persist()
        return true
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(customTags) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
