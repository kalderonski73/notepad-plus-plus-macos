#import <Cocoa/Cocoa.h>

/// A toolbar row drawn inside the main window's content area, instead of the system
/// NSToolbar in the title bar. It hosts the same item views the toolbar delegate builds,
/// so the buttons, groups and their actions stay as they are.
@interface NppContentToolbar : NSView

/// Replace the row's contents with `items`. Items with a custom view are placed as-is;
/// separators and flexible spaces become a divider and a spacer.
- (void)setToolbarItems:(NSArray<NSToolbarItem *> *)items;

@end
