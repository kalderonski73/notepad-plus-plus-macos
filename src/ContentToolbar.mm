#import "ContentToolbar.h"

static const CGFloat kContentToolbarHeight = 34.0;
static const CGFloat kOverflowButtonWidth  = 22.0;

@interface NppContentToolbar ()
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSStackView *stack;
@property (nonatomic, strong) NSButton *overflowButton;
@property (nonatomic, strong) NSLayoutConstraint *scrollToOverflow;   // used while » is shown
@property (nonatomic, strong) NSLayoutConstraint *scrollToEdge;       // used while » is hidden
@property (nonatomic, strong) NSMutableArray<NSNumber *> *widths;     // natural width per item view
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
        _scrollToEdge = [_scrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor];
        _scrollToEdge.active = YES;

        [NSLayoutConstraint activateConstraints:@[
            [_scrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_scrollView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_scrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [_overflowButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
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
    return self.stack.arrangedSubviews;
}

- (void)setToolbarItems:(NSArray<NSToolbarItem *> *)items {
    for (NSView *v in [self.stack.arrangedSubviews copy]) {
        [self.stack removeArrangedSubview:v];
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
        NSSize fit = view.fittingSize;
        if (fit.width < 1) fit.width = view.frame.size.width;
        if (fit.height < 1) fit.height = kContentToolbarHeight - 8;
        CGFloat width = ceil(fit.width);
        [view.widthAnchor constraintEqualToConstant:width].active = YES;
        [view.heightAnchor constraintEqualToConstant:ceil(fit.height)].active = YES;
        [view setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                        forOrientation:NSLayoutConstraintOrientationHorizontal];
        [view setContentHuggingPriority:NSLayoutPriorityRequired
                         forOrientation:NSLayoutConstraintOrientationHorizontal];
        [self.stack addArrangedSubview:view];
        [self.widths addObject:@(width)];
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
    // Everything fits in the full width: no » button.
    NSUInteger cut = [self _firstHiddenIndexFittingWidth:self.bounds.size.width];
    BOOL overflow = cut < count;
    if (overflow) {
        // » takes space at the right edge; fit the rest into what remains.
        cut = [self _firstHiddenIndexFittingWidth:self.bounds.size.width - kOverflowButtonWidth];
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

- (void)_overflowClicked:(NSButton *)sender {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    for (NSView *v in self.stack.arrangedSubviews) {
        if (!v.hidden) continue;
        NSMutableArray<NSControl *> *controls = [NSMutableArray array];
        if ([v isKindOfClass:[NSControl class]] && ((NSControl *)v).action) [controls addObject:(NSControl *)v];
        [self _collectControlsIn:v into:controls];
        for (NSControl *c in controls) {
            NSString *title = c.toolTip.length ? c.toolTip : (c.accessibilityLabel ?: @"");
            NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:title action:c.action keyEquivalent:@""];
            mi.target = c.target;
            if ([c isKindOfClass:[NSButton class]]) mi.image = ((NSButton *)c).image;
            mi.enabled = c.enabled;
            [menu addItem:mi];
        }
    }
    if (menu.numberOfItems == 0) return;
    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, -2) inView:sender];
}

@end
