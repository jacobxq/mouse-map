import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var permissionManager: PermissionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PermissionStatusView(permissionManager: permissionManager)

            Toggle("启用按键映射", isOn: Binding(
                get: { viewModel.config.isEnabled },
                set: { viewModel.setEnabled($0) }
            ))
            .font(.headline)

            if viewModel.config.mappings.isEmpty {
                Text("暂无映射规则，点击下方按钮添加。")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.config.mappings) { mapping in
                            HStack {
                                Text(mapping.displayName)
                                    .frame(width: 140, alignment: .leading)

                                Picker("", selection: Binding(
                                    get: { mapping.action },
                                    set: { viewModel.updateAction(id: mapping.id, action: $0) }
                                )) {
                                    ForEach(MappingAction.allCases) { action in
                                        Text(action.displayName).tag(action)
                                    }
                                }
                                .frame(width: 180)

                                Spacer()

                                Button(action: { viewModel.removeMapping(id: mapping.id) }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }

            Divider()

            HStack {
                if viewModel.isLearning {
                    Button("取消") {
                        viewModel.cancelLearning()
                    }
                    Text("请按下要学习的鼠标按键...")
                        .foregroundColor(.orange)
                        .font(.caption)
                } else {
                    Button("添加按键映射") {
                        viewModel.startLearning()
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 480, height: 360)
    }
}
