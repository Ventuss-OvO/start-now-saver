//
//  Start_NowView.m
//  Start Now
//
//  Created by Jason on 4/15/25.
//

#import "Start_NowView.h"
#import <AVFoundation/AVFoundation.h>

// 1. 首先，在 Start_NowView.m 之外定义 FontManager 辅助类
@interface FontManager : NSObject
+ (CTFontRef)gentiumFontWithSize:(CGFloat)size;
+ (BOOL)registerGentiumFont;
+ (NSString *)gentiumFontPath;
@end

@implementation FontManager

// 静态变量，确保字体只注册一次
static BOOL isGentiumRegistered = NO;

// 获取 Gentium 字体
+ (CTFontRef)gentiumFontWithSize:(CGFloat)size {
    // 确保字体已注册
    [self registerGentiumFont];
    
    // 创建字体
    CTFontRef font = CTFontCreateWithName(CFSTR("Gentium"), size, NULL);
    
    // 如果获取失败，使用备用字体
    if (!font) {
        NSLog(@"无法创建 Gentium 字体，使用系统字体");
        font = CTFontCreateWithName(CFSTR("Helvetica"), size, NULL);
    }
    
    return font;
}

// 注册 Gentium 字体
+ (BOOL)registerGentiumFont {
    // 如果已经注册过，直接返回成功
    if (isGentiumRegistered) {
        return YES;
    }
    
    NSString *fontPath = [self gentiumFontPath];
    if (!fontPath) {
        NSLog(@"无法找到 Gentium 字体文件");
        return NO;
    }
    
    NSURL *fontURL = [NSURL fileURLWithPath:fontPath];
    CFErrorRef error = NULL;
    
    if (CTFontManagerRegisterFontsForURL((__bridge CFURLRef)fontURL, kCTFontManagerScopeProcess, &error)) {
        NSLog(@"成功注册 Gentium 字体：%@", fontPath);
        isGentiumRegistered = YES;
        return YES;
    } else {
        NSLog(@"字体注册失败：%@", error);
        if (error) CFRelease(error);
        return NO;
    }
}

// 查找 Gentium 字体文件路径
+ (NSString *)gentiumFontPath {
    // 从 bundle 加载自定义字体
    NSBundle *bundle = [NSBundle bundleForClass:[FontManager class]];
    NSString *fontPath = [bundle pathForResource:@"Gentium" ofType:@"ttf"];
    
    // 如果无法从当前 bundle 找到，尝试从主 bundle 查找
    if (!fontPath) {
        fontPath = [[NSBundle mainBundle] pathForResource:@"Gentium" ofType:@"ttf"];
    }
    
    // 尝试从已知路径加载
    if (!fontPath) {
        NSString *knownPath = @"/Users/jason/Documents/Cerelib/Projects/Coding/Start Now/Resources/Gentium.ttf";
        if ([[NSFileManager defaultManager] fileExistsAtPath:knownPath]) {
            fontPath = knownPath;
        }
    }
    
    return fontPath;
}

@end

// 2. 然后定义 Start_NowView 的接口和实现
@interface Start_NowView ()
@property (nonatomic, strong) NSArray *displayTexts;
@property (nonatomic, assign) NSInteger currentTextIndex;
@property (nonatomic, strong) NSColor *textColor;
@property (nonatomic, assign) NSInteger birthYear;
@property (nonatomic, strong) NSTimer *updateTimer;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSDateFormatter *timeFormatter;
// 新增打字动画相关属性
@property (nonatomic, strong) NSString *currentDisplayText; // 当前显示的文本
@property (nonatomic, assign) BOOL isTyping; // 是否正在输入
@property (nonatomic, assign) BOOL isErasing; // 是否正在删除
@property (nonatomic, assign) NSInteger charIndex; // 当前字符索引
@property (nonatomic, strong) NSTimer *typingTimer; // 打字计时器

// 视频背景相关属性
@property (nonatomic, strong) AVPlayer *videoPlayer;
@property (nonatomic, strong) AVPlayerLayer *videoPlayerLayer;
@property (nonatomic, strong) NSString *videoPath;

