#define main YiApplicationMain
#import "../Sources/main.m"
#undef main
@interface SwitcherTestDelegate:AppDelegate @end
@implementation SwitcherTestDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)note {} // No real hotkeys or updater in test.
@end
static void Check(BOOL ok,const char *message){if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
static void Spin(double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];}
int main(void){@autoreleasepool{
 [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
 SwitcherTestDelegate *d=[SwitcherTestDelegate new];NSApp.delegate=d;[NSApp finishLaunching];d.targetCode=@"zh-CN";[d showSetup:nil];
 Check(NSApp.activationPolicy==NSApplicationActivationPolicyAccessory,"ordinary opening must remain menu-bar-only");
 NSButton *yellow=[d.setupWindow standardWindowButton:NSWindowMiniaturizeButton];
 Check(yellow.target==d && yellow.action==@selector(minimizeToSwitcher:),"yellow button must invoke the new behavior");
 [yellow performClick:nil];Spin(.5);
 Check(d.keepsSwitcherAfterMinimize && NSApp.activationPolicy==NSApplicationActivationPolicyRegular,"yellow click must put Yi in Dock and app switcher");
 Check(d.setupWindow.miniaturized,"yellow click must actually minimize the native window");
 [d applicationDidResignActive:[NSNotification notificationWithName:NSApplicationDidResignActiveNotification object:NSApp]];Check(d.setupWindow.miniaturized,"switching away must retain the minimized window");
 [d applicationDidBecomeActive:[NSNotification notificationWithName:NSApplicationDidBecomeActiveNotification object:NSApp]];Spin(.1);Check(!d.setupWindow.miniaturized && d.setupWindow.visible,"switching back must restore the main window");
 Check(NSApp.activationPolicy==NSApplicationActivationPolicyRegular,"restored app remains available to switcher until explicitly closed");
 [d.setupWindow orderOut:nil];Check(!d.setupWindow.visible && !d.setupWindow.miniaturized,"fixture must reproduce hidden but not miniaturized main window");
 [d applicationDidBecomeActive:[NSNotification notificationWithName:NSApplicationDidBecomeActiveNotification object:NSApp]];
 Check(d.setupWindow.visible,"Cmd+Tab must restore an orderOut-hidden main window too");
 [d.setupWindow orderOut:nil];d.statusMenuOpen=YES;
 [d applicationDidBecomeActive:[NSNotification notificationWithName:NSApplicationDidBecomeActiveNotification object:NSApp]];
 Check(!d.setupWindow.visible,"opening right-click menu must not summon main window");d.statusMenuOpen=NO;
 d.captureInProgress=YES;[d restoreWindowFromSwitcher];Check(!d.setupWindow.visible,"capture overlay must not reveal main window");d.captureInProgress=NO;
 [d restoreWindowFromSwitcher];Check(d.setupWindow.visible,"main window should remain restorable after capture guard clears");
 [d.permissionTimer invalidate];[d.setupWindow performClose:nil];
 Check(!d.keepsSwitcherAfterMinimize && NSApp.activationPolicy==NSApplicationActivationPolicyAccessory,"red close must return to original menu-bar behavior");
 puts("PASS: yellow-button wiring, native minimization, Cmd+Tab policy, activation and hidden-window restore, menu/capture guards, red-close reset and unchanged ordinary opening.");
}return 0;}
