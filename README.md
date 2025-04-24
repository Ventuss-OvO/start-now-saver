# Start Now Screensaver

一款 macOS 屏幕保护程序，显示"Think Different"和"Start Now"等激励文字，带有动态效果。

## 启动说明
- Start Now.xcodeproj 启动 Xcode
- Shift + Command + K 清空缓存
- Command + B 编译
- Script/clear_screensaver_cache.command 清除系统缓存
- Script/alias.saver 快速安装新 .saver 文件


## 功能特点

- 显示两行文字：固定的"Think Different"和动态变化的"Start Now"系列语句
- 采用渐变色文字效果
- 支持视频背景
- 可配置出生年份，显示相应年龄

## 安装说明

1. 下载最新的发布版本
2. 双击`Start Now.saver`文件安装
3. 在系统设置中选择"屏幕保护程序"，启用"Start Now"

## 配置选项

屏幕保护程序提供以下配置选项：
- 出生年份设置：显示"in your XXs"时会根据您设置的出生年份计算年龄

## 技术栈与实现方式

### 核心技术
- **Objective-C**: 项目基于 Objective-C 实现，使用 ScreenSaver 框架
- **Core Animation**: 文字渐变效果和动画通过 CALayer、CATextLayer、CAGradientLayer 实现
- **AVFoundation**: 视频背景播放和控制
- **Core Text**: 自定义字体加载与渲染
- **NSDistributedNotificationCenter**: 处理屏幕保护程序生命周期事件

### 主要组件
- **FontManager**: 自定义字体管理和注册
- **Start_NowView**: 主视图类，继承自 ScreenSaverView
- **打字动画系统**: 实现了打字输入和擦除效果的动画
- **配置表单**: 通过 NSWindow 实现的用户配置界面

### 架构特点
- **分层设计**: 视频背景层、半透明遮罩层、文字渲染层
- **响应式布局**: 自动适应全屏和预览窗口的不同尺寸
- **持久化配置**: 使用 NSUserDefaults 存储用户设置
- **内存优化**: 针对 macOS Sonoma 中的内存泄漏问题进行修复

### 文件结构
- **Start_NowView.h/m**: 主要实现文件
- **Resources/**: 包含 Gentium 字体文件和背景视频
- **thumbnail.png/thumbnail@2x.png**: 屏保缩略图

## 开发环境

- Xcode 15.0+
- macOS 14.0+ (Sonoma)

## 许可证

[许可证类型] - 详情请参见 LICENSE 文件