// 文字图层
@property (nonatomic, strong) CATextLayer *firstLineTextLayer; // 第一行：Think Different
@property (nonatomic, strong) CATextLayer *secondLineTextLayer; // 第二行：Start xxxx (整行动态)
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) CATextLayer *gradientTextMask;

// 新增遮罩层相关属性
@property (nonatomic, strong) CALayer *overlayLayer; // 半透明遮罩层

// 配置界面相关属性
@property (nonatomic, strong) NSTextField *birthYearTextField;
@property (nonatomic, strong) NSWindow *configSheet;

// 新增属性 - 标记是否处于预览模式
@end

@implementation Start_NowView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        // 在初始化时就注册字体，确保字体可用
        [FontManager registerGentiumFont];
        
        // 启用 layer 支持 - 这很重要，要放在最前面
        [self setWantsLayer:YES];
        
        [self setAnimationTimeInterval:3.0]; // 修改为 3 秒更新一次
        
        // 初始化属性
        self.currentTextIndex = 0;
        self.textColor = [NSColor whiteColor];
        
        // 从用户偏好设置加载出生年份
        [self loadConfiguration];
        
        // 初始化打字动画属性
        self.currentDisplayText = @"";
        self.isTyping = YES;
        self.isErasing = NO;
        self.charIndex = 0;
        
        // 初始化日期格式器
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setLocale:[NSLocale currentLocale]];
        
        self.timeFormatter = [[NSDateFormatter alloc] init];
        [self.timeFormatter setDateFormat:@"HH:mm"];
        
        // 初始化展示文字
        [self updateDisplayTexts];
        
        // 先设置视频背景
        [self setupVideoBackground];
        
        // 然后添加半透明遮罩层 - 在视频层之上，文字层之下
        [self setupOverlayLayer];
        
        // 最后创建文字图层
        [self setupTextLayers];
        
        // 启动打字动画定时器
        self.typingTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 // 100 毫秒的打字速度
                                                 target:self
                                               selector:@selector(updateTypingAnimation)
                                               userInfo:nil
                                                repeats:YES];
        
        // 添加屏保停止通知监听，解决 macOS Sonoma 中的泄漏问题
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                           selector:@selector(willStop:)
                                                               name:@"com.apple.screensaver.willstop"
                                                             object:nil];
        
        #if DEBUG
        // InjectionIII 部分
        [[NSBundle bundleWithPath:@"/Applications/InjectionIII.app/Contents/Resources/macOSInjection.bundle"] load];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                selector:@selector(injected)
                                                    name:@"INJECTION_BUNDLE_NOTIFICATION"
                                                  object:nil];
        #endif
    }
    return self;
}

// 替换原来的 loadCustomFont 方法
- (CTFontRef)loadCustomFont {
    return [FontManager gentiumFontWithSize:100];
}

