//
//  ToolbarLayout.h
//  NP++ (macOS) — the single toolbar layout model
//
//  One layout drives BOTH toolbar profiles (Classic and Tahoe). It is stored in
//  ~/Library/Application Support/NP++/toolbarLayout.xml and edited from
//  Preferences ▸ Toolbar (Classic) or Preferences ▸ Tahoe (Liquid Glass). This class
//  owns ONLY the data + file I/O; it knows nothing about AppKit or the editor UI.
//
//  The file is created on first use (see -load). The old Tahoe-only file
//  toolbarButtonsTahoeConf.xml is migrated once and kept as .bak.
//
//  Model shape — an ordered NSArray of group dictionaries:
//      @{ @"label":    NSString,                     // group name, unique
//         @"kind":     @"builtin" | @"plugins",
//         @"visible":  NSNumber (BOOL),              // NO hides the whole group
//         @"primary":  NSArray<NSString*>,           // shown on the group capsule
//         @"overflow": NSArray<NSString*>,           // behind the group's ▾ menu
//         @"hidden":   NSArray<NSString*> }           // not shown anywhere
//  For "builtin" groups the entries are toolbar button ids (TB_New, …). For the
//  "plugins" group they are plugin command NAMES (the registered tooltip), not the
//  per-session cmdID.
//
//  How each profile reads it:
//    Tahoe   — one capsule per visible group; primary on the capsule, overflow in
//              the ▾ menu, hidden not shown.
//    Classic — one flat row; visible groups in order, primary then overflow inline
//              (Classic has no ▾ menu), hidden not shown, a separator between groups.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Posted (by the Preferences editor) when the layout file changes, so the live
/// MainWindowController rebuilds its toolbar. No userInfo.
extern NSString *const NPPToolbarLayoutChanged;

@interface ToolbarLayout : NSObject

/// ~/Library/Application Support/NP++/toolbarLayout.xml
+ (NSString *)filePath;

/// Test hook: redirect the layout file to `path` (nil restores the real location).
+ (void)setFilePathOverrideForTesting:(nullable NSString *)path;

/// Parse the file into the model. If the file is missing, migrates the legacy Tahoe
/// file when present; otherwise returns nil and the caller materializes defaults.
+ (nullable NSArray<NSDictionary *> *)load;

/// Serialize the model to the file (with a commented schema header). YES on success.
+ (BOOL)saveModel:(NSArray<NSDictionary *> *)model;

/// Delete the file (Reset to Defaults — the host regenerates it on next build).
+ (void)removeFile;

// ── Catalog injected by MainWindowController at startup (single source of truth,
//    no duplication of the button tables). Used by the Preferences editor. ──

/// The default built-in groups, in dict form (kind=builtin). Empty until set.
+ (void)setDefaultBuiltinGroups:(NSArray<NSDictionary *> *)groups;
+ (NSArray<NSDictionary *> *)defaultBuiltinGroups;

/// Map of built-in button id → human display name (from toolbarDescriptors()).
+ (void)setButtonDisplayNames:(NSDictionary<NSString *, NSString *> *)names;
/// Display name for a built-in button id; falls back to the id minus "TB_".
+ (NSString *)displayNameForId:(NSString *)btnId;

@end

NS_ASSUME_NONNULL_END
