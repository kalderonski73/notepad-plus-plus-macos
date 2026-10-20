#import <Cocoa/Cocoa.h>

/// A menu bar drawn inside the main window, above the tabs. It shows one button per
/// document menu (File … ?) and pops up the same NSMenu the macOS menu bar would show.
/// The menus themselves stay in NSApp.mainMenu, so their actions and shortcuts are unchanged.
@interface NppInWindowMenuBar : NSView <NSMenuDelegate>

/// Decides whether a menu item is enabled. Set by the window controller, so the menus show
/// the same state as the editor's own menu validation. Nil leaves items as they are.
@property (nonatomic, copy, nullable) BOOL (^validator)(NSMenuItem *item);

/// Rebuild the buttons from the top-level items of NSApp.mainMenu that are hidden from the
/// macOS menu bar. Call again after the menus are translated to a new language.
- (void)rebuildFromMainMenu;

@end
