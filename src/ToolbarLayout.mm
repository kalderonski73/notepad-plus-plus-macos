//
//  ToolbarLayout.mm
//  NP++ (macOS) — the single toolbar layout model
//
//  See ToolbarLayout.h for the model and how each profile reads it.
//
#import "ToolbarLayout.h"
#import "NppPaths.h"

NSString *const NPPToolbarLayoutChanged = @"NPPToolbarLayoutChanged";

static NSString *const kLayoutFileName  = @"toolbarLayout.xml";
static NSString *const kLegacyFileName  = @"toolbarButtonsTahoeConf.xml";

static NSString *_layoutConfigDir(void) {
    return NppConfigDir();
}

// Test hook: when set, the layout file lives here (and its legacy sibling beside it),
// so tests never touch the user's real configuration.
static NSString *sFilePathOverride = nil;

static NSString *const kSchemaHeader =
    @" Toolbar Layout (NP++ macOS)\n"
    @"  ==========================\n"
    @"  This file is generated and managed by NP++. It is LIVE: edits take effect\n"
    @"  immediately. Edit it from Preferences ▸ Toolbar (Classic) or Preferences ▸\n"
    @"  Tahoe, or by hand here. Delete it to restore defaults.\n\n"
    @"  Each <Group> is one block of buttons. visible=\"no\" hides the whole group.\n"
    @"  Inside a group, <Primary> buttons show on the group, <Overflow> buttons sit\n"
    @"  behind the group's ▾ menu (Tahoe) or inline after the primary buttons\n"
    @"  (Classic), and <Hidden> buttons are not shown. Built-in buttons are\n"
    @"  referenced by id (<Btn id=...>), plugin buttons by command name (<Btn name=...>). ";

@implementation ToolbarLayout

static NSArray<NSDictionary *> *sDefaultBuiltinGroups = nil;
static NSDictionary<NSString *, NSString *> *sDisplayNames = nil;

+ (NSString *)filePath {
    if (sFilePathOverride) return sFilePathOverride;
    return [_layoutConfigDir() stringByAppendingPathComponent:kLayoutFileName];
}

+ (void)setFilePathOverrideForTesting:(NSString *)path {
    sFilePathOverride = [path copy];
}

#pragma mark - Catalog (injected by MainWindowController)

+ (void)setDefaultBuiltinGroups:(NSArray<NSDictionary *> *)groups {
    sDefaultBuiltinGroups = [groups copy];
}

+ (NSArray<NSDictionary *> *)defaultBuiltinGroups {
    return sDefaultBuiltinGroups ?: @[];
}

+ (void)setButtonDisplayNames:(NSDictionary<NSString *, NSString *> *)names {
    sDisplayNames = [names copy];
}

+ (NSString *)displayNameForId:(NSString *)btnId {
    NSString *n = sDisplayNames[btnId];
    if (n.length) return n;
    if ([btnId hasPrefix:@"TB_"]) return [btnId substringFromIndex:3];
    return btnId;
}

#pragma mark - Load

/// Parse an XML layout file at `path`. Returns nil if the file cannot be read.
+ (nullable NSArray<NSDictionary *> *)_parseFileAtPath:(NSString *)path {
    NSXMLDocument *doc = [[NSXMLDocument alloc]
        initWithContentsOfURL:[NSURL fileURLWithPath:path] options:0 error:nil];
    if (!doc) return nil;

    NSMutableArray<NSDictionary *> *model = [NSMutableArray array];
    NSArray *groupNodes = [doc nodesForXPath:@"//TahoeToolbar/Group" error:nil];
    for (NSXMLElement *gEl in groupNodes) {
        NSString *label = [gEl attributeForName:@"label"].stringValue;
        NSString *kind  = [gEl attributeForName:@"kind"].stringValue ?: @"builtin";
        if (!label.length) continue;
        BOOL isPlugins = [kind isEqualToString:@"plugins"];

        NSMutableDictionary *g = [NSMutableDictionary dictionary];
        g[@"label"] = label;
        g[@"kind"]  = isPlugins ? @"plugins" : @"builtin";
        // visible defaults to YES; only an explicit "no" hides the group.
        g[@"visible"] = @(![[gEl attributeForName:@"visible"].stringValue isEqualToString:@"no"]);
        // "customized" marks that the user has taken over this group's layout, so
        // the host stops re-applying its smart default (used for the Plugins group).
        if ([[gEl attributeForName:@"customized"].stringValue isEqualToString:@"yes"])
            g[@"customized"] = @YES;
        for (NSString *section in @[@"primary", @"overflow", @"hidden"]) {
            NSMutableArray<NSString *> *entries = [NSMutableArray array];
            NSString *cap = [section capitalizedString];   // Primary / Overflow / Hidden
            NSArray *btns = [gEl nodesForXPath:
                [NSString stringWithFormat:@"%@/Btn", cap] error:nil];
            for (NSXMLElement *bEl in btns) {
                NSString *attr = isPlugins ? @"name" : @"id";
                NSString *val  = [bEl attributeForName:attr].stringValue;
                if (val.length) [entries addObject:val];
            }
            g[section] = entries;
        }
        [model addObject:g];
    }
    return model.count ? model : nil;
}