// 修改 setupTextLayers 方法，在预览模式下静态显示文字
- (void)setupTextLayers {
    // 创建文字图层
    self.firstLineTextLayer = [CATextLayer layer];
    self.gradientTextMask = [CATextLayer layer];
    
    // 先应用字体 - 使字体成为基础样式
    [self applyCustomFontToTextLayers];
    
    // 设置其他属性
    self.firstLineTextLayer.string = @"Think Different";
    
    // 在预览模式下静态显示 "Start Now"，否则使用动态打字效果
    if ([self isPreview]) {
        self.gradientTextMask.string = @"Start Now"; // 预览模式下固定显示 "Start Now"
    } else {
        self.gradientTextMask.string = @""; // 非预览模式下从空开始，进行打字动画
    }
    
    // 其余设置保持不变
    self.firstLineTextLayer.fontSize = 100;
    self.firstLineTextLayer.alignmentMode = kCAAlignmentLeft;
    self.firstLineTextLayer.foregroundColor = self.textColor.CGColor;
    
    self.gradientTextMask.fontSize = 100;
    self.gradientTextMask.alignmentMode = kCAAlignmentLeft;
    self.gradientTextMask.foregroundColor = [NSColor whiteColor].CGColor; // 蒙版用白色
    
    // 创建渐变层
    self.gradientLayer = [CAGradientLayer layer];
    
    // 设置两种颜色的线性渐变 - 只修改第一种颜色
    // e60b09 - 鲜红色
    // fff95b - 亮黄色
    NSColor *brightRedColor = [NSColor colorWithRed:230.0/255.0 green:11.0/255.0 blue:9.0/255.0 alpha:1.0];
    NSColor *brightYellowColor = [NSColor colorWithRed:255.0/255.0 green:249.0/255.0 blue:91.0/255.0 alpha:1.0];
    
    self.gradientLayer.colors = @[
        (id)brightRedColor.CGColor,
        (id)brightYellowColor.CGColor
    ];
    
    // 其余配置保持不变
    self.gradientLayer.startPoint = CGPointMake(0.0, 0.5);
    self.gradientLayer.endPoint = CGPointMake(1.0, 0.5);
    
    // 使用文字图层作为渐变层的蒙版
    self.gradientLayer.mask = self.gradientTextMask;
    
    // 添加位置值，确保渐变均匀分布
    self.gradientLayer.locations = @[@0.0, @1.0];
    
    // 调整位置并添加到图层 - 确保正确的层次顺序
    [self updateTextLayersPosition];
    
    // 添加到视图的图层中 - 确保文字层在遮罩层之上
    [self.layer addSublayer:self.firstLineTextLayer];
    [self.layer addSublayer:self.gradientLayer]; // 添加渐变层
    
    // 添加简单的动画效果
    [self animateGradient];
    
    NSLog(@"文字图层已添加 - 已确保在遮罩层之上");
}

// 修改 applyCustomFontToTextLayers 方法
- (void)applyCustomFontToTextLayers {
    // 加载字体 - 这里使用字体管理器
    CTFontRef font = [self loadCustomFont];
    if (font) {
        // 应用到第一行文字
        if (self.firstLineTextLayer) {
            self.firstLineTextLayer.font = font;
        }
        
        // 应用到渐变蒙版文字
        if (self.gradientTextMask) {
            self.gradientTextMask.font = font;
        }
        
        // 释放字体
        CFRelease(font);
        
        NSLog(@"成功应用 Gentium 字体到文字图层");
    }
}

// 修改 updateTextLayersPosition 方法，确保在预览模式下适当缩放
- (void)updateTextLayersPosition {
    // 获取视图尺寸
    CGRect bounds = self.bounds;
    
    // 根据是否是预览模式来调整字体大小和行间距
    // 预览模式时使用更小的字体以适应小窗口
    CGFloat fontSize = [self isPreview] ? 10.0 : 100.0;   // 将预览模式字体从 30 减小到 15
    CGFloat lineSpacing = [self isPreview] ? 5.0 : 20.0;  // 将预览模式行间距从 6 减小到 3
    
    // 添加整体垂直偏移量 - 正值表示向下移动
    CGFloat verticalOffset = [self isPreview] ? 5.0 : 60.0; // 预览和全屏模式可以使用不同的偏移量
    
    // 使用 Gentium 字体计算宽度
    CTFontRef ctFont = [FontManager gentiumFontWithSize:fontSize];
    NSFont *font = nil;
    
    // 将 CTFont 转换为 NSFont 以用于计算宽度
    if (ctFont) {
        NSString *fontName = (__bridge_transfer NSString *)CTFontCopyPostScriptName(ctFont);
        font = [NSFont fontWithName:fontName size:fontSize];
        CFRelease(ctFont); // 释放 CTFont
    }
    
    // 如果无法使用 Gentium，使用系统字体
    if (!font) {
        font = [NSFont fontWithName:@"Helvetica" size:fontSize];
    }
    
    // 计算第一行文字的宽度（Think Different）- 使用正确的字体
    NSAttributedString *thinkDifferentAttrString = [[NSAttributedString alloc] 
                                                   initWithString:@"Think Different" 
                                                   attributes:@{NSFontAttributeName: font}];
    CGFloat thinkDifferentWidth = thinkDifferentAttrString.size.width;
    
    // 计算第一行文字的起始 X 位置（水平居中）
    CGFloat firstLineX = NSMidX(bounds) - (thinkDifferentWidth / 2);
    
    // 计算两行文字的 Y 位置 - 添加垂直偏移量
    CGFloat firstLineY = NSMidY(bounds) + lineSpacing/2 - verticalOffset; // 添加偏移量
    CGFloat secondLineY = NSMidY(bounds) - fontSize - lineSpacing/2 - verticalOffset; // 添加偏移量
    
    // 增加高度以适应字母的下降部分，通常是字体大小的 1.2-1.5 倍
    // 这样可以确保字母 y、g、j 等有下降部分的字符显示完整
    CGFloat heightMultiplier = 1.5; // 将高度增加到字体大小的 1.5 倍
    
    // 设置第一行文字位置 (Think Different) - 水平居中
    self.firstLineTextLayer.frame = CGRectMake(
        firstLineX,
        firstLineY,
        thinkDifferentWidth,
        fontSize * heightMultiplier // 增加高度
    );
    
    // 设置第二行文字位置（渐变层和蒙版）
    CGRect secondLineFrame = CGRectMake(
        firstLineX, // 与第一行左对齐
        secondLineY,
        bounds.size.width - firstLineX, // 到右边界的距离
        fontSize * heightMultiplier // 增加高度以显示完整字符
    );
    
    self.gradientTextMask.frame = secondLineFrame;
    self.gradientLayer.frame = CGRectMake(0, 0, bounds.size.width, bounds.size.height);
    
    // 根据是否是预览模式调整字体大小
    self.firstLineTextLayer.fontSize = fontSize;
    self.gradientTextMask.fontSize = fontSize;
    
    NSLog(@"文字图层位置已更新，使用字体：%@，大小：%.1f", font.fontName, fontSize);
}

