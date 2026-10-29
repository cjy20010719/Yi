#define main YiApplicationMain
#import "../Sources/main.m"
#undef main

static void Next(Translator *translator, NSUInteger index) {
    NSArray *samples = @[@"Welcome to Chen Shanglong Music Studio", @"Welcome to John Smith Music Studio", @"Bonjour Pierre, bienvenue dans notre studio de musique.", @"明天和 John Smith 在 서울 开会。Please bring the document. ありがとうございます。"];
    if (index == samples.count) { puts("PASS: live translation of English/French names and mixed Korean/English/Japanese/Chinese."); exit(0); }
    [translator translate:samples[index] completion:^(NSString *result, NSError *error) {
        if (error || [result isEqual:samples[index]] || [result rangeOfString:@"\\p{Han}" options:NSRegularExpressionSearch].location == NSNotFound || (index < 2 && (![result containsString:@"欢迎"] || ![result containsString:@"工作室"]))) {
            fprintf(stderr, "FAIL: %s / %s\n", result.UTF8String, error.localizedDescription.UTF8String); exit(1);
        }
        printf("%s → %s\n", [samples[index] UTF8String], result.UTF8String); fflush(stdout);
        Next(translator, index + 1);
    }];
}
int main(void) { @autoreleasepool { Next([Translator new], 0); [NSRunLoop.mainRunLoop run]; } return 0; }
