# MFCMouseEffect 深度代码理解

## 1. 模块地图

### 核心模块
- **输入采集模块**
  - `MFCMouseEffect/MouseFx/Core/System/IGlobalMouseHook.h` - 鼠标钩子接口
  - `MFCMouseEffect/MouseFx/Core/System/CursorPositionProvider.cpp` - 光标位置获取
  - `MFCMouseEffect/MouseFx/Core/Input/GestureRecognizer.cpp` - 手势识别

- **状态管理模块**
  - `MFCMouseEffect/MouseFx/Core/Control/AppController.cpp` - 应用控制器
  - `MFCMouseEffect/MouseFx/Core/Control/DispatchRouter.cpp` - 事件分发器

- **特效计算模块**
  - `MFCMouseEffect/MouseFx/Core/Effects/TrailEffectCompute.cpp` - 拖尾特效计算
  - `MFCMouseEffect/MouseFx/Core/Effects/ClickEffectCompute.cpp` - 点击特效计算
  - `MFCMouseEffect/MouseFx/Core/Effects/HoverEffectCompute.cpp` - 悬停特效计算

- **渲染输出模块**
  - `MFCMouseEffect/MouseFx/Renderers/` - 各种特效渲染器
  - `MFCMouseEffect/MouseFx/Core/Overlay/OverlayHostService.cpp` -  overlay 管理

- **配置管理模块**
  - `MFCMouseEffect/MouseFx/Core/Config/EffectConfig.cpp` - 配置结构和加载
  - `MFCMouseEffect/MouseFx/Core/Config/EffectConfigJsonCodec.Parse.cpp` - JSON 解析

- **WebUI/设置模块**
  - `MFCMouseEffect/WebUI/` - Web 界面
  - `MFCMouseEffect/WebUIWorkspace/` - Web 界面工作区

- **插件/WASM 模块**
  - `MFCMouseEffect/MouseFx/Core/Wasm/WasmEffectHost.cpp` - WASM 效果宿主
  - `MFCMouseEffect/MouseFx/Core/Wasm/WasmExecutionBudgetGuard.cpp` - WASM 执行预算管理

## 2. 主链路

### 链路 1: 鼠标移动事件处理
1. **输入采集** - 鼠标钩子捕获鼠标移动事件
2. **事件分发** - `DispatchRouter` 接收并路由事件
3. **状态更新** - `AppController` 更新鼠标位置和速度
4. **特效计算** - `TrailEffectCompute` 计算拖尾特效参数
5. **渲染输出** - 渲染器绘制拖尾效果

### 链路 2: 配置加载与应用
1. **配置读取** - 从 JSON 文件读取配置
2. **配置解析** - `EffectConfigJsonCodec` 解析配置
3. **配置应用** - `AppController` 应用配置到各模块
4. **特效更新** - 特效模块根据配置更新行为

## 3. 配置生效路径
1. 配置文件 → `EffectConfig.Load.cpp` → `EffectConfig` 实例
2. `EffectConfig` → `AppController` → 各特效模块
3. 运行时修改 → 配置保存 → 持久化到文件

## 4. 扩展点设计
- **特效扩展** - 通过 `EffectFactory` 注册新特效类型
- **WASM 插件** - 通过 WASM 模块扩展特效能力
- **渲染器扩展** - 实现新的渲染器接口
- **配置扩展** - 在 `EffectConfig` 中添加新配置项

## 5. 风险清单
1. **性能风险** - 复杂特效可能导致性能下降
2. **兼容性风险** - 不同 Windows 版本的兼容性问题
3. **安全风险** - WASM 执行可能存在安全隐患
4. **稳定性风险** - 鼠标钩子可能导致系统不稳定
5. **内存风险** - 内存泄漏或过度使用
6. **配置风险** - 配置错误可能导致功能异常
7. **依赖风险** - 第三方库依赖问题
8. **用户体验风险** - 特效过于复杂可能影响用户体验

## 6. 下一轮执行计划
1. **Bug 修复** - 修复 WASM 插件执行超时问题
2. **功能增强** - 添加速度自适应特效强度
3. **性能优化** - 优化特效计算和渲染性能
4. **兼容性改进** - 提升跨 Windows 版本兼容性
5. **安全性增强** - 加强 WASM 执行安全