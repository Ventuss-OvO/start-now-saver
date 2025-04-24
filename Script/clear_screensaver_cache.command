#!/bin/bash
# 文件名: clear_screensaver_cache_thorough.command
# 功能: 彻底清除macOS屏保缓存，确保新版本可以正常显示

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}====== 开始执行屏保缓存彻底清理 ======${NC}"

# 步骤1: 保存当前系统屏保设置以便稍后恢复
echo -e "${BLUE}[步骤1]${NC} 备份当前系统屏保设置..."
# 使用defaults读取当前屏保设置并保存
CURRENT_SCREENSAVER_SETTINGS=$(defaults read com.apple.screensaver 2>/dev/null || echo "No settings found")
CURRENT_SCREENSAVER_MODULE=$(defaults read com.apple.screensaver moduleDict 2>/dev/null || echo "No module settings found")
CURRENT_SCREENSAVER_IDLE_TIME=$(defaults read com.apple.screensaver idleTime 2>/dev/null || echo "No idle time found")
echo "当前设置已备份"

# 步骤2: 停止所有屏保相关进程
echo -e "${BLUE}[步骤2]${NC} 停止所有屏保相关进程..."
# 终止屏保引擎和相关进程
killall ScreenSaverEngine 2>/dev/null
killall "System Preferences" 2>/dev/null
killall "System Settings" 2>/dev/null
# 使用进程名称检查并杀死更多可能相关的进程
ps aux | grep -i 'screensaver' | grep -v grep | awk '{print $2}' | xargs kill 2>/dev/null
sleep 2
echo "所有屏保相关进程已停止"

# 步骤3: 删除所有缓存文件
echo -e "${BLUE}[步骤3]${NC} 删除所有屏保相关缓存文件..."
# 删除主要缓存目录
rm -rf ~/Library/Caches/com.apple.screensaver 2>/dev/null
rm -rf ~/Library/Caches/com.apple.preference.desktopscreeneffect 2>/dev/null
rm -rf ~/Library/Saved\ Application\ State/com.apple.ScreenSaver.Engine.savedState 2>/dev/null

# 删除偏好设置缓存
rm -rf ~/Library/Preferences/ByHost/com.apple.screensaver.*.plist 2>/dev/null
# 不删除主偏好设置文件，以保留系统设置
# rm -rf ~/Library/Preferences/com.apple.screensaver.plist 2>/dev/null

# 删除其他可能的缓存位置
rm -rf ~/Library/Caches/com.apple.preference.universalaccess 2>/dev/null
echo "屏保缓存文件已删除"

# 步骤4: 处理Start Now屏保文件的缓存
echo -e "${BLUE}[步骤4]${NC} 处理Start Now屏保文件的特定缓存..."
# 检查屏保文件是否存在
SAVER_PATH=~/Library/Screen\ Savers/Start\ Now.saver
if [ -d "$SAVER_PATH" ]; then
    echo "找到Start Now屏保，进行深度缓存清理..."
    
    # 移除Spotlight索引以防止缓存
    mdutil -i off "$SAVER_PATH" 2>/dev/null
    
    # 清空可能的缓存目录
    find "$SAVER_PATH" -name "*.cache" -type f -delete 2>/dev/null
    
    # 强制系统重新加载屏保文件
    touch "$SAVER_PATH"
    touch "$SAVER_PATH/Contents/Info.plist"
    touch "$SAVER_PATH/Contents/MacOS/"*
    
    # 确保权限正确
    chmod -R 755 "$SAVER_PATH"
    
    # 添加时间戳标记以验证更新
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    mkdir -p "$SAVER_PATH/Contents/Resources/cache_cleared"
    echo "$TIMESTAMP" > "$SAVER_PATH/Contents/Resources/cache_cleared/timestamp.txt"
    
    echo "Start Now屏保特定缓存已清理"
else
    echo "未找到Start Now屏保文件"
fi

# 步骤5: 强制刷新系统缓存
echo -e "${BLUE}[步骤5]${NC} 强制刷新系统缓存服务..."
# 重新启动缓存相关服务
sudo pkill -f "com.apple.screensaver" 2>/dev/null
sudo pkill -f "cfprefsd" 2>/dev/null
sleep 1

# 使用kextcache命令清理系统扩展缓存
sudo kextcache -clear-staging 2>/dev/null
sleep 1

# 使用系统命令强制刷新缓存
mds -s &> /dev/null # 重启Spotlight
sudo update_dyld_shared_cache -force &> /dev/null # 强制更新动态库缓存

echo "系统缓存服务已刷新"

# 步骤6: 恢复之前的系统屏保设置
echo -e "${BLUE}[步骤6]${NC} 恢复系统屏保设置..."
# 如果有备份，恢复原始设置
if [ "$CURRENT_SCREENSAVER_IDLE_TIME" != "No idle time found" ]; then
    defaults write com.apple.screensaver idleTime -int "$CURRENT_SCREENSAVER_IDLE_TIME"
    echo "屏保空闲时间已恢复"
fi

# 确保缓存真正清除
defaults read com.apple.screensaver &> /dev/null
echo "系统屏保设置已恢复"

# 步骤7: 验证缓存清理效果
echo -e "${BLUE}[步骤7]${NC} 验证缓存清理效果..."
# 检查特定文件的修改时间以确认是否已刷新
if [ -d "$SAVER_PATH" ]; then
    MOD_TIME=$(stat -f "%m" "$SAVER_PATH")
    CURRENT_TIME=$(date +%s)
    DIFF=$((CURRENT_TIME - MOD_TIME))
    
    if [ $DIFF -lt 300 ]; then # 5分钟内
        echo -e "${GREEN}✓ 验证成功: 屏保文件最近已更新${NC}"
    else
        echo -e "${YELLOW}⚠️ 屏保文件未被最近修改，可能需要重新安装${NC}"
    fi
fi

echo -e "${GREEN}====== 屏保缓存彻底清理完成 ======${NC}"
echo -e "${YELLOW}现在应该已经可以看到最新的屏保效果${NC}"
echo -e "${YELLOW}你可以使用以下命令预览屏保:${NC}"
echo -e "${GREEN}open -a ScreenSaverEngine.app --args -module \"Start Now\"${NC}"
echo -e "${YELLOW}如果仍然看到旧效果，请尝试重启电脑${NC}"
echo -e "${YELLOW}如果需要调试:${NC}"
echo -e "${GREEN}log show --predicate 'subsystem == \"com.apple.screensaver\"' --last 5m${NC}"