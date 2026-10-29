#define main YiApplicationMain
#import "../Sources/main.m"
#undef main

static void Check(BOOL condition, NSString *message) {
    if (!condition) { fprintf(stderr, "FAIL: %s\n", message.UTF8String); exit(1); }
}

@interface FixtureReader : SelectionReader
@end
@implementation FixtureReader
- (BOOL)isElement:(id)element { return [element isKindOfClass:NSDictionary.class]; }
- (id)attribute:(id)element name:(CFStringRef)name { return element[(__bridge NSString *)name]; }
- (id)parameter:(id)element name:(CFStringRef)name value:(id)value {
    if (!value) return nil;
    return element[(__bridge NSString *)name];
}
@end

@interface NameTranslator : Translator
@property NSMutableArray *requests;
@property BOOL failRetry;
@end
@implementation NameTranslator
- (instancetype)init { if ((self = [super init])) _requests = [NSMutableArray new]; return self; }
- (void)raw:(NSString *)text source:(NSString *)source completion:(TranslationCompletion)completion {
    [self.requests addObject:@[source, text]];
    if ([source isEqual:@"auto"]) { completion(text, nil); return; } // Reproduce the reported untranslated result.
    if (self.failRetry) { completion(nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]); return; }
    NSDictionary *translations = @{@"Welcome to Chen Shanglong Music Studio":@"欢迎来到陈尚龙音乐工作室", @"Welcome to John Smith Music Studio":@"欢迎来到约翰·史密斯音乐工作室", @"Bonjour Pierre":@"你好，皮埃尔"};
    completion(translations[text] ?: text, nil);
}
@end

int main(void) {
    @autoreleasepool {
        FixtureReader *reader = [FixtureReader new];
        NSPoint point = NSMakePoint(100, 100);
        NSDictionary *web = @{@"AXSelectedTextMarkerRange":@"selected-marker", @"AXStringForTextMarkerRange":@"Welcome to Chen Shanglong Music Studio"};
        NSDictionary *focus = @{@"AXParent":web};
        Check([[reader readFocus:focus hit:nil window:nil fallback:point].text isEqual:@"Welcome to Chen Shanglong Music Studio"], @"WebKit parent text-marker selection must be read");
        NSDictionary *nested = @{@"AXChildren":@[@{@"AXChildren":@[web]}]};
        Check([reader readFocus:@{} hit:nil window:nested fallback:point] != nil, @"nested web area selection must be found even when focus is a container");
        Check([reader readFocus:nil hit:web window:nil fallback:point] != nil, @"hit-tested text must work without focused text");
        NSDictionary *secure = @{@"AXSubrole":@"AXSecureTextField", @"AXSelectedText":@"secret"};
        Check([reader readFocus:secure hit:web window:nested fallback:point] == nil, @"secure focus must block all fallbacks");
        Check([reader readFocus:@{} hit:nil window:@{@"AXValue":@"unselected page content"} fallback:point] == nil, @"unselected AXValue must never be treated as selected text");
        CFRange characters=CFRangeMake(7,17);
        id range=CFBridgingRelease(AXValueCreate(kAXValueCFRangeType,&characters));
        NSDictionary *ranged=@{@"AXSelectedTextRange":range,@"AXStringForRange":@"Change visibility"};
        Check([[reader readFocus:ranged hit:nil window:nil fallback:point].text isEqual:@"Change visibility"],@"selected range without AXSelectedText must be extracted using AXStringForRange");
        NSDictionary *sliced=@{@"AXSelectedTextRange":range,@"AXValue":@"prefix Change visibility suffix"};
        Check([[reader readFocus:sliced hit:nil window:nil fallback:point].text isEqual:@"Change visibility"],@"valid selected range must slice only selected text, excluding surrounding content");
        characters=CFRangeMake(1000,20); id invalid=CFBridgingRelease(AXValueCreate(kAXValueCFRangeType,&characters));
        Check([reader readFocus:@{@"AXSelectedTextRange":invalid,@"AXValue":@"short"} hit:nil window:nil fallback:point]==nil,@"out-of-bounds ranges must not fall back to whole content");
        id deep=web; for(NSUInteger depth=0;depth<14;depth++) deep=@{@"AXRole":@"AXGroup",@"AXContents":@[deep]};
        Check([[reader readFocus:nil hit:nil window:deep fallback:point].text isEqual:web[@"AXStringForTextMarkerRange"]],@"deeply nested chat web areas must be found through AXContents");
        Check([reader readFocus:@{@"AXSelectedText":@42} hit:nil window:nil fallback:point] == nil, @"malformed selection must be ignored");
        Check([reader readFocus:@{@"AXSelectedText":[@"x" stringByPaddingToLength:5001 withString:@"x" startingAtIndex:0]} hit:nil window:nil fallback:point] == nil, @"selection length limit must apply to every fallback");
        NSMutableDictionary *cycle = [NSMutableDictionary new]; cycle[@"AXParent"] = cycle;
        Check([reader readFocus:cycle hit:nil window:nil fallback:point] == nil, @"cyclic AX parents must terminate"); [cycle removeAllObjects];
        puts("PASS: web text markers, nested containers, hit testing, secure fields, no-selection, length limit and cycles.");

        NameTranslator *translator = [NameTranslator new];
        for (NSString *sample in @[@"Welcome to Chen Shanglong Music Studio", @"Welcome to John Smith Music Studio", @"Bonjour Pierre"]) {
            [translator translate:sample completion:^(NSString *result, NSError *error) {
                Check(!error && [result rangeOfString:@"\\p{Han}" options:NSRegularExpressionSearch].location != NSNotFound, @"unchanged name-containing sentence must be translated using local language fallback");
            }];
        }
        Check([translator.requests[1][0] isEqual:@"en"], @"English phrase must retry as English, retaining the full name and context");
        Check([translator.requests.lastObject[0] isEqual:@"fr"], @"French phrase must retry as French");
        [translator translate:@"明天 Welcome to John Smith Music Studio。" completion:^(NSString *result, NSError *error) {
            Check(!error && [result hasPrefix:@"明天 "] && [result containsString:@"音乐工作室"], @"mixed Chinese and name phrase must preserve Chinese and translate the entire foreign span");
        }];
        NSUInteger count = translator.requests.count;
        [translator translate:@"Welcome to Chen Shanglong Music Studio" completion:^(NSString *result, NSError *error) { Check(result.length && !error, @"cache result must be available"); }];
        Check(count == translator.requests.count, @"successful retry must be cached");
        NameTranslator *cancelled = [NameTranslator new]; cancelled.failRetry = YES;
        [cancelled translate:@"Welcome to Chen Shanglong Music Studio" completion:^(NSString *result, NSError *error) { Check(!result && error.code == NSURLErrorCancelled, @"cancellation must not publish an untranslated success"); }];
        puts("PASS: English/French names, mixed Chinese preservation, retry cache and cancellation.");
    }
    return 0;
}