// 修改 updateTypingAnimation 方法，在预览模式下不进行动画
- (void)updateTypingAnimation {
    // 如果是预览模式，不进行打字动画
    if ([self isPreview]) {
        return; // 直接返回，不更新
    }
    
    // 以下是原有的动画逻辑，只在非预览模式下执行
    // 实时更新时间相关的显示文本
    if (self.currentTextIndex == 4) { // 当前显示的是时间项
        NSDate *now = [NSDate date];
        NSString *time = [self.timeFormatter stringFromDate:now];
        NSMutableArray *texts = [self.displayTexts mutableCopy];
        texts[4] = [NSString stringWithFormat:@"at %@", time];
        self.displayTexts = texts;
    }
    
    // 获取目标文本 - 增加"Start "前缀
    NSString *targetText = [NSString stringWithFormat:@"Start %@", self.displayTexts[self.currentTextIndex]];
    
    if (self.isErasing) {
        // 删除动画
        if (self.charIndex > 0) {
            self.charIndex--;
            // 从完整文本（包括"Start"）中截取
            self.currentDisplayText = [targetText substringToIndex:self.charIndex];
            // 更新渐变蒙版文字
            self.gradientTextMask.string = self.currentDisplayText;
        } else {
            // 删除完成，准备切换到下一个文本
            self.isErasing = NO;
            // 不立即开始输入，而是延迟 1 秒
            self.currentTextIndex = (self.currentTextIndex + 1) % self.displayTexts.count;
            
            // 1 秒后开始新的打字动画
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // 重置字符索引和当前显示文本
                self.charIndex = 0;
                self.currentDisplayText = @"";
                self.gradientTextMask.string = @""; // 清空显示
                self.isTyping = YES;
            });
        }
    } else if (self.isTyping) {
        // 输入动画
        targetText = [NSString stringWithFormat:@"Start %@", self.displayTexts[self.currentTextIndex]];
        if (self.charIndex < targetText.length) {
            self.charIndex++;
            self.currentDisplayText = [targetText substringToIndex:self.charIndex];
            // 更新渐变蒙版文字
            self.gradientTextMask.string = self.currentDisplayText;
        } else {
            // 输入完成，等待一段时间再开始删除
            self.isTyping = NO;
            
            // 2 秒后开始删除
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (!self.isTyping && !self.isErasing) {
                    self.isErasing = YES;
                }
            });
        }
    }
}

