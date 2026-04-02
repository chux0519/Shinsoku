#include "platform/macos/macos_hud_presenter.hpp"

#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>

#include <QColor>
#include <QString>

#include <array>

namespace {

NSString* nsstring_from_qstring(const QString& value) {
    return [NSString stringWithUTF8String:value.toUtf8().constData()];
}

NSColor* nscolor_from_hex(const QString& hex) {
    QColor color(hex);
    if (!color.isValid()) {
        color = QColor("#111315");
    }
    return [NSColor colorWithSRGBRed:color.redF() green:color.greenF() blue:color.blueF() alpha:color.alphaF()];
}

bool is_dark_mode() {
    if (@available(macOS 10.14, *)) {
        NSAppearance* appearance = [NSApp effectiveAppearance];
        NSAppearanceName name = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
        return [name isEqualToString:NSAppearanceNameDarkAqua];
    }
    return false;
}

bool uses_waveform_indicator(const QString& text) {
    return text == "Recording" || text == "Listening";
}

bool uses_processing_indicator(const QString& text) {
    return text == "Transcribing" || text == "Thinking";
}

NSScreen* best_screen() {
    const NSPoint mouse = [NSEvent mouseLocation];
    for (NSScreen* screen in [NSScreen screens]) {
        if (NSMouseInRect(mouse, screen.frame, NO)) {
            return screen;
        }
    }
    return [NSScreen mainScreen] != nil ? [NSScreen mainScreen] : [NSScreen screens].firstObject;
}

NSRect hud_frame_for_screen(NSScreen* screen, CGFloat width, CGFloat height, int bottom_margin) {
    if (screen == nil) {
        return NSMakeRect(0, 0, width, height);
    }
    const NSRect visible = screen.visibleFrame;
    const CGFloat x = NSMidX(visible) - width / 2.0;
    const CGFloat y = NSMinY(visible) + bottom_margin;
    return NSMakeRect(x, y, width, height);
}

CGFloat hud_width_for_text(const QString& text, bool persistent_state) {
    if (persistent_state) {
        return 196.0;
    }
    if (text == "Copied") {
        return 108.0;
    }
    return std::max<CGFloat>(156.0, 76.0 + text.size() * 7.0);
}

bool is_persistent_state(const QString& text) {
    return text == "Recording" || text == "Listening" || text == "Transcribing" || text == "Thinking";
}

}  // namespace

@interface ShinsokuHudPanel : NSPanel
@end

@implementation ShinsokuHudPanel

- (BOOL)canBecomeKeyWindow {
    return NO;
}

- (BOOL)canBecomeMainWindow {
    return NO;
}

@end

typedef NS_ENUM(NSInteger, ShinsokuHudIndicatorMode) {
    ShinsokuHudIndicatorModeNone = 0,
    ShinsokuHudIndicatorModeWaveform,
    ShinsokuHudIndicatorModeProcessing,
};

@interface ShinsokuHudIndicatorView : NSView

@property(nonatomic, strong) NSColor* accentColor;
@property(nonatomic, assign) BOOL commandMode;
@property(nonatomic, assign) CGFloat phase;
@property(nonatomic, assign) ShinsokuHudIndicatorMode mode;

@end

@implementation ShinsokuHudIndicatorView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self != nil) {
        _accentColor = [NSColor colorWithSRGBRed:0.07 green:0.08 blue:0.09 alpha:1.0];
        _phase = 0.0;
        _mode = ShinsokuHudIndicatorModeNone;
        self.wantsLayer = YES;
    }
    return self;
}

- (BOOL)isOpaque {
    return NO;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    if (self.mode == ShinsokuHudIndicatorModeNone) {
        return;
    }

    [[NSColor clearColor] setFill];
    NSRectFill(dirtyRect);

    if (self.mode == ShinsokuHudIndicatorModeWaveform) {
        static constexpr std::array<CGFloat, 5> offsets = {0.0, 0.19, 0.37, 0.58, 0.81};
        static constexpr std::array<CGFloat, 5> baselines = {0.36, 0.58, 0.8, 0.58, 0.36};
        const CGFloat barWidth = 3.0;
        const CGFloat spacing = 1.0;
        const CGFloat minHeight = 4.0;
        const CGFloat totalWidth = barWidth * offsets.size() + spacing * (offsets.size() - 1);
        const CGFloat originX = (NSWidth(self.bounds) - totalWidth) / 2.0;
        const CGFloat centerY = NSHeight(self.bounds) / 2.0;

        for (NSInteger i = 0; i < static_cast<NSInteger>(offsets.size()); ++i) {
            const CGFloat wave = 0.5 + 0.5 * std::sin((self.phase + offsets[static_cast<std::size_t>(i)]) * M_PI * 2.0);
            const CGFloat amplitude = baselines[static_cast<std::size_t>(i)] + wave * 0.34;
            const CGFloat height = std::clamp(std::round(amplitude * NSHeight(self.bounds)), minHeight, NSHeight(self.bounds));
            const CGFloat x = originX + i * (barWidth + spacing);
            const CGFloat y = centerY - height / 2.0;
            NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(x, y, barWidth, height) xRadius:1.5 yRadius:1.5];
            [[self.accentColor colorWithAlphaComponent:self.commandMode ? 0.92 : 0.88] setFill];
            [path fill];
        }
        return;
    }

    if (self.mode == ShinsokuHudIndicatorModeProcessing) {
        static constexpr std::array<CGFloat, 3> offsets = {0.0, 0.17, 0.34};
        const CGFloat dotSize = 4.0;
        const CGFloat gap = 3.0;
        const CGFloat totalWidth = dotSize * 3 + gap * 2;
        const CGFloat originX = (NSWidth(self.bounds) - totalWidth) / 2.0;
        const CGFloat originY = (NSHeight(self.bounds) - dotSize) / 2.0;

        for (NSInteger i = 0; i < 3; ++i) {
            const CGFloat pulse = 0.35 + 0.65 * (0.5 + 0.5 * std::sin((self.phase + offsets[static_cast<std::size_t>(i)]) * M_PI * 2.0));
            [[self.accentColor colorWithAlphaComponent:pulse] setFill];
            NSBezierPath* path = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(originX + i * (dotSize + gap), originY, dotSize, dotSize)];
            [path fill];
        }
    }
}

