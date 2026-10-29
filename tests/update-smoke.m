// Isolated Sparkle integration app. Never uses Yi's real bundle ID or preferences.
#import <Cocoa/Cocoa.h>
#import <Sparkle/Sparkle.h>
@interface SmokeDelegate:NSObject<NSApplicationDelegate,SPUUpdaterDelegate>
@property SPUStandardUpdaterController *controller;
@property NSWindow *window;
@end
@implementation SmokeDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    NSString *version=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *record=[NSBundle.mainBundle.bundlePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"launches.txt"];
    NSFileHandle *file=[NSFileHandle fileHandleForWritingAtPath:record];
    if(!file) { [NSData.data writeToFile:record atomically:YES]; file=[NSFileHandle fileHandleForWritingAtPath:record]; }
    [file seekToEndOfFile]; [file writeData:[[version stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]]; [file closeFile];
    self.controller=[[SPUStandardUpdaterController alloc] initWithStartingUpdater:YES updaterDelegate:self userDriverDelegate:nil];
    self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,440,180) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    self.window.title=[@"Yi 更新验证 " stringByAppendingString:version]; self.window.releasedWhenClosed=NO;
    NSTextField *label=[NSTextField labelWithString:[@"独立测试副本 · " stringByAppendingString:version]]; label.frame=NSMakeRect(30,110,380,30); [self.window.contentView addSubview:label];
    NSButton *button=[NSButton buttonWithTitle:@"检查更新…" target:self.controller action:@selector(checkForUpdates:)]; button.frame=NSMakeRect(135,40,170,40); [self.window.contentView addSubview:button];
    [self.window center]; [self.window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
}
- (void)updater:(SPUUpdater *)updater didAbortWithError:(NSError *)error { NSLog(@"UPDATE ERROR: %@",error); }
@end
int main(void) { @autoreleasepool { NSApplication *app=NSApplication.sharedApplication; SmokeDelegate *delegate=[SmokeDelegate new]; app.delegate=delegate; [app run]; } }