- (void)updateDisplayTexts {
    NSDate *now = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSInteger currentYear = [calendar component:NSCalendarUnitYear fromDate:now];
    NSInteger age = currentYear - self.birthYear;
    
    // 设置月份格式
    [self.dateFormatter setDateFormat:@"MMMM"];
    NSString *month = [self.dateFormatter stringFromDate:now];
    
    // 设置星期格式
    [self.dateFormatter setDateFormat:@"EEEE"];
    NSString *weekday = [self.dateFormatter stringFromDate:now];
    
    // 获取日期
    NSInteger day = [calendar component:NSCalendarUnitDay fromDate:now];
    
    // 为日期添加后缀 (st, nd, rd, th)
    NSString *daySuffix;
    if (day % 10 == 1 && day != 11) {
        daySuffix = @"st";
    } else if (day % 10 == 2 && day != 12) {
        daySuffix = @"nd";
    } else if (day % 10 == 3 && day != 13) {
        daySuffix = @"rd";
    } else {
        daySuffix = @"th";
    }
    
    // 获取时间
    NSString *time = [self.timeFormatter stringFromDate:now];
    
    self.displayTexts = @[
        [NSString stringWithFormat:@"in %@", month],
        [NSString stringWithFormat:@"on %ld%@", (long)day, daySuffix], // 添加后缀
        [NSString stringWithFormat:@"in your %lds", (long)age],
        [NSString stringWithFormat:@"on %@", weekday],
        [NSString stringWithFormat:@"at %@", time],
        @"Now"
    ];
    
    // 如果当前没有显示文本，初始化为第一个文本的第一个字符
    if (self.currentDisplayText.length == 0 && self.displayTexts.count > 0) {
        self.currentDisplayText = @"";
        self.charIndex = 0;
        self.isTyping = YES;
        self.isErasing = NO;
    }
    
    // 确保字体设置正确
    [self applyCustomFontToTextLayers];
}

- (void)updateDisplay {
    [self updateDisplayTexts];
}

- (void)drawRect:(NSRect)rect {
    // 空实现，因为我们使用图层显示内容
}

- (void)animateOneFrame {
    // 不在这里切换文本索引，由 typingTimer 控制
    [self setNeedsDisplay:YES];
}

- (void)dealloc {
    [self.updateTimer invalidate];
    self.updateTimer = nil;
    
    [self.typingTimer invalidate];
    self.typingTimer = nil;
    
    // 移除 KVO 观察者 (以防万一还没被移除)
    @try {
        [self.videoPlayer.currentItem removeObserver:self forKeyPath:@"status"];
    } @catch (NSException *exception) {
        // 忽略已经被移除的情况
    }
    
    // 移除通知观察者
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:self.videoPlayer.currentItem];
    
    #if DEBUG
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    #endif
}

- (void)startAnimation {
    [super startAnimation];
    
    // 确保文字使用正确的字体
    [self applyCustomFontToTextLayers];
    
    // 从随机位置继续播放
    if (self.videoPlayer && self.videoPlayer.currentItem) {
        CMTime duration = self.videoPlayer.currentItem.duration;
        if (CMTIME_IS_VALID(duration) && !CMTIME_IS_INDEFINITE(duration)) {
            Float64 durationSeconds = CMTimeGetSeconds(duration);
            Float64 randomSeconds = durationSeconds * ((Float64)arc4random() / UINT32_MAX);
            CMTime randomTime = CMTimeMakeWithSeconds(randomSeconds, NSEC_PER_SEC);
            
            [self.videoPlayer seekToTime:randomTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        }
    }
    
    // 恢复视频播放
    [self.videoPlayer play];
}

- (void)stopAnimation {
    [super stopAnimation];
    
    // 暂停视频播放
    [self.videoPlayer pause];
    
    [self.typingTimer invalidate];
    self.typingTimer = nil;
}

#pragma mark - 配置相关方法

// 保存配置的用户默认域
- (NSString *)defaultsKey {
    return @"com.jason.StartNow";
}

// 获取保存出生年份的 key
- (NSString *)birthYearKey {
    return [NSString stringWithFormat:@"%@.birthYear", [self defaultsKey]];
}

// 从偏好设置读取出生年份
- (void)loadBirthYear {
    // 获取用户偏好设置中的出生年份，如果没有则使用默认值 1995
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger savedBirthYear = [defaults integerForKey:[self birthYearKey]];
    if (savedBirthYear > 0) {
        self.birthYear = savedBirthYear;
    } else {
        self.birthYear = 1995; // 默认出生年份
    }
}

// 在初始化时调用此方法加载配置
- (void)loadConfiguration {
    [self loadBirthYear];
}

// 保存出生年份到偏好设置
- (void)saveBirthYear {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:self.birthYear forKey:[self birthYearKey]];
    [defaults synchronize];
}

