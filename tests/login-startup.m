#define main YiApplicationMain
#import "../Sources/main.m"
#undef main

@interface FakeLoginService:NSObject<YiLoginService>
@property SMAppServiceStatus status;
@property NSUInteger registrations;
@property NSUInteger unregistrations;
@property BOOL fail;
@property BOOL approvalRequired;
@end
@implementation FakeLoginService
- (BOOL)registerAndReturnError:(NSError **)error {
    self.registrations++;
    if(self.fail) { if(error) *error=[NSError errorWithDomain:@"test" code:1 userInfo:nil];return NO; }
    self.status=self.approvalRequired ? SMAppServiceStatusRequiresApproval : SMAppServiceStatusEnabled;return YES;
}
- (BOOL)unregisterAndReturnError:(NSError **)error {
    self.unregistrations++;
    if(self.fail) { if(error) *error=[NSError errorWithDomain:@"test" code:2 userInfo:nil];return NO; }
    self.status=SMAppServiceStatusNotRegistered;return YES;
}
@end
@interface LoginTestDelegate:AppDelegate
@property NSUInteger windowsShown;
@property NSUInteger errorsShown;
@property NSUInteger approvalsShown;
@end
@implementation LoginTestDelegate
- (void)showSetup:(id)sender { self.windowsShown++; }
- (void)showLoginServiceError:(NSError *)error { self.errorsShown++; }
- (void)requestLoginServiceApproval { self.approvalsShown++; }
@end
static void Check(BOOL ok,const char *message) { if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);} }
static NSAppleEventDescriptor *LaunchEvent(AEEventID eventID,OSType reason) {
    NSAppleEventDescriptor *event=[NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass eventID:eventID targetDescriptor:nil returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
    if(reason) [event setParamDescriptor:[NSAppleEventDescriptor descriptorWithEnumCode:reason] forKeyword:keyAEPropData];
    return event;
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    Check(WasLaunchedAtLogin(LaunchEvent(kAEOpenApplication,keyAELaunchedAsLogInItem)),"real Launch Services login marker must be recognized");
    Check(!WasLaunchedAtLogin(nil) && !WasLaunchedAtLogin(LaunchEvent(kAEOpenApplication,0)),"manual launch must still show main window");
    Check(!WasLaunchedAtLogin(LaunchEvent(kAEReopenApplication,keyAELaunchedAsLogInItem)),"reopen is not a silent startup");
    Check(!WasLaunchedAtLogin(LaunchEvent(kAEOpenApplication,keyAELaunchedAsServiceItem)),"service launch is not a main-app login marker");
    LoginTestDelegate *d=[LoginTestDelegate new];FakeLoginService *service=[FakeLoginService new];d.loginService=service;
    [d finishStartupForLoginLaunch:YES];Check(d.windowsShown==0,"login startup must not create or activate main window");
    [d finishStartupForLoginLaunch:NO];Check(d.windowsShown==1,"manual startup still opens the main window");
    [d applicationShouldHandleReopen:NSApp hasVisibleWindows:NO];Check(d.windowsShown==2,"manual reopening after silent startup opens the window");
    Check(service.registrations==0,"startup must never opt into persistence automatically");
    NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:@"开机静默启动" action:@selector(toggleLaunchAtLogin:) keyEquivalent:@""];
    [d validateMenuItem:item];Check(item.state==NSControlStateValueOff,"new login setting is off");
    [d toggleLaunchAtLogin:item];[d validateMenuItem:item];Check(service.registrations==1 && item.state==NSControlStateValueOn,"register and show actual enabled status");
    service.fail=YES;[d toggleLaunchAtLogin:item];[d validateMenuItem:item];Check(d.errorsShown==1 && item.state==NSControlStateValueOn,"failed unregister must not falsely clear setting");
    service.fail=NO;[d toggleLaunchAtLogin:item];[d validateMenuItem:item];Check(item.state==NSControlStateValueOff,"unregister must clear system state");
    service.approvalRequired=YES;[d toggleLaunchAtLogin:item];[d validateMenuItem:item];Check(d.approvalsShown==1 && item.state==NSControlStateValueMixed && [item.title containsString:@"待系统允许"],"pending OS approval must not be reported as enabled");
    [d toggleLaunchAtLogin:item];Check(service.status==SMAppServiceStatusNotRegistered,"pending approval registration can be disabled");
    service.fail=YES;[d toggleLaunchAtLogin:item];Check(d.errorsShown==2 && service.status==SMAppServiceStatusNotRegistered,"failed register must not create a fake enabled preference");
    puts("PASS: login/manual/reopen launch routing, opt-in registration, unregister, external status, failure and approval states.");
}return 0;}