@end

namespace ohmytypeless {

class MacOSHudPresenter::Impl {
public:
    explicit Impl(QWidget* host_window) : host_window_(host_window) {
        (void)host_window_;

        panel_ = [[ShinsokuHudPanel alloc] initWithContentRect:NSMakeRect(0, 0, 220, 58)
                                                     styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                                       backing:NSBackingStoreBuffered
                                                         defer:NO];
        [panel_ setLevel:NSStatusWindowLevel];
        [panel_ setOpaque:NO];
        [panel_ setBackgroundColor:[NSColor clearColor]];
        [panel_ setHasShadow:YES];
        [panel_ setHidesOnDeactivate:NO];
        [panel_ setIgnoresMouseEvents:YES];
        [panel_ setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces |
                                      NSWindowCollectionBehaviorFullScreenAuxiliary |
                                      NSWindowCollectionBehaviorTransient];

        NSView* content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 220, 58)];
        [content setWantsLayer:YES];
        content.layer.cornerRadius = 16.0;
        content.layer.masksToBounds = YES;
        [panel_ setContentView:content];

        indicator_ = [[ShinsokuHudIndicatorView alloc] initWithFrame:NSMakeRect(13, 15, 16, 18)];
        [content addSubview:indicator_];

        label_ = [[NSTextField alloc] initWithFrame:NSMakeRect(36, 16, 148, 24)];
        [label_ setBezeled:NO];
        [label_ setBordered:NO];
        [label_ setEditable:NO];
        [label_ setSelectable:NO];
        [label_ setDrawsBackground:NO];
        [label_ setAlignment:NSTextAlignmentCenter];
        [label_ setFont:[NSFont systemFontOfSize:14 weight:NSFontWeightSemibold]];
        [content addSubview:label_];

        animation_timer_ = [NSTimer timerWithTimeInterval:(1.0 / 30.0)
                                                   repeats:YES
                                                     block:^(__unused NSTimer* timer) {
                                                         this->phase_ += 0.038;
                                                         if (this->phase_ > 1.0) {
                                                             this->phase_ -= 1.0;
                                                         }
                                                         [this->indicator_ setPhase:this->phase_];
                                                         [this->indicator_ setNeedsDisplay:YES];
                                                     }];
        [[NSRunLoop mainRunLoop] addTimer:animation_timer_ forMode:NSRunLoopCommonModes];
        [animation_timer_ setTolerance:0.01];
        [animation_timer_ invalidate];
    }

    void apply_config(const HudConfig& config) {
        config_ = config;
        if (!config_.enabled) {
            hide();
        }
    }

    bool supports_overlay_hud() const {
        return true;
    }

    void show_recording(bool command_mode) {
        show_text(command_mode ? "Listening" : "Recording",
                  is_dark_mode() ? "#f3f4f6" : "#111315",
                  command_mode ? (is_dark_mode() ? "#2b3138" : "#f8fafc") : (is_dark_mode() ? "#1d2126" : "#ffffff"),
                  0);
    }

    void show_transcribing() {
        show_text("Transcribing", is_dark_mode() ? "#d1d5db" : "#1f2933", is_dark_mode() ? "#1d2126" : "#ffffff", 0);
    }

    void show_thinking() {
        show_text("Thinking", is_dark_mode() ? "#cbd5e1" : "#374151", is_dark_mode() ? "#1d2126" : "#ffffff", 0);
    }

    void show_notice(const QString& text, int duration_ms) {
        show_text(text, is_dark_mode() ? "#e5e7eb" : "#111315", is_dark_mode() ? "#1d2126" : "#ffffff", duration_ms);
    }

    void show_error(const QString& text, int duration_ms) {
        show_text(text, is_dark_mode() ? "#fecaca" : "#991b1b", is_dark_mode() ? "#2a1619" : "#fff7f7", duration_ms);
    }

    void hide() {
        pending_hide_token_++;
        [animation_timer_ invalidate];
        [panel_ orderOut:nil];
    }

