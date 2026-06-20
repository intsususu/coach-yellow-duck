// ProfileSettingsViews.swift
// 「我的」资料设置页（头像上传 + 昵称/身高/年龄/性别）与关于页。

import SwiftUI
import PhotosUI

// MARK: - 资料设置页

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ProfileStore

    // 草稿：保存时一次性写回 store，取消则丢弃。
    @State private var draft: UserProfile
    @State private var pickerItem: PhotosPickerItem?
    @State private var draftAvatar: UIImage?
    @State private var avatarEdited = false
    @State private var showPhotoPicker = false
    @State private var cropTarget: CropTarget?   // 选中原图后进圆形裁剪，确认才生效

    init(store: ProfileStore) {
        self.store = store
        _draft = State(initialValue: store.profile)
        _draftAvatar = State(initialValue: store.avatarImage)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    avatarPicker
                    fieldsCard
                }
                .padding(20)
            }
            .background(Color.appBg.ignoresSafeArea())
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.bold)
                }
            }
            // 选完照片不直接确认 —— 先加载原图，弹出圆形裁剪界面。
            .photosPicker(isPresented: $showPhotoPicker, selection: $pickerItem, matching: .images)
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        cropTarget = CropTarget(image: image)
                    }
                    pickerItem = nil
                }
            }
            .fullScreenCover(item: $cropTarget) { target in
                ImageCropView(image: target.image) {
                    cropTarget = nil
                } onCrop: { cropped in
                    draftAvatar = cropped
                    avatarEdited = true
                    cropTarget = nil
                }
            }
        }
    }

    private var avatarPicker: some View {
        VStack(spacing: 12) {
            Button { showPhotoPicker = true } label: {
                ZStack(alignment: .bottomTrailing) {
                    AvatarImageView(image: draftAvatar, size: 110)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.brandBlue)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
            }
            .buttonStyle(.plain)

            Button("更换头像") { showPhotoPicker = true }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.brandBlue)

            if draftAvatar != nil {
                Button("恢复默认头像") {
                    draftAvatar = nil
                    pickerItem = nil
                    avatarEdited = true
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
            }
        }
    }

    private var fieldsCard: some View {
        CardView(padding: 0) {
            VStack(spacing: 0) {
                textRow(title: "昵称", text: $draft.nickname, placeholder: "输入昵称")
                rowDivider
                textRow(title: "状态标签", text: $draft.statusTag, placeholder: "如：减脂中")
                rowDivider
                stepperRow(title: "身高", value: $draft.heightCm, range: 100...230, unit: "cm")
                rowDivider
                stepperRow(title: "年龄", value: $draft.age, range: 1...120, unit: "岁")
                rowDivider
                genderRow
            }
        }
    }

    private func textRow(title: String, text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textPrimary)
                .frame(width: 70, alignment: .leading)
            TextField(placeholder, text: text)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func stepperRow(title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textPrimary)
            Spacer()
            Text("\(value.wrappedValue) \(unit)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.brandBlue)
                .frame(minWidth: 64, alignment: .trailing)
            Stepper("", value: value, in: range)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var genderRow: some View {
        HStack {
            Text("性别")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textPrimary)
            Spacer()
            Picker("性别", selection: $draft.gender) {
                ForEach(Gender.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    private var rowDivider: some View {
        Divider().background(Color.hairline).padding(.leading, 16)
    }

    private func save() {
        store.profile = draft
        if avatarEdited {
            store.updateAvatar(draftAvatar)
        }
        dismiss()
    }
}

// MARK: - 头像展示（占位图为小黄鸡）

struct AvatarImageView: View {
    let image: UIImage?
    var size: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image("ChickAvatar").resizable().scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 3))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}

// MARK: - 圆形头像裁剪（拖动 + 缩放，确认才生效）

/// fullScreenCover(item:) 需要 Identifiable 包装原图。
struct CropTarget: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ImageCropView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onCrop: (UIImage) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    /// 裁剪框直径（圆）。显示与最终输出共用，保证所见即所得。
    private let cropDiameter: CGFloat = 300

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // 所见即所得：圆形裁剪框内可自由拖动、缩放图片。
                croppable(diameter: cropDiameter, clipCircle: true)
                    .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 2))
                    .gesture(
                        SimultaneousGesture(dragGesture, magnifyGesture)
                    )

                Text("拖动调整位置，双指缩放")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                HStack(spacing: 16) {
                    Button(action: onCancel) {
                        Text("取消")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    Button(action: confirmCrop) {
                        Text("使用")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.brandBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { v in
                offset = CGSize(width: lastOffset.width + v.translation.width,
                                height: lastOffset.height + v.translation.height)
            }
            .onEnded { _ in lastOffset = offset }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { v in scale = min(max(1, lastScale * v), 6) }
            .onEnded { _ in lastScale = scale }
    }

    /// 可拖动 / 缩放的图片合成。clipCircle=true 用于展示，false（方形）用于输出，
    /// 圆内切于方形 —— 输出方形避免 JPEG 无 alpha 导致圆角变黑、并保证吸色取到头像主体。
    private func croppable(diameter d: CGFloat, clipCircle: Bool) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: d, height: d)
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: d, height: d)
            .clipShape(clipCircle ? AnyShape(Circle()) : AnyShape(Rectangle()))
    }

    @MainActor private func confirmCrop() {
        let renderer = ImageRenderer(content: croppable(diameter: cropDiameter, clipCircle: false))
        renderer.scale = 3   // 输出约 900px
        if let ui = renderer.uiImage {
            onCrop(ui)
        } else {
            onCrop(image)
        }
    }
}

// MARK: - 关于页

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Image("ChickAvatar")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
                        .padding(.top, 24)

                    Text("自律小黄鸡")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.textPrimary)
                    Text(version)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textSecondary)

                    CardView(padding: 0) {
                        VStack(spacing: 0) {
                            aboutRow(title: "App 名称", value: "自律小黄鸡")
                            Divider().background(Color.hairline).padding(.leading, 16)
                            aboutRow(title: "版本", value: version)
                            Divider().background(Color.hairline).padding(.leading, 16)
                            aboutRow(title: "数据来源", value: "Apple 健康")
                        }
                    }

                    Text("坚持自律，和小黄鸡一起变更好 🐤")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textMuted)
                        .padding(.top, 8)

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .background(Color.appBg.ignoresSafeArea())
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func aboutRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
