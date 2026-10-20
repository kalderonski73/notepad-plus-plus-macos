#import "PanelFrame.h"
#import "NppThemeManager.h"

// ─────────────────────────────────────────────────────────────────────────────
// Close button — pixel-identical to the per-panel _DMPCloseButton /
// _FLPCloseButton / _DLPCloseButton / etc. Hoisted here so all panels share
// one implementation instead of 8 copies.
//
// Behavior:
//   * 1pt grey border at rest, toolbar-blue (#D0EAFF) on hover/press
//   * Light-blue background fill on hover (#E5F3FF) / press (#CCE8FF) in
//     LIGHT mode only — skipped in dark mode to avoid clashing with the
//     dark title-bar background
//   * ✕ glyph centered via NSAttributedString for true vertical alignment
// ─────────────────────────────────────────────────────────────────────────────

@interface _PFCloseButton : NSButton { BOOL _hovering; }
@end

@implementation _PFCloseButton

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.bordered = NO;
        self.buttonType = NSButtonTypeMomentaryChange;
        self.title = @"";
        NSTrackingArea *ta = [[NSTrackingArea alloc]
            initWithRect:NSZeroRect
                 options:(NSTrackingMouseEnteredAndExited |
                          NSTrackingActiveInActiveApp     |
                          NSTrackingInVisibleRect)
                   owner:self userInfo:nil];
        [self addTrackingArea:ta];
    }
    return self;
}

- (void)mouseEntered:(NSEvent *)event { _hovering = YES; [self setNeedsDisplay:YES]; }
- (void)mouseExited:(NSEvent *)event  { _hovering = NO;  [self setNeedsDisplay:YES]; }

- (void)drawRect:(NSRect)dirtyRect {
    BOOL pressed = self.isHighlighted;
    BOOL active  = pressed || _hovering;
    BOOL isDark  = [NppThemeManager shared].isDark;

    if (active && !isDark) {
        NSColor *bg = pressed
            ? [NSColor colorWithRed:0xCC/255.0 green:0xE8/255.0 blue:0xFF/255.0 alpha:1.0]
            : [NSColor colorWithRed:0xE5/255.0 green:0xF3/255.0 blue:0xFF/255.0 alpha:1.0];
        [bg setFill];
        NSRectFill(self.bounds);
    }

    NSColor *bdr = active
        ? [NSColor colorWithRed:0xD0/255.0 green:0xEA/255.0 blue:0xFF/255.0 alpha:1.0]
        : [NSColor colorWithWhite:0.75 alpha:1.0];
    NSBezierPath *border = [NSBezierPath bezierPathWithRect:NSInsetRect(self.bounds, 0.5, 0.5)];
    border.lineWidth = 1.0;
    [bdr setStroke];
    [border stroke];

    NSString *glyph = @"✕";
    NSDictionary *attrs = @{
        NSFontAttributeName: self.font ?: [NSFont systemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor labelColor],
    };
    NSSize sz = [glyph sizeWithAttributes:attrs];
    NSPoint origin = NSMakePoint(NSMidX(self.bounds) - sz.width / 2.0,
                                 NSMidY(self.bounds) - sz.height / 2.0);
    [glyph drawAtPoint:origin withAttributes:attrs];
}

@end

// ─────────────────────────────────────────────────────────────────────────────
// Pop-out / dock-back button — chrome style matches the in-panel toolbar
// buttons (e.g. _FTPanelButton in FolderTreePanel.mm): NO border at rest,
// toolbar-blue fill + border on hover/press, no fill in dark mode. Icon
// is loaded from the standard/dark theme subdirectory so it auto-adapts
// to light vs dark appearance. The same instance swaps its icon based
// on `popped`:
//   * docked  → pop_out.png   (send to floating window)
//   * popped  → pop_in.png    (dock back to side pane)
// ─────────────────────────────────────────────────────────────────────────────

static const CGFloat kPFToolbarIconSize = 13;  // rendered size inside 16×16 pop button

static NSString *_PFIconSubdir(void) {
    return [NppThemeManager shared].isDark
        ? @"icons/dark/panels/toolbar"
        : @"icons/standard/panels/toolbar";
}

static NSImage *_PFLoadIcon(NSString *name) {
    NSURL *url = [[NSBundle mainBundle] URLForResource:name withExtension:@"png"
                                          subdirectory:_PFIconSubdir()];
    NSImage *img = url ? [[NSImage alloc] initWithContentsOfURL:url] : nil;
    if (img) img.size = NSMakeSize(kPFToolbarIconSize, kPFToolbarIconSize);
    return img;
}