+ (nullable NSArray<NSDictionary *> *)load {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [self filePath];

    if (![fm fileExistsAtPath:path]) {
        // One-time migration from the Tahoe-only file (same format, no visible flag).
        NSString *legacy = [[path stringByDeletingLastPathComponent]
            stringByAppendingPathComponent:kLegacyFileName];
        if (![fm fileExistsAtPath:legacy]) return nil;
        NSArray *migrated = [self _parseFileAtPath:legacy];
        if (!migrated) return nil;
        [self saveModel:migrated];
        [fm moveItemAtPath:legacy toPath:[legacy stringByAppendingString:@".bak"] error:nil];
        return migrated;
    }
    return [self _parseFileAtPath:path];
}

#pragma mark - Save

+ (BOOL)saveModel:(NSArray<NSDictionary *> *)model {
    NSXMLElement *root = [NSXMLElement elementWithName:@"NotepadPlus"];
    NSXMLElement *tb   = [NSXMLElement elementWithName:@"TahoeToolbar"];
    [root addChild:tb];

    for (NSDictionary *g in model) {
        NSString *label = g[@"label"];
        if (!label.length) continue;
        BOOL isPlugins = [g[@"kind"] isEqualToString:@"plugins"];

        NSXMLElement *gEl = [NSXMLElement elementWithName:@"Group"];
        [gEl addAttribute:[NSXMLNode attributeWithName:@"label" stringValue:label]];
        [gEl addAttribute:[NSXMLNode attributeWithName:@"kind"
                                           stringValue:(isPlugins ? @"plugins" : @"builtin")]];
        if (g[@"visible"] && ![g[@"visible"] boolValue])
            [gEl addAttribute:[NSXMLNode attributeWithName:@"visible" stringValue:@"no"]];
        if ([g[@"customized"] boolValue])
            [gEl addAttribute:[NSXMLNode attributeWithName:@"customized" stringValue:@"yes"]];
        for (NSString *section in @[@"primary", @"overflow", @"hidden"]) {
            NSXMLElement *sEl = [NSXMLElement elementWithName:[section capitalizedString]];
            for (NSString *entry in (NSArray *)(g[section] ?: @[])) {
                if (![entry isKindOfClass:[NSString class]] || !entry.length) continue;
                NSXMLElement *bEl = [NSXMLElement elementWithName:@"Btn"];
                [bEl addAttribute:[NSXMLNode attributeWithName:(isPlugins ? @"name" : @"id")
                                                   stringValue:entry]];
                [sEl addChild:bEl];
            }
            [gEl addChild:sEl];
        }
        [tb addChild:gEl];
    }

    NSXMLDocument *doc = [NSXMLDocument documentWithRootElement:root];
    doc.version = @"1.0";
    doc.characterEncoding = @"UTF-8";
    // Lead with the schema comment (insert before the root element).
    [doc insertChild:[NSXMLNode commentWithStringValue:kSchemaHeader] atIndex:0];
    NSData *data = [doc XMLDataWithOptions:NSXMLNodePrettyPrint];
    NSString *dir = [[self filePath] stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES attributes:nil error:nil];
    return [data writeToFile:[self filePath] atomically:YES];
}

+ (void)removeFile {
    [[NSFileManager defaultManager] removeItemAtPath:[self filePath] error:nil];
}

@end
