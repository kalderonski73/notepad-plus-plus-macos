#import <Cocoa/Cocoa.h>

/// A toolbar row drawn inside the main window's content area, instead of the system
/// NSToolbar in the title bar. It hosts the same item views the toolbar delegate builds,
/// so the buttons, groups and their actions stay as they are. Items that don't fit are
/// hidden behind a » button, which opens a menu of their controls.
/// A row item that has its own overflow menu (a Tahoe capsule's ▾ menu). The toolbar's overflow
/// popover lists those menu items, so every tool the item offers stays reachable.
@protocol NppToolbarOverflowMenuProviding <NSObject>
- (nullable NSMenu *)npp_overflowMenu;
@end

@interface NppContentToolbar : NSView

/// Replace the row's contents with `items`. Items with a custom view are placed as-is;
/// separators and flexible spaces become a divider and a spacer.
- (void)setToolbarItems:(NSArray<NSToolbarItem *> *)items;

/// Identifiers of items that stay at the right edge and are never moved behind the » button.
@property (nonatomic, copy, nullable) NSSet<NSString *> *pinnedItemIdentifiers;

/// The item views in row order (including any hidden behind »).
@property (nonatomic, readonly) NSArray<NSView *> *itemViews;

@end