@interface _PFPopButton : NSButton {
    BOOL _hovering;
}
@property (nonatomic) BOOL popped;
- (void)reloadIcon;
/// Force the internal hover state back to NO. NSTrackingArea only fires
/// mouseExited: on actual cursor-leaves-bounds transitions — it does NOT
/// fire when the view becomes hidden while the cursor is still over it.
/// That's exactly the case when the user clicks Detach: the button hides
/// under the still-stationary cursor and mouseExited never gets called,
/// so _hovering stays YES and the hover border persists when the chrome
/// re-expands on dock-back. Call this from PanelFrame.setPopped: to break
/// that sticky state on every transition.
- (void)clearHoverState;
@end

@implementation _PFPopButton

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.bordered = NO;
        self.buttonType = NSButtonTypeMomentaryChange;
        self.title = @"";
        NSTrackingArea *ta = [[NSTrackingArea alloc]
            initWithRect:NSZeroRect
                 options:(NSTrackingMouseEnteredAndExited |
                          NSTrackingActiveInActiveApp     |
                          NSTrackingInVisibleRect)
                   owner:self userInfo:nil];
        [self addTrackingArea:ta];
    }
    return self;
}

- (void)mouseEntered:(NSEvent *)event { _hovering = YES; [self setNeedsDisplay:YES]; }
- (void)mouseExited:(NSEvent *)event  { _hovering = NO;  [self setNeedsDisplay:YES]; }

- (void)setPopped:(BOOL)popped {
    if (_popped == popped) return;
    _popped = popped;
    self.toolTip = popped ? @"Dock back" : @"Detach";
    [self setNeedsDisplay:YES];
}

- (void)reloadIcon {
    [self setNeedsDisplay:YES];
}

- (void)clearHoverState {
    if (!_hovering) return;
    _hovering = NO;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    BOOL pressed = self.isHighlighted;
    BOOL active  = pressed || _hovering;
    BOOL isDark  = [NppThemeManager shared].isDark;

    // Hover/press chrome only — no border at rest, matching the in-panel
    // toolbar buttons (_FTPanelButton et al.).
    if (active) {
        if (!isDark) {
            NSColor *bg = pressed
                ? [NSColor colorWithRed:0xCC/255.0 green:0xE8/255.0 blue:0xFF/255.0 alpha:1.0]
                : [NSColor colorWithRed:0xE5/255.0 green:0xF3/255.0 blue:0xFF/255.0 alpha:1.0];
            [bg setFill];
            NSRectFill(self.bounds);
        }
        NSColor *bdr = [NSColor colorWithRed:0xD0/255.0 green:0xEA/255.0 blue:0xFF/255.0 alpha:1.0];
        NSBezierPath *border = [NSBezierPath bezierPathWithRect:NSInsetRect(self.bounds, 0.5, 0.5)];
        border.lineWidth = 1.0;
        [bdr setStroke];
        [border stroke];
    }

    NSImage *icon = _PFLoadIcon(_popped ? @"pop_in" : @"pop_out");
    if (!icon) return;  // icon missing — leave just the hover chrome

    NSSize isz = icon.size;
    NSRect target = NSMakeRect(NSMidX(self.bounds) - isz.width / 2.0,
                               NSMidY(self.bounds) - isz.height / 2.0,
                               isz.width, isz.height);
    [icon drawInRect:target
            fromRect:NSZeroRect
           operation:NSCompositingOperationSourceOver
            fraction:1.0
      respectFlipped:YES
               hints:nil];
}

@end

// ─────────────────────────────────────────────────────────────────────────────
// PanelFrame
// ─────────────────────────────────────────────────────────────────────────────

@implementation PanelFrame {
    NSView        *_titleBar;
    NSTextField   *_titleLabel;
    _PFPopButton  *_popButton;
    _PFCloseButton *_closeButton;
    NSBox         *_separator;
    // Tahoe-only (gated on usesGlassMaterials): a glass material backing behind
    // the title-bar content. nil under Classic, so the Classic header (an opaque
    // tabBarBackground layer) is byte-for-byte unchanged.
    NSVisualEffectView *_headerVFX;
    CGFloat        _headerH;       // title-bar height: 24 Classic / 28 Tahoe (sleeker)
    NSView        *_contentView;  // strong — we own the view we wrap
    // Collapsible chrome: when `popped`, both of these flip to 0 so the
    // content view takes over the full frame and there's no "double title
    // bar" under the FloatingPanelWindow's native chrome.
    NSLayoutConstraint *_titleBarHeight;
    NSLayoutConstraint *_separatorHeight;
}