private:
    void show_text(const QString& text, const QString& text_hex, const QString& background_hex, int duration_ms) {
        if (!config_.enabled || panel_ == nil || label_ == nil) {
            return;
        }

        pending_hide_token_++;
        const std::uint64_t token = pending_hide_token_;

        NSTextField* label = label_;
        ShinsokuHudPanel* panel = panel_;
        NSView* content = panel.contentView;
        if (content == nil) {
            return;
        }

        [label setStringValue:nsstring_from_qstring(text)];
        [label setTextColor:nscolor_from_hex(text_hex)];

        content.layer.backgroundColor = nscolor_from_hex(background_hex).CGColor;
        content.layer.borderColor = [NSColor colorWithWhite:(is_dark_mode() ? 1.0 : 0.0) alpha:0.10].CGColor;
        content.layer.borderWidth = 1.0;
        content.layer.shadowColor = [NSColor colorWithWhite:0.0 alpha:0.20].CGColor;
        content.layer.shadowOpacity = 1.0;
        content.layer.shadowRadius = 18.0;
        content.layer.shadowOffset = NSMakeSize(0, 10);

        const bool waveform = uses_waveform_indicator(text);
        const bool processing = uses_processing_indicator(text);
        const bool has_indicator = waveform || processing;
        indicator_.hidden = !has_indicator;
        indicator_.mode = waveform ? ShinsokuHudIndicatorModeWaveform
                                   : (processing ? ShinsokuHudIndicatorModeProcessing : ShinsokuHudIndicatorModeNone);
        indicator_.commandMode = text == "Listening";
        indicator_.accentColor = nscolor_from_hex(text_hex);
        if (has_indicator) {
            phase_ = 0.0;
            indicator_.phase = phase_;
            [indicator_ setNeedsDisplay:YES];
            if (![animation_timer_ isValid]) {
                animation_timer_ = [NSTimer timerWithTimeInterval:(1.0 / 30.0)
                                                           repeats:YES
                                                             block:^(__unused NSTimer* timer) {
                                                                 this->phase_ += waveform ? 0.04 : 0.03;
                                                                 if (this->phase_ > 1.0) {
                                                                     this->phase_ -= 1.0;
                                                                 }
                                                                 [this->indicator_ setPhase:this->phase_];
                                                                 [this->indicator_ setNeedsDisplay:YES];
                                                             }];
                [[NSRunLoop mainRunLoop] addTimer:animation_timer_ forMode:NSRunLoopCommonModes];
                [animation_timer_ setTolerance:0.01];
            }
        } else {
            [animation_timer_ invalidate];
        }

        const CGFloat width = hud_width_for_text(text, is_persistent_state(text));
        const CGFloat height = 52.0;
        if (has_indicator) {
            [indicator_ setFrame:NSMakeRect(13, 17, 16, 18)];
            [label setFrame:NSMakeRect(36, 15, width - 47, 22)];
        } else {
            [label setFrame:NSMakeRect(16, 15, width - 32, 22)];
        }

        NSScreen* screen = best_screen();
        [panel setFrame:hud_frame_for_screen(screen, width, height, config_.bottom_margin) display:NO];
        [panel orderFrontRegardless];

        if (duration_ms > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, static_cast<int64_t>(duration_ms) * NSEC_PER_MSEC),
                           dispatch_get_main_queue(), ^{
                               if (this->pending_hide_token_ == token) {
                                   [panel orderOut:nil];
                               }
                           });
        }
    }

    QWidget* host_window_ = nullptr;
    HudConfig config_;
    ShinsokuHudPanel* panel_ = nil;
    ShinsokuHudIndicatorView* indicator_ = nil;
    NSTextField* label_ = nil;
    NSTimer* animation_timer_ = nil;
    CGFloat phase_ = 0.0;
    std::uint64_t pending_hide_token_ = 0;
};

MacOSHudPresenter::MacOSHudPresenter(QWidget* host_window) : impl_(std::make_unique<Impl>(host_window)) {}
MacOSHudPresenter::~MacOSHudPresenter() = default;

void MacOSHudPresenter::apply_config(const HudConfig& config) {
    impl_->apply_config(config);
}

bool MacOSHudPresenter::supports_overlay_hud() const {
    return impl_->supports_overlay_hud();
}

void MacOSHudPresenter::show_recording(bool command_mode) {
    impl_->show_recording(command_mode);
}

void MacOSHudPresenter::show_transcribing() {
    impl_->show_transcribing();
}

void MacOSHudPresenter::show_thinking() {
    impl_->show_thinking();
}

void MacOSHudPresenter::show_notice(const QString& text, int duration_ms) {
    impl_->show_notice(text, duration_ms);
}

void MacOSHudPresenter::show_error(const QString& text, int duration_ms) {
    impl_->show_error(text, duration_ms);
}

void MacOSHudPresenter::hide() {
    impl_->hide();
}

}  // namespace ohmytypeless
