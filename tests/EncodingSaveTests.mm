// EncodingSaveTests.mm
// XCTest checks for file loading, encoding round-trips and save state in EditorView.
// Built only when configuring with -DNPP_BUILD_TESTS=ON (see CMakeLists.txt).

#import <XCTest/XCTest.h>
#import "EditorView.h"
#import "NppApplication.h"
#import "Scintilla.h"

@interface EncodingSaveTests : XCTestCase
@property (nonatomic, copy) NSString *tempDir;
@property (nonatomic, strong) NSMutableArray<NSWindow *> *windows;
@end

@implementation EncodingSaveTests

- (void)setUp {
    [super setUp];
    // EditorView reads app-level state (appearance, theme) that needs NSApp to exist.
    [NppApplication sharedApplication];
    NSString *name = [NSString stringWithFormat:@"npp-tests-%@", [[NSUUID UUID] UUIDString]];
    self.tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    [[NSFileManager defaultManager] createDirectoryAtPath:self.tempDir
                              withIntermediateDirectories:YES attributes:nil error:nil];
    self.windows = [NSMutableArray array];
}

- (void)tearDown {
    [EditorView setLossySaveConfirmationHandlerForTesting:nil];
    [[NSFileManager defaultManager] removeItemAtPath:self.tempDir error:nil];
    [super tearDown];
}

- (NSString *)pathNamed:(NSString *)name {
    return [self.tempDir stringByAppendingPathComponent:name];
}

- (EditorView *)openBytes:(NSData *)bytes named:(NSString *)name {
    NSString *path = [self pathNamed:name];
    XCTAssertTrue([bytes writeToFile:path atomically:NO], @"fixture write failed");
    // Host the editor in an off-screen window: Scintilla only reports edits and
    // applies themes once its view is attached to a window.
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 300)
                                                   styleMask:NSWindowStyleMaskBorderless
                                                     backing:NSBackingStoreBuffered defer:NO];
    EditorView *ed = [[EditorView alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)];
    window.contentView = ed;
    window.alphaValue = 0.0;
    [window orderFrontRegardless];
    [self.windows addObject:window];
    NSError *err = nil;
    XCTAssertTrue([ed loadFileAtPath:path error:&err], @"load failed: %@", err);
    return ed;
}

/// Load `bytes`, save the editor to a second path, and return what landed on disk.
- (NSData *)roundTrip:(NSData *)bytes name:(NSString *)name {
    EditorView *ed = [self openBytes:bytes named:name];
    XCTAssertFalse(ed.isModified, @"a freshly loaded file must not be modified");
    NSString *target = [self pathNamed:[@"out-" stringByAppendingString:name]];
    NSError *err = nil;
    XCTAssertTrue([ed saveToPath:target error:&err], @"save failed: %@", err);
    XCTAssertFalse(ed.isModified, @"a successful save must clear the modified state");
    return [NSData dataWithContentsOfFile:target];
}

