#import "ContentToolbar.h"

static const CGFloat kContentToolbarHeight = 34.0;

@interface NppContentToolbar ()
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSStackView *stack;
@end

@implementation NppContentToolbar

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _stack = [[NSStackView alloc] init];
        _stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        _stack.spacing = 1;
        _stack.alignment = NSLayoutAttributeCenterY;
        _stack.edgeInsets = NSEdgeInsetsMake(2, 4, 2, 4);
        _stack.translatesAutoresizingMaskIntoConstraints = NO;

        // Horizontal scrolling keeps every button reachable when the window is narrow.
        _scrollView = [[NSScrollView alloc] init];
        _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
        _scrollView.hasHorizontalScroller = YES;
        _scrollView.hasVerticalScroller = NO;
        _scrollView.drawsBackground = NO;
        _scrollView.borderType = NSNoBorder;
        _scrollView.documentView = _stack;
        [self addSubview:_scrollView];

        [NSLayoutConstraint activateConstraints:@[
            [_scrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_scrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_scrollView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_scrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
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

- (void)setToolbarItems:(NSArray<NSToolbarItem *> *)items {
    for (NSView *v in [self.stack.arrangedSubviews copy]) {
        [self.stack removeArrangedSubview:v];
        [v removeFromSuperview];
    }

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
        // Each item keeps its natural size; the stack never squeezes it. Overflow scrolls.
        view.translatesAutoresizingMaskIntoConstraints = NO;
        NSSize fit = view.fittingSize;
        if (fit.width < 1) fit.width = view.frame.size.width;
        if (fit.height < 1) fit.height = kContentToolbarHeight - 8;
        [view.widthAnchor constraintEqualToConstant:ceil(fit.width)].active = YES;
        [view.heightAnchor constraintEqualToConstant:ceil(fit.height)].active = YES;
        [view setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                        forOrientation:NSLayoutConstraintOrientationHorizontal];
        [view setContentHuggingPriority:NSLayoutPriorityRequired
                         forOrientation:NSLayoutConstraintOrientationHorizontal];
        [self.stack addArrangedSubview:view];
    }
}

@end
