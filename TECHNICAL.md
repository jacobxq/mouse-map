# MouseMap 技术总结

这份文档记录 MouseMap 当前的输入监听方案、G502 兼容处理、支持边界和后续扩展方向。

## 背景

MouseMap 目标是把鼠标额外按键映射成 macOS 系统动作。最直接的实现是监听 `CGEvent otherMouseDown`，但在部分游戏鼠标上，这条路径并不可靠。

Logitech G502 HERO 是这次已验证的问题设备：

- `CGEvent tap` 看不到侧键
- `IOHIDManagerRegisterInputValueCallback` 也不能稳定拿到 `usage=4/5`
- 但鼠标 HID 接口本身仍然暴露了标准 `page=9` 按钮元素

因此，项目最终采用了“双路径输入监听”。

## 当前输入链路

### 1. `CGEvent` 路径

文件：`Services/EventTapManager.swift`

职责：

- 处理标准多键鼠标
- 在学习模式下捕获按钮号
- 在正常模式下拦截 `otherMouseDown` 并执行映射动作

适用前提：

- macOS 会把目标按键上抛成 `otherMouseDown` / `otherMouseUp`

优点：

- 通用
- 实现简单
- 不依赖具体厂商设备

局限：

- 一旦驱动层或系统层没有把侧键上抛成 `CGEvent`，这条路径就无效

### 2. HID report fallback

文件：`Services/HIDMonitor.swift`

职责：

- 处理 `CGEvent` 路径拿不到的鼠标侧键
- 监听原始 input report
- 在 report 到达后回读标准按钮元素状态

当前实现要点：

1. 通过 `IOHIDManagerSetDeviceMatching` 只匹配鼠标接口
2. 使用 `IOHIDManagerRegisterInputReportCallback` 监听 input report
3. 枚举目标设备上的 `page=9` 按钮元素
4. 在 report 到达后用 `IOHIDDeviceGetValue` 读取按钮状态
5. 只在“未按下 -> 按下”的边沿触发学习和映射
6. HID `usage` 转换为项目内部按钮号：

```text
buttonNumber = usage - 1
```

这样可以和现有配置保持一致，例如：

- `usage=4` -> `buttonNumber=3`
- `usage=5` -> `buttonNumber=4`

## 两条路径如何协作

`EventTapManager` 和 `HIDMonitor` 不是并行重复处理，而是按接管状态协作：

- 如果 HID 监控已经成功接管目标设备按钮，`EventTapManager` 不再处理对应学习/映射逻辑
- 如果 HID 没接管，仍由 `CGEvent` 路径工作

这样做是为了避免：

- 同一个按键触发两次
- HID 启动后把所有 `CGEvent` 逻辑都错误地静音

## 这次修复实际解决了什么

### 1. G502 侧键不可见

修复前：

- `CGEvent` 看不到侧键
- `InputValueCallback` 看不到 `usage=4/5`

修复后：

- 改走 `InputReportCallback`
- 在 report 到达时读取按钮元素状态
- G502 侧键可以进入学习模式和正常映射模式

### 2. 重装后“执行了没反应”

原因：

- 安装到新路径后，辅助功能权限失效
- 应用虽然进程在运行，但事件 tap 和 HID 都不会工作

修复后：

- 应用启动时如果权限缺失，会自动弹配置窗口
- 同时触发辅助功能授权请求

### 3. 无关 HID 接口导致的权限噪音

之前的 HID 监听会同时匹配：

- 鼠标接口
- 键盘接口
- 消费者控制接口

这会引出无关的 `TCC deny IOHIDDeviceOpen`。现在已收敛为只监听鼠标接口。

## 当前支持范围

### 当前支持

- 能直接产生 `otherMouseDown` 的标准多键鼠标
- 类似 G502 HERO 这种：
  - `CGEvent` 不稳定
  - 鼠标接口仍有标准 `page=9` 按钮元素
  - input report 到达后可以通过元素状态回读按钮

### 当前不保证支持

- 侧键映射成键盘键的鼠标
- 侧键映射成消费者控制键的鼠标
- 仅通过 vendor-defined page 暴露额外按键的鼠标
- 非 G502，但同样需要 HID fallback、且当前未被纳入适配策略的型号

## 为什么现在还不是“所有鼠标都支持”

当前 `HIDMonitor` 仍然包含设备筛选，优先解决的是已确认有问题的 G502。

这意味着项目现在的状态是：

- 已经有一套可工作的 fallback 方案
- 但还没有把 fallback 泛化成“按能力自动探测所有鼠标”

## 建议的后续扩展方向

如果以后要支持更多不同类型的鼠标，建议按下面顺序推进：

1. 把 HID fallback 从设备白名单改成“按能力识别”
2. 增加诊断输出，记录新鼠标走的是哪条路径：
   - `CGEvent`
   - 标准 HID Button
   - 键盘页
   - 消费者页
   - vendor-defined page
3. 再针对确实需要的设备补第三层或第四层处理：
   - 键盘接口监听
   - 消费者控制接口监听
   - vendor report / 私有协议解析

## 调试信息

- 启动日志：`/tmp/mousemap_debug.log`
- HID 相关日志统一走 stderr 输出

## 相关文件

- `App/MouseMapApp.swift`
- `Services/EventTapManager.swift`
- `Services/HIDMonitor.swift`
- `Services/PermissionManager.swift`
- `ViewModels/SettingsViewModel.swift`