@synthesize contentView = _contentView;

- (instancetype)initWithContentView:(NSView *)content title:(NSString *)title {
    NSParameterAssert(content != nil);
    self = [super initWithFrame:NSZeroRect];
    if (!self) return nil;

    _contentView = content;
    [self _buildLayout];
    self.title = title ?: @"";
    [self _applyThemeColors];

    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(_darkModeChanged:)
               name:NPPDarkModeChangedNotification object:nil];

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)_buildLayout {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    // 24pt header / 11pt title / 6pt leading for both profiles. Tahoe keeps the
    // glass header material + white body (applied in _applyThemeColors) but matches
    // Classic's compact metrics.
    _headerH = 24.0;

    // Title bar
    _titleBar = [[NSView alloc] init];
    _titleBar.translatesAutoresizingMaskIntoConstraints = NO;
    _titleBar.wantsLayer = YES;
    [self addSubview:_titleBar];

    _titleLabel = [NSTextField labelWithString:@""];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [NSFont systemFontOfSize:11.0];
    _titleLabel.textColor = [NSColor labelColor];
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_titleBar addSubview:_titleLabel];

    _popButton = [[_PFPopButton alloc] initWithFrame:NSZeroRect];
    _popButton.translatesAutoresizingMaskIntoConstraints = NO;
    _popButton.target = self;
    _popButton.action = @selector(_popClicked:);
    _popButton.font = [NSFont systemFontOfSize:11];
    _popButton.toolTip = @"Detach";
    [_titleBar addSubview:_popButton];

    _closeButton = [[_PFCloseButton alloc] initWithFrame:NSZeroRect];
    _closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    _closeButton.target = self;
    _closeButton.action = @selector(_closeClicked:);
    _closeButton.font = [NSFont systemFontOfSize:11];
    _closeButton.toolTip = @"Close panel";
    [_titleBar addSubview:_closeButton];

    // Separator
    _separator = [[NSBox alloc] init];
    _separator.boxType = NSBoxSeparator;
    _separator.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_separator];

    // Content
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_contentView];

    _titleBarHeight  = [_titleBar.heightAnchor  constraintEqualToConstant:_headerH];
    _separatorHeight = [_separator.heightAnchor constraintEqualToConstant:1];

    [NSLayoutConstraint activateConstraints:@[
        // Title bar (24pt — shrinks to 0 when popped)
        [_titleBar.topAnchor       constraintEqualToAnchor:self.topAnchor],
        [_titleBar.leadingAnchor   constraintEqualToAnchor:self.leadingAnchor],
        [_titleBar.trailingAnchor  constraintEqualToAnchor:self.trailingAnchor],
        _titleBarHeight,

        [_titleLabel.leadingAnchor  constraintEqualToAnchor:_titleBar.leadingAnchor constant:6.0],
        [_titleLabel.centerYAnchor  constraintEqualToAnchor:_titleBar.centerYAnchor],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_popButton.leadingAnchor constant:-4],

        // Pop button — 16×16 (20% larger than the 13pt close X).
        [_popButton.trailingAnchor   constraintEqualToAnchor:_closeButton.leadingAnchor constant:-4],
        [_popButton.centerYAnchor    constraintEqualToAnchor:_titleBar.centerYAnchor],
        [_popButton.widthAnchor      constraintEqualToConstant:16],
        [_popButton.heightAnchor     constraintEqualToConstant:16],

        // Close X — 13×13.
        [_closeButton.trailingAnchor constraintEqualToAnchor:_titleBar.trailingAnchor constant:-4],
        [_closeButton.centerYAnchor  constraintEqualToAnchor:_titleBar.centerYAnchor],
        [_closeButton.widthAnchor    constraintEqualToConstant:13],
        [_closeButton.heightAnchor   constraintEqualToConstant:13],

        // Separator (1pt — collapses to 0 when popped)
        [_separator.topAnchor      constraintEqualToAnchor:_titleBar.bottomAnchor],
        [_separator.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_separator.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        _separatorHeight,

        // Content view fills the rest — flush to edges, no inset.
        [_contentView.topAnchor      constraintEqualToAnchor:_separator.bottomAnchor],
        [_contentView.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_contentView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_contentView.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],
    ]];

    // Tahoe: a Liquid-Glass material behind the header, inserted BELOW the
    // existing title-bar content (label + buttons render on top). Gated on
    // usesGlassMaterials, so it's never created under Classic and the Classic
    // header (an opaque tabBarBackground layer) stays byte-for-byte unchanged.
    if ([NppThemeManager shared].usesGlassMaterials) {
        _headerVFX = [[NSVisualEffectView alloc] init];
        _headerVFX.translatesAutoresizingMaskIntoConstraints = NO;
        _headerVFX.material     = [[NppThemeManager shared] materialForRole:NppMaterialRolePanelHeader];
        _headerVFX.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        _headerVFX.state        = NSVisualEffectStateActive;
        [_titleBar addSubview:_headerVFX positioned:NSWindowBelow relativeTo:nil];
        [NSLayoutConstraint activateConstraints:@[
            [_headerVFX.topAnchor      constraintEqualToAnchor:_titleBar.topAnchor],
            [_headerVFX.leadingAnchor  constraintEqualToAnchor:_titleBar.leadingAnchor],
            [_headerVFX.trailingAnchor constraintEqualToAnchor:_titleBar.trailingAnchor],
            [_headerVFX.bottomAnchor   constraintEqualToAnchor:_titleBar.bottomAnchor],
        ]];
    }
}

