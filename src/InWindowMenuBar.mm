#import "InWindowMenuBar.h"
#import "NppThemeManager.h"

@interface NppInWindowMenuBar ()
@property (nonatomic, strong) NSStackView *stack;
@property (nonatomic, copy) NSArray<NSMenu *> *menus;
@end

@implementation NppInWindowMenuBar

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;

        _stack = [[NSStackView alloc] init];
        _stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        _stack.spacing = 2;
        _stack.alignment = NSLayoutAttributeCenterY;
        _stack.edgeInsets = NSEdgeInsetsMake(0, 6, 0, 6);
        _stack.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_stack];
        [NSLayoutConstraint activateConstraints:@[
            [_stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_stack.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];

        [self rebuildFromMainMenu];
        [self _applyBackground];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_themeChanged:)
                                                     name:NPPDarkModeChangedNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)rebuildFromMainMenu {
    for (NSView *v in [self.stack.arrangedSubviews copy]) {
        [self.stack removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    NSMutableArray<NSMenu *> *menus = [NSMutableArray array];
    for (NSMenuItem *top in [NSApp mainMenu].itemArray) {
        // Only the document menus are hidden from the macOS bar; the App menu stays there.
        if (!top.hidden || !top.submenu) continue;

        NSButton *button = [NSButton buttonWithTitle:top.submenu.title
                                              target:self
                                              action:@selector(_menuButtonClicked:)];
        button.bordered = NO;
        button.font = [NSFont systemFontOfSize:12];
        button.tag = (NSInteger)menus.count;
        [menus addObject:top.submenu];
        [self.stack addArrangedSubview:button];
    }
    self.menus = menus;
}

- (void)_menuButtonClicked:(NSButton *)sender {
    if (sender.tag < 0 || (NSUInteger)sender.tag >= self.menus.count) return;
    NSMenu *menu = self.menus[(NSUInteger)sender.tag];
    // Drop the menu just below the button (view is not flipped: y = 0 is its bottom edge).
    [menu popUpMenuPositioningItem:nil
                        atLocation:NSMakePoint(0, -2)
                            inView:sender];
}

- (void)_applyBackground {
    BOOL dark = [NppThemeManager shared].isDark;
    NSColor *bg = dark ? [NSColor colorWithCalibratedWhite:0.125 alpha:1.0]
                       : [NSColor colorWithCalibratedWhite:0.94 alpha:1.0];
    self.layer.backgroundColor = bg.CGColor;
}

- (void)_themeChanged:(NSNotification *)note {
    [self _applyBackground];
}

@end
