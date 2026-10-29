#define main YiApplicationMain
#import "../Sources/main.m"
#undef main
@interface TrackingTestDelegate : AppDelegate
@property NSUInteger shortcutCalls;
@property NSUInteger starts;
@end
@implementation TrackingTestDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)note {}
- (void)capture:(id)sender { self.shortcutCalls++; self.captureInProgress=YES; self.captureWaitingForMenu=YES; }
- (void)beginCaptureSelection { self.starts++; }
@end
static void Check(BOOL ok,const char *message){if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
int main(void){ @autoreleasepool {
    [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    TrackingTestDelegate *d=[TrackingTestDelegate new]; NSApp.delegate=d; [NSApp finishLaunching];
    d.status=[NSStatusBar.systemStatusBar statusItemWithLength:24];d.status.button.title=@"T";
    d.statusMenu=[NSMenu new];[d.statusMenu addItemWithTitle:@"Yi native tracking test" action:NULL keyEquivalent:@""];
    __block BOOL firedDuringTracking=NO;
    CFRunLoopTimerRef timer=CFRunLoopTimerCreateWithHandler(NULL,CFAbsoluteTimeGetCurrent()+.15,0,0,0,^(CFRunLoopTimerRef timer){
        firedDuringTracking=d.statusMenuOpen && d.status.menu==d.statusMenu;
        EventRef event=NULL;CreateEvent(NULL,kEventClassKeyboard,kEventHotKeyPressed,0,kEventAttributeNone,&event);
        EventHotKeyID identifier={'Trns',1};SetEventParameter(event,kEventParamDirectObject,typeEventHotKeyID,sizeof(identifier),&identifier);
        Check(TranslationHotkeyHandler(NULL,event,(__bridge void *)d)==noErr,"capture hotkey must be accepted during native tracking");ReleaseEvent(event);
    });
    CFRunLoopAddTimer(CFRunLoopGetMain(),timer,kCFRunLoopCommonModes);
    // A separate common-mode watchdog fails instead of leaving a test menu open.
    CFRunLoopTimerRef watchdog=CFRunLoopTimerCreateWithHandler(NULL,CFAbsoluteTimeGetCurrent()+3,0,0,0,^(CFRunLoopTimerRef timer){
        [d.statusMenu cancelTracking];fprintf(stderr,"FAIL: hotkey was starved by menu tracking\n");exit(1);
    });
    CFRunLoopAddTimer(CFRunLoopGetMain(),watchdog,kCFRunLoopCommonModes);
    [d showStatusMenu];
    Check(firedDuringTracking && d.shortcutCalls==1,"hotkey must run before real native menu tracking returns");
    NSDate *end=[NSDate dateWithTimeIntervalSinceNow:.1];while(end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    Check(d.starts==1 && !d.statusMenuOpen && !d.status.menu,"capture must start exactly once after native menu closes and left-click behavior must reset");
    CFRunLoopTimerInvalidate(timer);CFRelease(timer);CFRunLoopTimerInvalidate(watchdog);CFRelease(watchdog);
    [NSStatusBar.systemStatusBar removeStatusItem:d.status];
    puts("PASS: real NSStatusItem menu tracking accepts the screenshot hotkey in common run-loop mode, closes and starts capture once.");
}return 0;}
