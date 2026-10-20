#import "ContentToolbar.h"

extern NSString *const kPrefToolbarIconScale;

static const CGFloat kContentToolbarHeight = 34.0;
static const CGFloat kOverflowButtonWidth  = 22.0;
// Popover icons match the toolbar row: a 20-point icon in a 24-point button.
// The row's button size follows the toolbar icon-scale preference (same formula as
// MainWindowController's metrics), so popover buttons match the row exactly.
static CGFloat NppOverflowButtonSize(void) {
    double s = [[NSUserDefaults standardUserDefaults] doubleForKey:kPrefToolbarIconScale];
    if (s < 0.50 - 1e-6 || s > 1.50 + 1e-6) s = 1.0;
    return round(28.0 * s);
}

@interface NppContentToolbar ()
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSStackView *stack;
@property (nonatomic, strong) NSStackView *pinnedStack;    // fixed at the right edge
@property (nonatomic, strong) NSButton *overflowButton;
@property (nonatomic, strong) NSLayoutConstraint *scrollToOverflow;   // used while » is shown
@property (nonatomic, strong) NSLayoutConstraint *scrollToEdge;       // used while » is hidden
@property (nonatomic, strong) NSMutableArray<NSNumber *> *widths;     // natural width per item view
@property (nonatomic, strong) NSPopover *overflowPopover;
@property (nonatomic, copy) NSArray<NSDictionary *> *overflowEntries;
@property (nonatomic) CGFloat overflowIconSize;   // popover icon box, taken from the row's own buttons   // {target, action} per icon
@end

