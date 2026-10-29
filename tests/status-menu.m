#define main YiApplicationMain
#import "../Sources/main.m"
#undef main

@interface MenuProbe : NSMenu
@property NSUInteger cancellations;
@property (copy) void (^tracking)(void);
@end
@implementation MenuProbe
- (void)cancelTracking { self.cancellations++; }
- (void)cancelTrackingWithoutAnimation { self.cancellations++; }
@end
@interface StatusButtonProbe : NSButton
@property (copy) void (^clicked)(void);
@end
@implementation StatusButtonProbe
- (void)performClick:(id)sender { if(self.clicked) self.clicked(); }
@end
@interface StatusItemProbe : NSObject
@property NSMenu *menu;
@property StatusButtonProbe *button;
@end
@implementation StatusItemProbe @end
@interface MenuTestDelegate : AppDelegate
@property NSUInteger captureStarts;
@end
@implementation MenuTestDelegate
- (uint64_t)menuMouseDownCounter { return 0; }
- (void)applicationDidFinishLaunching:(NSNotification *)note {}
- (void)beginCaptureSelection { self.captureStarts++; }
@end
@interface ActivatedApp : NSObject
@property pid_t processIdentifier;
@end
@implementation ActivatedApp @end
static void Check(BOOL condition,const char *message) { if(!condition) { fprintf(stderr,"FAIL: %s\n",message);exit(1); } }
static void Spin(void) { NSDate *end=[NSDate dateWithTimeIntervalSinceNow:.1]; while(end.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]]; }
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    MenuTestDelegate *d=[MenuTestDelegate new]; MenuProbe *menu=[MenuProbe new]; d.statusMenu=menu;
    StatusItemProbe *item=[StatusItemProbe new]; item.button=[StatusButtonProbe new]; d.status=(id)item;
    item.button.clicked=^{
        Check(item.menu==menu,"native status-item menu property must be attached before performClick");
        if(menu.tracking) menu.tracking();
    };
    menu.tracking=^{
        Check(d.statusMenuOpen,"menu must stay marked open during native tracking");
        // A reentrant request must not start another nested tracking loop.
        [d showStatusMenu];
        [d applicationDidResignActive:[NSNotification notificationWithName:NSApplicationDidResignActiveNotification object:NSApp]];
        Check(menu.cancellations==1,"losing activation must cancel menu even with automatic selection disabled");
    };
    [d showStatusMenu]; Check(!d.statusMenuOpen && !item.menu,"menu exit must clear tracking and restore ordinary left-click behavior");
    [d dismissStatusMenu]; Check(menu.cancellations==1,"closed menu must not be cancelled again");
    menu.tracking=^{
        ActivatedApp *other=[ActivatedApp new]; other.processIdentifier=NSProcessInfo.processInfo.processIdentifier+1;
        NSNotification *notice=[NSNotification notificationWithName:NSWorkspaceDidActivateApplicationNotification object:nil userInfo:@{NSWorkspaceApplicationKey:other}];
        d.captureInProgress=YES; [d appChanged:notice];
        Check(menu.cancellations==2,"app switch must dismiss menu before capture or bubble interaction guards");
        d.captureInProgress=NO;
        ActivatedApp *same=[ActivatedApp new]; same.processIdentifier=NSProcessInfo.processInfo.processIdentifier;
        NSNotification *own=[NSNotification notificationWithName:NSWorkspaceDidActivateApplicationNotification object:nil userInfo:@{NSWorkspaceApplicationKey:same}];
        [d appChanged:own]; Check(menu.cancellations==2,"Yi's own activation must preserve its menu");
    };
    [d showStatusMenu];
    menu.tracking=^{ @throw [NSException exceptionWithName:@"MenuTest" reason:@"cleanup fixture" userInfo:nil]; };
    @try { [d showStatusMenu]; } @catch(NSException *exception) { Check([exception.name isEqual:@"MenuTest"],"unexpected exception"); }
    Check(!d.statusMenuOpen && !item.menu,"tracking cleanup must also run after an exception");
    menu.tracking=^{ d.captureInProgress=YES; d.captureWaitingForMenu=YES; Check(d.captureStarts==0,"capture must remain deferred inside menu"); };
    [d showStatusMenu]; Spin();
    Check(d.captureStarts==1 && !d.captureWaitingForMenu,"capture menu action must still start once after tracking ends");
    menu.tracking=nil;
    item.button.clicked=nil;
    puts("PASS: app deactivation and workspace-switch dismissal, reentry/exception cleanup, self-activation guard and deferred screenshot action.");
} return 0; }