- (void)_closeClicked:(id)sender {
    id<PanelFrameDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(panelFrameRequestedClose:)])
        [d panelFrameRequestedClose:self];
}

- (void)_popClicked:(id)sender {
    id<PanelFrameDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(panelFrameRequestedTogglePop:)])
        [d panelFrameRequestedTogglePop:self];
}

- (void)simulateCloseClick { [self _closeClicked:nil]; }

// ── Popped-state binding ──────────────────────────────────────────────────
//
// When popped, the FloatingPanelWindow's NATIVE title bar provides title +
// close X; rendering our own title bar on top of that produced a
// double-header stack. Collapse the chrome entirely when popped — content
// view takes over the full frame. The dock-back button is moved into the
// window's native title bar as an NSTitlebarAccessoryViewController by
// FloatingPanelWindow, so the user still has one-click dock-back.

- (BOOL)isPopped { return _popButton.popped; }

- (void)setPopped:(BOOL)popped {
    if (_popButton.popped == popped) return;
    _popButton.popped = popped;

    // Hiding the button under a stationary cursor leaves NSTrackingArea
    // with no mouseExited: to fire. Reset proactively so the border
    // doesn't re-appear as "hovered" when the chrome expands again.
    [_popButton clearHoverState];

    if (popped) {
        _titleBarHeight.constant = 0;
        _separatorHeight.constant = 0;
        _titleBar.hidden  = YES;
        _separator.hidden = YES;
    } else {
        _titleBarHeight.constant = _headerH;
        _separatorHeight.constant = 1;
        _titleBar.hidden  = NO;
        _separator.hidden = NO;
    }
    [self needsUpdateConstraints];
    [self layoutSubtreeIfNeeded];
}

// ── Title binding ─────────────────────────────────────────────────────────

- (NSString *)title { return _titleLabel.stringValue ?: @""; }

- (void)setTitle:(NSString *)title {
    _titleLabel.stringValue = title ?: @"";
}

// ── Theme ─────────────────────────────────────────────────────────────────

- (void)_applyThemeColors {
    if ([NppThemeManager shared].usesGlassMaterials) {
        // Tahoe: the glass _headerVFX provides the header background, so keep the
        // title-bar layer clear and let the material show through.
        _titleBar.layer.backgroundColor = NSColor.clearColor.CGColor;
        _headerVFX.material = [[NppThemeManager shared] materialForRole:NppMaterialRolePanelHeader];
        // Opaque white body so each panel's content — including its transparent
        // action/search row — reads as white, not the window gradient. The header
        // VFX renders on top; the rounded side-panel host clips this.
        self.wantsLayer = YES;
        self.layer.backgroundColor = [NppThemeManager shared].panelBackground.CGColor;
    } else {
        _titleBar.layer.backgroundColor = [NppThemeManager shared].tabBarBackground.CGColor;
    }
}

- (void)_darkModeChanged:(NSNotification *)n {
    [self _applyThemeColors];
    // Pop-out/in PNGs live in a theme-keyed subdirectory; refresh so the
    // correct variant paints after a light/dark flip.
    [_popButton reloadIcon];
}

@end