@implementation NppContentToolbar

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _widths = [NSMutableArray array];

        _stack = [[NSStackView alloc] init];
        _stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        _stack.spacing = 1;
        _stack.alignment = NSLayoutAttributeCenterY;
        _stack.edgeInsets = NSEdgeInsetsMake(2, 4, 2, 4);
        _stack.translatesAutoresizingMaskIntoConstraints = NO;

        _pinnedStack = [[NSStackView alloc] init];
        _pinnedStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        _pinnedStack.spacing = 1;
        _pinnedStack.alignment = NSLayoutAttributeCenterY;
        _pinnedStack.edgeInsets = NSEdgeInsetsMake(2, 0, 2, 4);
        _pinnedStack.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_pinnedStack];

        _scrollView = [[NSScrollView alloc] init];
        _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
        _scrollView.hasHorizontalScroller = NO;
        _scrollView.hasVerticalScroller = NO;
        _scrollView.drawsBackground = NO;
        _scrollView.borderType = NSNoBorder;
        _scrollView.documentView = _stack;
        [self addSubview:_scrollView];

        _overflowButton = [NSButton buttonWithTitle:@"»" target:self action:@selector(_overflowClicked:)];
        _overflowButton.bordered = NO;
        _overflowButton.font = [NSFont systemFontOfSize:14];
        _overflowButton.toolTip = @"More buttons";
        _overflowButton.hidden = YES;
        _overflowButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_overflowButton];

        _scrollToOverflow = [_scrollView.trailingAnchor constraintEqualToAnchor:_overflowButton.leadingAnchor];
        _scrollToEdge = [_scrollView.trailingAnchor constraintEqualToAnchor:_pinnedStack.leadingAnchor];
        _scrollToEdge.active = YES;

        [NSLayoutConstraint activateConstraints:@[
            [_scrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_scrollView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_scrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [_pinnedStack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_pinnedStack.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_pinnedStack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [_overflowButton.trailingAnchor constraintEqualToAnchor:_pinnedStack.leadingAnchor],
            [_overflowButton.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_overflowButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [_overflowButton.widthAnchor constraintEqualToConstant:kOverflowButtonWidth],
            [_stack.topAnchor constraintEqualToAnchor:_scrollView.contentView.topAnchor],
            [_stack.bottomAnchor constraintEqualToAnchor:_scrollView.contentView.bottomAnchor],
            [_stack.leadingAnchor constraintEqualToAnchor:_scrollView.contentView.leadingAnchor],
            [_stack.heightAnchor constraintEqualToAnchor:_scrollView.contentView.heightAnchor],
        ]];
    }
    return self;
}

- (NSSize)intrinsicContentSize {
    return NSMakeSize(NSViewNoIntrinsicMetric, kContentToolbarHeight);
}

- (NSArray<NSView *> *)itemViews {
    return [self.stack.arrangedSubviews arrayByAddingObjectsFromArray:self.pinnedStack.arrangedSubviews];
}

- (void)setToolbarItems:(NSArray<NSToolbarItem *> *)items {
    for (NSView *v in [self.stack.arrangedSubviews copy]) {
        [self.stack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    for (NSView *v in [self.pinnedStack.arrangedSubviews copy]) {
        [self.pinnedStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    [self.widths removeAllObjects];

    for (NSToolbarItem *item in items) {
        NSView *view = nil;
        if ([item.itemIdentifier isEqualToString:NSToolbarSeparatorItemIdentifier]) {
            NSBox *divider = [[NSBox alloc] init];
            divider.boxType = NSBoxSeparator;
            divider.translatesAutoresizingMaskIntoConstraints = NO;
            [divider.widthAnchor constraintEqualToConstant:1].active = YES;
            [divider.heightAnchor constraintEqualToConstant:kContentToolbarHeight - 10].active = YES;
            view = divider;
        } else if ([item.itemIdentifier isEqualToString:NSToolbarSpaceItemIdentifier]) {
            // A fixed gap between Tahoe capsules: an empty view with an 8-point width.
            view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 8, 1)];
            view.identifier = @"space";
        } else if ([item.itemIdentifier isEqualToString:NSToolbarFlexibleSpaceItemIdentifier]) {
            view = [[NSView alloc] init];
            view.translatesAutoresizingMaskIntoConstraints = NO;
            [view setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
        } else if (item.view) {
            view = item.view;
        } else {
            NSButton *button = [NSButton buttonWithImage:item.image ?: [NSImage imageNamed:NSImageNameActionTemplate]
                                                  target:item.target
                                                  action:item.action];
            button.bordered = NO;
            button.toolTip = item.toolTip ?: item.label;
            button.translatesAutoresizingMaskIntoConstraints = NO;
            view = button;
        }
        if (view.superview) [view removeFromSuperview];

        // Each item keeps its natural size; the stack never squeezes it.
        view.translatesAutoresizingMaskIntoConstraints = NO;
        // Views with their own frame (Tahoe capsules, group views) keep it; fittingSize
        // would shrink them to their constraints, which clips them.
        NSSize fit = item.view ? item.view.frame.size : view.fittingSize;
        if (fit.width < 1) fit.width = view.frame.size.width;
        if (fit.height < 1) fit.height = kContentToolbarHeight - 8;
        CGFloat width = ceil(fit.width);
        [view.widthAnchor constraintEqualToConstant:width].active = YES;
        [view.heightAnchor constraintEqualToConstant:ceil(fit.height)].active = YES;
        [view setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                        forOrientation:NSLayoutConstraintOrientationHorizontal];
        [view setContentHuggingPriority:NSLayoutPriorityRequired
                         forOrientation:NSLayoutConstraintOrientationHorizontal];
        if ([self.pinnedItemIdentifiers containsObject:item.itemIdentifier]) {
            [self.pinnedStack addArrangedSubview:view];   // never overflows
        } else {
            [self.stack addArrangedSubview:view];
            [self.widths addObject:@(width)];
        }
    }
    [self setNeedsLayout:YES];
}

// Which items fit in `available` points, counting the stack's insets and spacing.
- (NSUInteger)_firstHiddenIndexFittingWidth:(CGFloat)available {
    CGFloat used = self.stack.edgeInsets.left + self.stack.edgeInsets.right;
    for (NSUInteger i = 0; i < self.widths.count; i++) {
        CGFloat add = self.widths[i].doubleValue + (i > 0 ? self.stack.spacing : 0);
        if (used + add > available) return i;
        used += add;
    }
    return self.widths.count;
}

- (void)layout {
    [super layout];

    NSUInteger count = self.widths.count;
    // Pinned items keep their place at the right edge; the rest fits in what is left.
    CGFloat pinnedWidth = self.pinnedStack.fittingSize.width;
    CGFloat available = self.bounds.size.width - pinnedWidth;
    // Everything fits in the full width: no » button.
    NSUInteger cut = [self _firstHiddenIndexFittingWidth:available];
    BOOL overflow = cut < count;
    if (overflow) {
        // » takes space just left of the pinned items; fit the rest into what remains.
        cut = [self _firstHiddenIndexFittingWidth:available - kOverflowButtonWidth];
    }

    self.scrollToOverflow.active = overflow;
    self.scrollToEdge.active = !overflow;
    self.overflowButton.hidden = !overflow;

    NSArray<NSView *> *views = self.stack.arrangedSubviews;
    for (NSUInteger i = 0; i < views.count; i++) {
        BOOL hide = (i >= cut);
        if (views[i].hidden != hide) views[i].hidden = hide;
    }
}

// The NSControls inside a view, including those nested in group views.
- (void)_collectControlsIn:(NSView *)root into:(NSMutableArray<NSControl *> *)out {
    for (NSView *v in root.subviews) {
        if ([v isKindOfClass:[NSControl class]] && ((NSControl *)v).action) [out addObject:(NSControl *)v];
        [self _collectControlsIn:v into:out];
    }
}

// Standard symbols for the controls that are drawn as text glyphs in the row.
- (NSImage *)_symbolImageForAction:(SEL)action {
    NSString *name = NSStringFromSelector(action);
    NSString *symbol = nil;
    if ([name isEqualToString:@"_tabControlNew:"])   symbol = @"plus";
    else if ([name isEqualToString:@"_tabControlList:"] ||
             [name isEqualToString:@"_showAllCharsDropdown:"]) symbol = @"chevron.down";
    else if ([name isEqualToString:@"_tabControlClose:"]) symbol = @"xmark";
    if (!symbol) return nil;
    return [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
}

- (void)_overflowClicked:(NSButton *)sender {
    // The hidden items: each control keeps its image, tooltip, enabled state and action.
    NSMutableArray<NSButton *> *icons = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *entries = [NSMutableArray array];
    // Rows in order: an icon button, or nil for a group separator (drawn as a divider).
    NSMutableArray *rows = [NSMutableArray array];
    self.overflowIconSize = 0;
    for (NSView *v in self.stack.arrangedSubviews) {
        if (!v.hidden) continue;
        if ([v isKindOfClass:[NSBox class]] || [v.identifier isEqualToString:@"space"]) {
            if (rows.count && [rows.lastObject isKindOfClass:[NSButton class]]) [rows addObject:[NSNull null]];
            continue;
        }
        NSMutableArray<NSControl *> *controls = [NSMutableArray array];
        if ([v isKindOfClass:[NSControl class]] && ((NSControl *)v).action) [controls addObject:(NSControl *)v];
        [self _collectControlsIn:v into:controls];
        for (NSControl *c in controls) {
            // A capsule's own label (its name and ▾) is a text button with an action; it is
            // not a tool, so it is left out of the popover.
            if ([c isKindOfClass:[NSButton class]] && !((NSButton *)c).image && ((NSButton *)c).title.length)
                continue;
            // Buttons drawn as text glyphs (+, ▾, ×) have no image: use a symbol for their action.
            // The popover icons match the row: take the size from the first real tool button.
            if (self.overflowIconSize < 1 && c.frame.size.width >= 16 && ![c.superview isKindOfClass:[NSStackView class]])
                self.overflowIconSize = round(c.frame.size.width);
            NSImage *image = [c isKindOfClass:[NSButton class]] ? ((NSButton *)c).image : nil;
            if (!image) image = [self _symbolImageForAction:c.action];
            NSButton *icon = [self _overflowIconWithImage:image
                                                  tooltip:(c.toolTip.length ? c.toolTip : c.accessibilityLabel)
                                                  enabled:c.enabled
                                                   sender:c target:c.target action:c.action entries:entries];
            [icons addObject:icon];
            [rows addObject:icon];
        }
        // A capsule's own ▾ menu holds more tools (its Overflow buttons): list them too,
        // as icons, so every tool the capsule offers is reachable from here.
        if ([v conformsToProtocol:@protocol(NppToolbarOverflowMenuProviding)]) {
            for (NSMenuItem *mi in [(id<NppToolbarOverflowMenuProviding>)v npp_overflowMenu].itemArray) {
                if (mi.isSeparatorItem || !mi.action) continue;
                NSButton *icon = [self _overflowIconWithImage:mi.image
                                                      tooltip:mi.title
                                                      enabled:mi.enabled
                                                       sender:mi target:mi.target action:mi.action entries:entries];
                [icons addObject:icon];
                [rows addObject:icon];
            }
        }
    }
    if (icons.count == 0) return;
    // A trailing separator has nothing after it; drop it.
    if ([rows.lastObject isKindOfClass:[NSNull class]]) [rows removeLastObject];
    self.overflowEntries = entries;

    // Icons in rows of up to six, in a vertical stack.
    NSStackView *column = [[NSStackView alloc] init];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeLeading;
    column.spacing = 4;
    column.edgeInsets = NSEdgeInsetsMake(8, 8, 8, 8);
    // One icon per row: a vertical list, with a divider between groups.
    for (id row in rows) {
        if ([row isKindOfClass:[NSButton class]]) {
            NSButton *icon = row;
            [icon.widthAnchor constraintEqualToConstant:(self.overflowIconSize > 0 ? self.overflowIconSize : NppOverflowButtonSize())].active = YES;
            [icon.heightAnchor constraintEqualToConstant:(self.overflowIconSize > 0 ? self.overflowIconSize : NppOverflowButtonSize())].active = YES;
            [column addArrangedSubview:icon];
        } else {
            // A 1-point rule centred in a short row, so the group break is visible.
            NSView *divider = [[NSView alloc] init];
            divider.translatesAutoresizingMaskIntoConstraints = NO;
            divider.wantsLayer = YES;
            NSView *rule = [[NSView alloc] init];
            rule.translatesAutoresizingMaskIntoConstraints = NO;
            rule.wantsLayer = YES;
            rule.layer.backgroundColor = [NSColor separatorColor].CGColor;
            [divider addSubview:rule];
            [NSLayoutConstraint activateConstraints:@[
                [divider.widthAnchor constraintEqualToConstant:(self.overflowIconSize > 0 ? self.overflowIconSize : NppOverflowButtonSize())],
                [divider.heightAnchor constraintEqualToConstant:9],
                [rule.leadingAnchor constraintEqualToAnchor:divider.leadingAnchor constant:3],
                [rule.trailingAnchor constraintEqualToAnchor:divider.trailingAnchor constant:-3],
                [rule.centerYAnchor constraintEqualToAnchor:divider.centerYAnchor],
                [rule.heightAnchor constraintEqualToConstant:1],
            ]];
            [column addArrangedSubview:divider];
        }
    }

    NSViewController *vc = [[NSViewController alloc] init];
    vc.view = column;
    NSPopover *popover = [[NSPopover alloc] init];
    popover.behavior = NSPopoverBehaviorTransient;
    popover.contentViewController = vc;
    self.overflowPopover = popover;
    [popover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSRectEdgeMinY];
}

// One popover icon. The entry remembers the original control (or menu item), so the action
// is sent from it: handlers such as the plugin buttons read the sender's tag.
- (NSButton *)_overflowIconWithImage:(NSImage *)image
                             tooltip:(NSString *)tooltip
                             enabled:(BOOL)enabled
                              sender:(id)original
                              target:(id)target
                              action:(SEL)action
                             entries:(NSMutableArray<NSDictionary *> *)entries {
    NSButton *icon = [NSButton buttonWithImage:(image ?: [NSImage imageNamed:NSImageNameActionTemplate])
                                        target:self
                                        action:@selector(_overflowIconClicked:)];
    icon.bordered = NO;
    // Same icon size for every entry, whatever the source image size.
    icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    icon.toolTip = tooltip;
    icon.enabled = enabled;
    icon.tag = (NSInteger)entries.count;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [entries addObject:@{ @"sender": original ?: [NSNull null],
                          @"target": target ?: [NSNull null],
                          @"action": NSStringFromSelector(action) }];
    return icon;
}

// Runs the original control's action: close the popover first, then send it on.
- (void)_overflowIconClicked:(NSButton *)icon {
    NSDictionary *entry = self.overflowEntries[(NSUInteger)icon.tag];
    id target = [entry[@"target"] isKindOfClass:[NSNull class]] ? nil : entry[@"target"];
    SEL action = NSSelectorFromString(entry[@"action"]);
    [self.overflowPopover performClose:nil];
    id original = [entry[@"sender"] isKindOfClass:[NSNull class]] ? icon : entry[@"sender"];
    [NSApp sendAction:action to:target from:original];
}

@end
