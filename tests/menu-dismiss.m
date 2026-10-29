#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
static NSArray *MenuWindowInfo;
static CFArrayRef FakeMenuWindowInfo(CGWindowListOption options,CGWindowID relativeToWindow) {return CFBridgingRetain(MenuWindowInfo ?: @[]);}
#define CGWindowListCopyWindowInfo FakeMenuWindowInfo
#define main YiApplicationMain
#import "../Sources/main.m"
#undef main
#undef CGWindowListCopyWindowInfo

@interface DismissMenuProbe : NSMenu
@property NSUInteger immediateCancellations;
@end
@implementation DismissMenuProbe
- (void)cancelTrackingWithoutAnimation { self.immediateCancellations++; }
@end
@interface DismissDelegateProbe : AppDelegate
@property uint64_t observedCounter;
@property NSPoint observedPointer;
@property BOOL pointerOutside;
@property NSPoint checkedPointer;
@end
@implementation DismissDelegateProbe
- (void)applicationDidFinishLaunching:(NSNotification *)notification {}
- (uint64_t)menuMouseDownCounter { return self.observedCounter; }
- (NSPoint)menuPointerLocation { return self.observedPointer; }
- (BOOL)menuPointerIsOutside:(NSPoint)point { self.checkedPointer=point;return self.pointerOutside; }
@end
static void Check(BOOL ok,const char *message){if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
int main(void){@autoreleasepool{
    [NSApplication sharedApplication];
    DismissDelegateProbe *delegate=[DismissDelegateProbe new];DismissMenuProbe *menu=[DismissMenuProbe new];delegate.statusMenu=menu;
    delegate.statusMenuOpen=YES;delegate.observedCounter=100;delegate.observedPointer=NSMakePoint(123,456);delegate.pointerOutside=YES;
    [delegate startStatusMenuDismissMonitor];
    CFRunLoopTimerRef timer=delegate.statusMenuDismissTimer;
    Check(timer && CFRunLoopTimerIsValid(timer),"menu opening must install a live dismissal timer");
    Check(CFRunLoopContainsTimer(CFRunLoopGetMain(),timer,kCFRunLoopCommonModes),"dismissal timer must run in common modes rather than being starved by menu tracking");
    [delegate pollStatusMenuDismissal];Check(!menu.immediateCancellations,"unchanged event counter must not dismiss a newly opened menu");
    // Button is already released by this poll; the counter still detects a quick click.
    delegate.observedCounter=101;[delegate pollStatusMenuDismissal];
    Check(menu.immediateCancellations==1 && NSEqualPoints(delegate.checkedPointer,delegate.observedPointer),"a completed quick outside click must immediately close the menu using the observed pointer");
    [delegate pollStatusMenuDismissal];Check(menu.immediateCancellations==1,"the same click must not repeatedly cancel tracking");
    delegate.pointerOutside=NO;delegate.observedCounter=102;[delegate pollStatusMenuDismissal];
    Check(menu.immediateCancellations==1,"inside-menu clicks must remain available to menu items and submenus");
    delegate.pointerOutside=YES;[delegate pollStatusMenuDismissal];Check(menu.immediateCancellations==1,"moving outside after an inside click must not turn it into a second click");
    delegate.statusMenuOpen=NO;delegate.observedCounter=103;[delegate pollStatusMenuDismissal];Check(menu.immediateCancellations==1,"a closed menu must ignore new mouse clicks");
    CFRetain(timer);[delegate stopStatusMenuDismissMonitor];Check(!delegate.statusMenuDismissTimer && !CFRunLoopTimerIsValid(timer),"tracking cleanup must clear and invalidate the timer");CFRelease(timer);
    [delegate stopStatusMenuDismissMonitor];

    delegate.statusMenuOpen=YES;delegate.observedCounter=200;[delegate startStatusMenuDismissMonitor];
    delegate.observedCounter=201;
    // Run only a tracking-like common mode. Default-mode dispatch is not relied on.
    CFStringRef mode=CFSTR("YiMenuDismissTrackingTest");CFRunLoopAddCommonMode(CFRunLoopGetMain(),mode);
    CFRunLoopRunInMode(mode,.18,false);
    Check(menu.immediateCancellations==2,"outside dismissal must fire while only a common tracking mode is running");
    [delegate stopStatusMenuDismissMonitor];delegate.statusMenuOpen=NO;
    // Verify the production geometry predicate with captured-window metadata,
    // including secondary-display coordinates and an open submenu.
    AppDelegate *geometry=[AppDelegate new];CGFloat top=NSMaxY(NSScreen.screens.firstObject.frame);
    NSMutableArray *records=[NSMutableArray new];
    for(NSValue *value in @[[NSValue valueWithRect:NSMakeRect(-500,100,220,300)],[NSValue valueWithRect:NSMakeRect(-280,170,180,180)]]) {
        NSRect rect=value.rectValue;CGRect quartz=CGRectMake(rect.origin.x,top-NSMaxY(rect),rect.size.width,rect.size.height);
        NSDictionary *bounds=CFBridgingRelease(CGRectCreateDictionaryRepresentation(quartz));
        [records addObject:@{(id)kCGWindowOwnerPID:@(NSProcessInfo.processInfo.processIdentifier),(id)kCGWindowLayer:@(NSPopUpMenuWindowLevel),(id)kCGWindowBounds:bounds}];
    }
    MenuWindowInfo=records;
    Check(![geometry menuPointerIsOutside:NSMakePoint(-450,200)] && ![geometry menuPointerIsOutside:NSMakePoint(-200,200)],"root menu and submenu coordinates must remain inside across negative display coordinates");
    Check([geometry menuPointerIsOutside:NSMakePoint(750,50)],"a click outside visible own popups must dismiss the menu");
    MenuWindowInfo=@[];
    Check(![geometry menuPointerIsOutside:NSMakePoint(20,20)],"missing popup geometry must fail safely rather than canceling legitimate menu input");
    puts("PASS: quick outside clicks dismiss immediately, inside/unchanged/closed events are ignored, common-mode polling and timer cleanup work.");
}return 0;}