- (NSData *)utf16LEBytes:(NSString *)s {
    return [s dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
}

- (NSData *)utf16BEBytes:(NSString *)s {
    return [s dataUsingEncoding:NSUTF16BigEndianStringEncoding];
}

- (void)testUTF8WithBOMRoundTripsBytes {
    NSMutableData *input = [NSMutableData dataWithBytes:"\xEF\xBB\xBF" length:3];
    [input appendData:[@"héllo\n" dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertEqualObjects([self roundTrip:input name:@"utf8-bom.txt"], input);
}

- (void)testUTF8WithoutBOMRoundTripsBytes {
    NSData *input = [@"héllo λ\n" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects([self roundTrip:input name:@"utf8.txt"], input);
}

- (void)testUTF16LittleEndianWithBOMRoundTripsBytes {
    NSMutableData *input = [NSMutableData dataWithBytes:"\xFF\xFE" length:2];
    [input appendData:[self utf16LEBytes:@"hello\n"]];
    XCTAssertEqualObjects([self roundTrip:input name:@"utf16le.txt"], input);
}

- (void)testUTF16BigEndianWithBOMRoundTripsBytes {
    NSMutableData *input = [NSMutableData dataWithBytes:"\xFE\xFF" length:2];
    [input appendData:[self utf16BEBytes:@"hello\n"]];
    XCTAssertEqualObjects([self roundTrip:input name:@"utf16be.txt"], input);
}

- (void)testEmptyFileRoundTripsBytes {
    NSData *input = [NSData data];
    XCTAssertEqualObjects([self roundTrip:input name:@"empty.md"], input);
}

- (void)testNonEmptyMarkdownLoadsText {
    NSData *input = [@"# Título\n" dataUsingEncoding:NSUTF8StringEncoding];
    EditorView *ed = [self openBytes:input named:@"load-check.md"];
    XCTAssertGreaterThan(ed.scintillaView.string.length, 0u, @"markdown must load non-empty text");
}

- (void)testEditMarksModifiedAndSaveClearsIt {
    NSData *input = [@"one\n" dataUsingEncoding:NSUTF8StringEncoding];
    EditorView *ed = [self openBytes:input named:@"save-state.txt"];
    [ed.scintillaView message:SCI_INSERTTEXT wParam:0 lParam:(sptr_t)"two\n"];
    XCTAssertTrue(ed.isModified, @"an edit must mark the document modified");
    NSError *err = nil;
    XCTAssertTrue([ed saveError:&err], @"save of an existing path must succeed: %@", err);
    XCTAssertFalse(ed.isModified, @"save must reset the modified state");
    NSData *onDisk = [NSData dataWithContentsOfFile:[self pathNamed:@"save-state.txt"]];
    NSData *expected = [@"two\none\n" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(onDisk, expected, @"save must write the edited text");
}

- (void)testFailedSaveKeepsPathAndModifiedState {
    NSData *input = [@"one\n" dataUsingEncoding:NSUTF8StringEncoding];
    EditorView *ed = [self openBytes:input named:@"failing.txt"];
    NSString *originalPath = ed.filePath;
    [ed.scintillaView message:SCI_INSERTTEXT wParam:0 lParam:(sptr_t)"unsaved\n"];
    NSString *unreachable = [self pathNamed:@"missing-directory/out.txt"];
    NSError *err = nil;
    XCTAssertFalse([ed saveToPath:unreachable error:&err], @"save into a missing directory must fail");
    XCTAssertNotNil(err, @"a failed save must report an error");
    XCTAssertEqualObjects(ed.filePath, originalPath, @"a failed Save As must keep the old path");
    XCTAssertTrue(ed.isModified, @"a failed save must leave the document modified");
}

- (void)testLossySaveDeclinedWritesNothingAndKeepsState {
    NSData *input = [@"abc\n" dataUsingEncoding:NSUTF8StringEncoding];
    EditorView *ed = [self openBytes:input named:@"lossy-declined.txt"];
    [ed.scintillaView message:SCI_INSERTTEXT wParam:0 lParam:(sptr_t)"\xE2\x9C\x93"]; // U+2713, not in Windows-1252
    [ed setFileEncoding:NSWindowsCP1252StringEncoding hasBOM:NO];
    __block NSString *askedEncoding = nil;
    [EditorView setLossySaveConfirmationHandlerForTesting:^BOOL(NSString *encodingName) {
        askedEncoding = encodingName;
        return NO;
    }];
    NSString *target = [self pathNamed:@"out-lossy-declined.txt"];
    NSError *err = nil;
    XCTAssertFalse([ed saveToPath:target error:&err], @"declined lossy save must not succeed");
    XCTAssertTrue([EditorView isUserCancelledSave:err], @"declining must report a user cancellation");
    XCTAssertGreaterThan(askedEncoding.length, 0u, @"the user must be asked, naming the encoding");
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:target], @"declined save must not create the file");
    XCTAssertTrue(ed.isModified, @"declined save must leave the document modified");
}

- (void)testLossySaveConfirmedReplacesUnrepresentableCharacters {
    NSData *input = [@"abc\n" dataUsingEncoding:NSUTF8StringEncoding];
    EditorView *ed = [self openBytes:input named:@"lossy-confirmed.txt"];
    [ed.scintillaView message:SCI_INSERTTEXT wParam:0 lParam:(sptr_t)"\xE2\x9C\x93"];
    [ed setFileEncoding:NSWindowsCP1252StringEncoding hasBOM:NO];
    [EditorView setLossySaveConfirmationHandlerForTesting:^BOOL(NSString *encodingName) { return YES; }];
    NSString *target = [self pathNamed:@"out-lossy-confirmed.txt"];
    NSError *err = nil;
    XCTAssertTrue([ed saveToPath:target error:&err], @"confirmed lossy save must succeed: %@", err);
    NSData *expected = [@"?abc\n" dataUsingEncoding:NSWindowsCP1252StringEncoding];
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:target], expected,
                          @"unrepresentable characters must become '?'");
}

- (void)testLosslessNonUTF8SaveDoesNotAskUser {
    NSData *input = [@"café\n" dataUsingEncoding:NSUTF8StringEncoding];
    EditorView *ed = [self openBytes:input named:@"lossless-cp1252.txt"];
    [ed setFileEncoding:NSWindowsCP1252StringEncoding hasBOM:NO];
    [EditorView setLossySaveConfirmationHandlerForTesting:^BOOL(NSString *encodingName) {
        XCTFail(@"a lossless save must not ask the user");
        return NO;
    }];
    NSString *target = [self pathNamed:@"out-lossless-cp1252.txt"];
    NSError *err = nil;
    XCTAssertTrue([ed saveToPath:target error:&err], @"lossless save must succeed: %@", err);
    NSData *expected = [@"café\n" dataUsingEncoding:NSWindowsCP1252StringEncoding];
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:target], expected);
}

