#import <Cocoa/Cocoa.h>

// Tags assigned to top-level menu-bar items at build time, so callers can
// look them up via [[NSApp mainMenu] itemWithTag:] without depending on
// the English title (which gets translated to the active UI language and
// breaks any "isEqualToString:@\"Language\"" / @"Plugins" / @"Macro" /
// @"Run" lookup). The 9900/9902 values were already used inline before we
// centralized them; keeping them avoids reshuffling existing references.
extern const NSInteger kMenuTagMacro;
extern const NSInteger kMenuTagRun;
extern const NSInteger kMenuTagLanguage;
extern const NSInteger kMenuTagPlugins;

/// Builds the application's main menu bar programmatically.
@interface MenuBuilder : NSObject
+ (void)buildMainMenu;

/// Insert dynamically-loaded plugin menu items into the Plugins menu.
/// Items are placed before the separator that precedes "Plugins Admin…".
+ (void)insertPluginMenuItems:(NSArray<NSMenuItem *> *)items;
@end
