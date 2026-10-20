// ToolbarLayoutTests.mm
// XCTest checks for the shared toolbar layout model: save/load round-trip, the
// default visibility of groups, the one-time migration of the old Tahoe file, and
// reset. Built only with -DNPP_BUILD_TESTS=ON (see CMakeLists.txt). Every test runs
// against a temporary directory through +setFilePathOverrideForTesting:, so the
// user's real toolbarLayout.xml is never read or written.

#import <XCTest/XCTest.h>
#import "ToolbarLayout.h"

@interface ToolbarLayoutTests : XCTestCase
@property (nonatomic, copy) NSString *dir;
@end

@implementation ToolbarLayoutTests

- (void)setUp {
    [super setUp];
    NSString *name = [NSString stringWithFormat:@"npp-layout-tests-%@", [[NSUUID UUID] UUIDString]];
    self.dir = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    [[NSFileManager defaultManager] createDirectoryAtPath:self.dir
                              withIntermediateDirectories:YES attributes:nil error:nil];
    [ToolbarLayout setFilePathOverrideForTesting:[self.dir stringByAppendingPathComponent:@"toolbarLayout.xml"]];
}

- (void)tearDown {
    [ToolbarLayout setFilePathOverrideForTesting:nil];
    [[NSFileManager defaultManager] removeItemAtPath:self.dir error:nil];
    [super tearDown];
}

- (NSArray<NSDictionary *> *)sampleModel {
    return @[
        @{ @"label": @"File", @"kind": @"builtin", @"visible": @YES,
           @"primary": @[@"TB_New", @"TB_Open"], @"overflow": @[@"TB_SaveAll"], @"hidden": @[@"TB_Print"] },
        @{ @"label": @"Find", @"kind": @"builtin", @"visible": @NO,
           @"primary": @[@"TB_Find"], @"overflow": @[], @"hidden": @[] },
        @{ @"label": @"Plugins", @"kind": @"plugins", @"visible": @YES, @"customized": @YES,
           @"primary": @[@"Compare"], @"overflow": @[@"Clear Active Compare"], @"hidden": @[] },
    ];
}

- (void)testSaveThenLoadRoundTrips {
    XCTAssertTrue([ToolbarLayout saveModel:[self sampleModel]]);
    NSArray *loaded = [ToolbarLayout load];
    XCTAssertEqual(loaded.count, 3);

    NSDictionary *file = loaded[0];
    XCTAssertEqualObjects(file[@"label"], @"File");
    XCTAssertEqualObjects(file[@"primary"], (@[@"TB_New", @"TB_Open"]));
    XCTAssertEqualObjects(file[@"overflow"], @[@"TB_SaveAll"]);
    XCTAssertEqualObjects(file[@"hidden"], @[@"TB_Print"]);
    XCTAssertTrue([file[@"visible"] boolValue]);

    NSDictionary *find = loaded[1];
    XCTAssertFalse([find[@"visible"] boolValue], @"visible=\"no\" must survive a round-trip");

    NSDictionary *plugins = loaded[2];
    XCTAssertEqualObjects(plugins[@"kind"], @"plugins");
    XCTAssertTrue([plugins[@"customized"] boolValue]);
    XCTAssertEqualObjects(plugins[@"primary"], @[@"Compare"]);
}

- (void)testMissingVisibleAttributeMeansShown {
    NSString *xml = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                    @"<NotepadPlus><TahoeToolbar>"
                    @"<Group label=\"Zoom\" kind=\"builtin\"><Primary><Btn id=\"TB_ZoomIn\"></Btn></Primary>"
                    @"<Overflow></Overflow><Hidden></Hidden></Group>"
                    @"</TahoeToolbar></NotepadPlus>";
    NSString *path = [self.dir stringByAppendingPathComponent:@"toolbarLayout.xml"];
    [xml writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSArray *loaded = [ToolbarLayout load];
    XCTAssertEqual(loaded.count, 1);
    XCTAssertTrue([loaded[0][@"visible"] boolValue]);
    XCTAssertEqualObjects(loaded[0][@"primary"], @[@"TB_ZoomIn"]);
}

- (void)testLoadReturnsNilWhenNothingExists {
    XCTAssertNil([ToolbarLayout load]);
}

- (void)testLegacyTahoeFileIsMigratedOnce {
    NSString *legacyXML = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                          @"<NotepadPlus><TahoeToolbar>"
                          @"<Group label=\"Edit\" kind=\"builtin\"><Primary><Btn id=\"TB_Copy\"></Btn></Primary>"
                          @"<Overflow></Overflow><Hidden></Hidden></Group>"
                          @"</TahoeToolbar></NotepadPlus>";
    NSString *legacy = [self.dir stringByAppendingPathComponent:@"toolbarButtonsTahoeConf.xml"];
    [legacyXML writeToFile:legacy atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSArray *migrated = [ToolbarLayout load];
    XCTAssertEqual(migrated.count, 1);
    XCTAssertEqualObjects(migrated[0][@"primary"], @[@"TB_Copy"]);

    NSFileManager *fm = [NSFileManager defaultManager];
    XCTAssertTrue([fm fileExistsAtPath:[self.dir stringByAppendingPathComponent:@"toolbarLayout.xml"]]);
    XCTAssertFalse([fm fileExistsAtPath:legacy], @"the legacy file is moved aside");
    XCTAssertTrue([fm fileExistsAtPath:[legacy stringByAppendingString:@".bak"]]);

    // The second load reads the new file, not the legacy one.
    XCTAssertEqualObjects([ToolbarLayout load][0][@"primary"], @[@"TB_Copy"]);
}

- (void)testRemoveFileResetsToNothing {
    XCTAssertTrue([ToolbarLayout saveModel:[self sampleModel]]);
    [ToolbarLayout removeFile];
    XCTAssertNil([ToolbarLayout load]);
}

@end
