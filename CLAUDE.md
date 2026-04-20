# MouseMap

macOS 鼠标按键映射工具，SwiftUI 纯 swiftc 编译（无 Xcode 项目文件）。

## 构建

```bash
make          # 编译到 build/MouseMap.app
make run      # 编译并启动
make clean    # 清理构建产物
```

## 项目结构

```
├── App/          # 入口 MouseMapApp.swift
├── Models/       # MappingAction, AppConfiguration
├── Services/     # EventTapManager, ConfigManager, PermissionManager, KeyEventSimulator
├── ViewModels/   # SettingsViewModel
├── Views/        # SettingsView, PermissionStatusView
└── Resources/    # Info.plist
```

## 注意

- `ls` 被 RTK hook 拦截输出 `(empty)`，用 `find` 或 `/bin/ls` 替代