- (BOOL)hasConfigureSheet {
    return YES;
}

- (NSWindow*)configureSheet {
    // 如果已经创建了配置表单，直接返回以避免重复创建
    if (self.configSheet) {
        return self.configSheet;
    }
    
    // 创建更窄的配置窗口
    NSWindow *sheet = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 280, 140)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
        backing:NSBackingStoreBuffered
        defer:NO];
    
    [sheet setTitle:@"Start Now Settings"];
    self.configSheet = sheet;
    
    // 创建内容视图
    NSView *contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 280, 140)];
    [sheet setContentView:contentView];
    
    // 定义控件尺寸和位置变量
    CGFloat buttonWidth = 70;
    CGFloat rightMargin = 20;
    CGFloat leftMargin = 20;
    CGFloat windowWidth = 280;
    
    // 精确计算右对齐位置 - 确保年份输入框和 OK 按钮完全右对齐
    CGFloat rightAlignedX = windowWidth - rightMargin - buttonWidth;
    
    // 添加标签
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(leftMargin, 90, 150, 20)];
    [label setStringValue:@"Enter your birth year:"];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setFont:[NSFont systemFontOfSize:13]];
    [label setTextColor:[NSColor labelColor]];
    [contentView addSubview:label];
    
    // 添加输入框 - 确保宽度和位置与按钮完全一致
    NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(rightAlignedX, 90, buttonWidth, 22)];
    [textField setStringValue:[NSString stringWithFormat:@"%ld", (long)self.birthYear]];
    [textField setFont:[NSFont systemFontOfSize:13]];
    [contentView addSubview:textField];
    self.birthYearTextField = textField;
    
    // 添加分隔线
    NSBox *separator = [[NSBox alloc] initWithFrame:NSMakeRect(leftMargin, 60, windowWidth - leftMargin - rightMargin, 1)];
    [separator setBoxType:NSBoxSeparator];
    [contentView addSubview:separator];
    
    // 添加网址小文字，左对齐与上面标签
    NSTextField *urlLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(leftMargin, 22, 180, 20)];
    [urlLabel setStringValue:@"crafted by ventuss.xyz"];
    [urlLabel setBezeled:NO];
    [urlLabel setDrawsBackground:NO];
    [urlLabel setEditable:NO];
    [urlLabel setSelectable:NO];
    [urlLabel setFont:[NSFont systemFontOfSize:11]];
    [urlLabel setTextColor:[NSColor grayColor]]; // 使用灰色使其显得不那么突出
    [contentView addSubview:urlLabel];
    
    // 添加 OK 按钮 - 确保与输入框精确对齐
    NSButton *okButton = [[NSButton alloc] initWithFrame:NSMakeRect(rightAlignedX, 20, 78, 24)];
    [okButton setTitle:@"OK"];
    [okButton setBezelStyle:NSBezelStyleRounded];
    [okButton setKeyEquivalent:@"\r"]; // 回车键触发
    [okButton setTarget:self];
    [okButton setAction:@selector(saveOptions:)];
    [contentView addSubview:okButton];
    
    // 设置默认按钮
    [sheet setDefaultButtonCell:[okButton cell]];
    
    // 居中显示
    [sheet center];
    
    return sheet;
}

