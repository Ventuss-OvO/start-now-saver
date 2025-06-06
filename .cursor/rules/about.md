# Start Now - macOS 屏幕保护程序

## 项目概述

Start Now 是一个简约而富有创意的 macOS 屏幕保护程序，设计用来提醒用户关注当下的重要性。它以简洁的视觉方式展示当前的时间、日期和用户的年龄信息，通过"Start Now"（从现在开始）这一主题激励用户珍惜当下时光。

## 功能特点

- **动态时间显示**：实时显示当前时间（时：分：秒）
- **日期信息展示**：显示当前月份、日期和星期几
- **年龄提醒**：根据设定的出生年份计算并显示当前年龄
- **简约设计**：黑色背景搭配白色文字，突出信息的清晰度
- **交替显示内容**：屏幕保护程序会定时切换显示不同的信息（月份、日期、年龄、星期、时间、"Now"）

## 技术实现

- **开发环境**：macOS 应用开发，使用 Objective-C 语言
- **框架**：基于 Apple 的 ScreenSaver 框架
- **字体**：主要使用 Gentium 字体，如不可用则回退至 Helvetica
- **自动部署**：构建脚本自动将屏幕保护程序安装到用户的 Screen Savers 目录

## 代码结构

- **Start_NowView.h**：定义了屏幕保护程序的主视图类
- **Start_NowView.m**：实现了屏幕保护程序的核心功能，包括：
  - 初始化和配置显示属性
  - 绘制文本和背景
  - 定时更新显示内容
  - 动画效果处理
  - 配置界面实现（待完成）

## 使用方法

1. **安装**：构建项目后，屏幕保护程序将自动安装到 `~/Library/Screen Savers/` 目录
2. **配置**：在 macOS 的系统偏好设置 > 屏幕保护程序中选择 "Start Now Clock"
3. **自定义**：可以通过配置面板（开发中）设置个人偏好，如出生年份等

## 开发状态

- 基本功能已实现完成
- 配置界面正在开发中（TODO: 添加用户配置控件）
- 支持 macOS 11.5 及以上版本

## 未来计划

- 完善配置界面，允许用户自定义：
  - 文字颜色
  - 字体选择
  - 出生年份设置
- 增加更多动态显示效果
- 优化性能和资源使用

## 构建与部署

项目包含两个自动化脚本：
1. 构建前脚本：安全关闭正在运行的屏幕保护程序引擎，并删除旧版本
2. 构建后脚本：将新构建的屏幕保护程序自动安装到用户的 Screen Savers 目录

## 许可信息

该项目由 Jason 于 2025 年 4 月 15 日创建，使用的开发团队标识符为 X6WT9YRNVA，包名为 Polytime.Start-Now。

---

*Start Now - 提醒你把握当下的每一刻！*
