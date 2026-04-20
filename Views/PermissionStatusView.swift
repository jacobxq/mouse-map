import SwiftUI

struct PermissionStatusView: View {
    @ObservedObject var permissionManager: PermissionManager

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: permissionManager.isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(permissionManager.isGranted ? .green : .orange)
                .font(.title3)

            if permissionManager.isGranted {
                Text("辅助功能权限已授权")
                    .font(.body)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("需要辅助功能权限")
                        .font(.body.bold())
                    Text("MouseMap 需要辅助功能权限才能拦截鼠标按键事件。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("打开系统设置") {
                        permissionManager.requestPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(permissionManager.isGranted ? Color.green.opacity(0.08) : Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