// 修改 saveOptions 方法，确保更新年份后应用字体
- (IBAction)saveOptions:(id)sender {
    // 获取输入框中的值
    NSInteger enteredYear = [self.birthYearTextField.stringValue integerValue];
    
    // 验证输入的年份是否合理（例如，不应该是未来的年份或太早的年份）
    NSInteger currentYear = [[NSCalendar currentCalendar] component:NSCalendarUnitYear fromDate:[NSDate date]];
    
    if (enteredYear > 0 && enteredYear <= currentYear) {
        // 保存出生年份
        self.birthYear = enteredYear;
        [self saveBirthYear];
        
        // 更新显示文本以反映新的年龄
        [self updateDisplayTexts];
        
        // 更新文字图层字体 - 使用共享方法确保字体一致性
        [self applyCustomFontToTextLayers];
        
        // 正确关闭配置窗口
        [[NSApplication sharedApplication] endSheet:self.configSheet];
        [self.configSheet orderOut:nil]; // 必须调用 orderOut 移除窗口
    } else {
        // 显示错误提示 - 修改为英文错误信息
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Input Error"];
        [alert setInformativeText:[NSString stringWithFormat:@"Please enter a valid birth year (1-%ld)", (long)currentYear]];
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:self.configSheet completionHandler:nil];
        return;
    }
}

// 修改 setupVideoBackground 方法，调整预览模式下的视频播放质量
- (void)setupVideoBackground {
    // 调试日志
    NSLog(@"开始设置视频背景");
    
    // 设置视频路径，这里假设视频文件放在 Resources 文件夹中
    NSString *videoName = @"background"; // 不含扩展名的视频文件名
    NSString *videoType = @"mp4";        // 视频文件扩展名
    
    // 尝试从主 bundle 获取资源
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    self.videoPath = [bundle pathForResource:videoName ofType:videoType];
    
    // 如果找不到，尝试从主 bundle 获取
    if (!self.videoPath) {
        NSLog(@"在 bundle 中找不到视频文件，尝试从主 bundle 加载");
        self.videoPath = [[NSBundle mainBundle] pathForResource:videoName ofType:videoType];
    }
    
    // 如果找不到，尝试直接使用完整路径
    if (!self.videoPath) {
        NSLog(@"在主 bundle 中也找不到视频文件，尝试使用完整路径");
        // 使用直接路径 - 确保 Resources 文件夹路径正确
        self.videoPath = @"/Users/jason/Documents/Cerelib/Projects/Coding/Start Now/Resources/background.mp4";
    }
    
    if (self.videoPath) {
        NSLog(@"找到视频文件：%@", self.videoPath);
        
        // 创建视频播放器
        NSURL *videoURL = [NSURL fileURLWithPath:self.videoPath];
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:videoURL];
        self.videoPlayer = [AVPlayer playerWithPlayerItem:playerItem];
        
        // 创建视频图层
        self.videoPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.videoPlayer];
        self.videoPlayerLayer.frame = self.bounds;
        
        // 在预览模式下使用不同的填充方式，以确保视频在小窗口中也能正确显示
        if ([self isPreview]) {
            self.videoPlayerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        } else {
            self.videoPlayerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        }
        
        // 将视频图层添加到视图的图层中 - 确保在最底层
        [self.layer insertSublayer:self.videoPlayerLayer atIndex:0]; 
        
        // 设置循环播放
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                selector:@selector(playerItemDidReachEnd:)
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:playerItem];
        
        // 使用 KVO 监听视频准备就绪状态
        [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
        
        // 先不要播放，等待视频加载完成后再从随机位置开始播放
    } else {
        NSLog(@"无法找到视频文件");
    }
}

// 视频播放结束后循环播放
- (void)playerItemDidReachEnd:(NSNotification *)notification {
    AVPlayerItem *item = [notification object];
    [item seekToTime:kCMTimeZero completionHandler:nil];
    [self.videoPlayer play];
}