- (void)testConvertDeclinedLeavesBufferAndEncodingUnchanged {
    NSData *input = [@"abc\n" dataUsingEncoding:NSUTF8StringEncoding];
    EditorView *ed = [self openBytes:input named:@"convert-declined.txt"];
    [ed.scintillaView message:SCI_INSERTTEXT wParam:0 lParam:(sptr_t)"\xE2\x9C\x93"];
    NSString *textBefore = ed.scintillaView.string;
    NSString *encodingBefore = ed.encodingName;
    [EditorView setLossySaveConfirmationHandlerForTesting:^BOOL(NSString *encodingName) { return NO; }];
    XCTAssertFalse([ed convertContentToEncoding:NSWindowsCP1252StringEncoding hasBOM:NO],
                   @"declined conversion must report failure");
    XCTAssertEqualObjects(ed.scintillaView.string, textBefore, @"declined conversion must not change the text");
    XCTAssertEqualObjects(ed.encodingName, encodingBefore, @"declined conversion must not change the encoding");
}

- (void)testConvertConfirmedReplacesUnrepresentableCharacters {
    NSData *input = [@"abc\n" dataUsingEncoding:NSUTF8StringEncoding];
    EditorView *ed = [self openBytes:input named:@"convert-confirmed.txt"];
    [ed.scintillaView message:SCI_INSERTTEXT wParam:0 lParam:(sptr_t)"\xE2\x9C\x93"];
    [EditorView setLossySaveConfirmationHandlerForTesting:^BOOL(NSString *encodingName) { return YES; }];
    XCTAssertTrue([ed convertContentToEncoding:NSWindowsCP1252StringEncoding hasBOM:NO],
                  @"confirmed conversion must succeed");
    XCTAssertEqualObjects(ed.scintillaView.string, @"?abc\n", @"unrepresentable characters must become '?'");
    XCTAssertTrue(ed.isModified, @"a conversion changes the document and must mark it modified");
}

- (void)testLosslessConvertDoesNotAskUser {
    NSData *input = [@"café\n" dataUsingEncoding:NSUTF8StringEncoding];
    EditorView *ed = [self openBytes:input named:@"convert-lossless.txt"];
    [EditorView setLossySaveConfirmationHandlerForTesting:^BOOL(NSString *encodingName) {
        XCTFail(@"a lossless conversion must not ask the user");
        return NO;
    }];
    XCTAssertTrue([ed convertContentToEncoding:NSWindowsCP1252StringEncoding hasBOM:NO]);
    XCTAssertEqualObjects(ed.scintillaView.string, @"café\n");
}

@end