// KVO 观察视频加载状态
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItem *playerItem = (AVPlayerItem *)object;
        if (playerItem.status == AVPlayerItemStatusReadyToPlay) {
            // 视频已准备就绪，可以从随机位置开始播放
            [playerItem removeObserver:self forKeyPath:@"status"];
            
            // 生成一个随机时间点
            CMTime duration = playerItem.duration;
            if (CMTIME_IS_VALID(duration) && !CMTIME_IS_INDEFINITE(duration)) {
                Float64 durationSeconds = CMTimeGetSeconds(duration);
                // 避免选择太接近结尾的位置
                Float64 maxSeconds = durationSeconds * 0.8; 
                Float64 randomSeconds = maxSeconds * ((Float64)arc4random() / UINT32_MAX);
                CMTime randomTime = CMTimeMakeWithSeconds(randomSeconds, NSEC_PER_SEC);
                
                // 从随机位置开始播放
                [self.videoPlayer seekToTime:randomTime completionHandler:^(BOOL finished) {
                    if (finished) {
                        [self.videoPlayer play];
                        NSLog(@"视频开始播放，从随机位置开始：%.2f 秒", randomSeconds);
                    }
                }];
            } else {
                [self.videoPlayer play];
                NSLog(@"视频时长无效，从头开始播放");
            }
        }
    }
}

// 重写 resizeWithOldSuperviewSize 方法，确保视图大小改变时重新调整位置
- (void)resizeWithOldSuperviewSize:(NSSize)oldSize {
    [super resizeWithOldSuperviewSize:oldSize];
    
    // 调整视频图层大小
    self.videoPlayerLayer.frame = self.bounds;
    
    // 调整遮罩层大小
    self.overlayLayer.frame = self.bounds;
    
    // 调整文字图层位置
    [self updateTextLayersPosition];
    
    NSLog(@"视图大小已改变，重新调整遮罩层和文字层位置");
}

// 为两色渐变设计简单的动画效果
- (void)animateGradient {
    // 创建动画
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"locations"];
    
    // 两色渐变的位置动画 - 确保渐变色完整显示在每个文本上
    animation.fromValue = @[@0.0, @1.0]; // 开始位置
    animation.toValue = @[@0.0, @1.0];   // 结束位置保持不变
    
    animation.duration = 3.0;
    animation.repeatCount = HUGE_VALF; // 无限循环
    animation.autoreverses = YES;      // 往返动画，更自然
    
    // 应用动画
    [self.gradientLayer addAnimation:animation forKey:@"gradientAnimation"];
}

// 创建半透明遮罩层
- (void)setupOverlayLayer {
    // 创建遮罩层
    self.overlayLayer = [CALayer layer];
    self.overlayLayer.frame = self.bounds;
    
    // 设置深色半透明背景 - 黑色 with 40% 透明度
    self.overlayLayer.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.618].CGColor;
    
    // 将遮罩层添加到视图的图层中，确保在视频层之上，文字层之下
    if (self.videoPlayerLayer) {
        [self.layer insertSublayer:self.overlayLayer above:self.videoPlayerLayer];
    } else {
        // 如果视频层尚未创建，直接添加到主层
        [self.layer addSublayer:self.overlayLayer];
    }
    
    NSLog(@"半透明遮罩层已添加 - 位于视频层之上，文字层之下");
}

// 添加 willStop 方法处理屏保关闭通知
- (void)willStop:(NSNotification *)notification {
    if (![self isPreview]) {
        // 只处理全屏模式的屏保，而不是系统设置中的预览
        [NSApplication.sharedApplication terminate:nil];
    }
}

#if DEBUG
- (void)injected {
    // 重置状态
    self.currentTextIndex = 0;
    self.currentDisplayText = @"";
    self.isTyping = YES;
    self.isErasing = NO;
    self.charIndex = 0;
    [self updateDisplayTexts];
    
    // 更新文字图层
    self.firstLineTextLayer.string = @"Think Different";
    self.gradientTextMask.string = @""; // 清空，等待动画开始
    
    // 确保字体设置正确
    [self applyCustomFontToTextLayers];
    
    // 重置计时器
    [self.typingTimer invalidate];
    self.typingTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                       target:self
                                                     selector:@selector(updateTypingAnimation)
                                                     userInfo:nil
                                                      repeats:YES];
    
    // 重置渐变动画
    [self animateGradient];
    
    // 重置视频播放
    if (self.videoPlayer) {
        [self.videoPlayer seekToTime:kCMTimeZero];
        [self.videoPlayer play];
    }
    
    NSLog(@"屏保视图已热重载 - %@", [NSDate date]);
}
#endif

@end
