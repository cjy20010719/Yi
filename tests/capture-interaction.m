#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
// Exercise the capture UI without changing TCC or requiring test-binary access.
static bool TestScreenAccess(void) { return true; }
#define CGPreflightScreenCaptureAccess TestScreenAccess
#define main YiApplicationMain
#import "../Sources/main.m"
#undef main
#undef CGPreflightScreenCaptureAccess

@interface CaptureTestDelegate : AppDelegate
@property NSUInteger overlaysStarted;
@property NSUInteger translations;
@property NSUInteger snapshotsTaken;
@end
@implementation CaptureTestDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)note {}
- (BOOL)onlineEnabled { return YES; }
- (void)prepareCaptureFrames:(NSArray<NSScreen *> *)screens completion:(void (^)(NSArray<CaptureFrame *> *))completion {
    NSMutableArray *frames=[NSMutableArray new];
    for(NSScreen *screen in screens) {
        CaptureFrame *source=[CaptureFrame new]; source.frame=screen.frame; source.bitmap=[self snapshotForScreen:screen]; [frames addObject:source];
    }
    completion(frames);
}
- (NSBitmapImageRep *)snapshotForScreen:(NSScreen *)screen {
    if(self.captureWindows.count) { fprintf(stderr,"FAIL: screen must be frozen before any overlay is created\n");exit(1); }
    self.snapshotsTaken++;
    return [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:320 pixelsHigh:180 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
}
- (void)beginCaptureSelection { self.overlaysStarted++; [super beginCaptureSelection]; }
- (void)runTranslation:(NSString *)text anchor:(NSRect)rect context:(NSString *)context pid:(pid_t)pid { self.translations++; }
@end
@interface DeferredCaptureTestDelegate : CaptureTestDelegate
@property (copy) void (^snapshotCompletion)(NSArray<CaptureFrame *> *);
@property NSUInteger errorWindows;
@end
@implementation DeferredCaptureTestDelegate
- (void)prepareCaptureFrames:(NSArray<NSScreen *> *)screens completion:(void (^)(NSArray<CaptureFrame *> *))completion { self.snapshotCompletion=completion; }
- (void)showSetup:(id)sender { self.errorWindows++; }
@end
static void Check(BOOL ok,const char *message) { if(!ok) { fprintf(stderr,"FAIL: %s\n",message);exit(1); } }
static NSEvent *Mouse(NSEventType type, NSWindow *window, NSPoint point) {
    return [NSEvent mouseEventWithType:type location:point modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:window.windowNumber context:nil eventNumber:1 clickCount:1 pressure:1];
}
static void Spin(void) { NSDate *end=[NSDate dateWithTimeIntervalSinceNow:.1]; while(end.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]]; }
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    CaptureTestDelegate *d=[CaptureTestDelegate new]; NSApp.delegate=d; [NSApp finishLaunching];
    // Reproduce a capture action executing inside the status popup's tracking loop.
    d.statusMenuOpen=YES; [d capture:nil];
    Check(d.captureInProgress && d.captureWaitingForMenu && !d.captureWindows.count && !d.overlaysStarted,"menu action must reserve capture without creating overlays during tracking");
    [d resumeCaptureAfterMenu]; Check(!d.overlaysStarted,"an open menu must keep capture deferred");
    [d capture:nil]; Check(!d.overlaysStarted,"duplicate capture requests must not bypass menu deferral");
    d.statusMenuOpen=NO; [d resumeCaptureAfterMenu];
    Check(!d.overlaysStarted,"overlay creation must wait for the menu action stack to unwind");
    Spin(); Check(d.overlaysStarted==1 && d.captureWindows.count==NSScreen.screens.count,"menu selection must create exactly one overlay per display after dismissal");
    Check(d.snapshotsTaken==NSScreen.screens.count && d.captureFrames.count==NSScreen.screens.count,"all displays must be frozen before selection starts");
    NSArray *windows=d.captureWindows.copy; CaptureWindow *window=windows.lastObject; CaptureView *view=(CaptureView *)window.contentView;
    Check([window isKindOfClass:NSPanel.class] && (window.styleMask & NSWindowStyleMaskNonactivatingPanel) && !window.hidesOnDeactivate,"capture must use a nonactivating panel that survives app deactivation");
    Check(window.level>NSPopUpMenuWindowLevel,"capture panel must receive clicks above other apps' popup menus");
    [view mouseUp:Mouse(NSEventTypeLeftMouseUp,window,NSMakePoint(30,30))];
    Check(d.captureInProgress && !view.finished,"the menu-opening mouse-up must not immediately cancel capture");
    [NSApp sendEvent:Mouse(NSEventTypeRightMouseDown,window,NSMakePoint(30,30))];
    Check(!d.captureInProgress && !d.captureWindows.count && [d.lastStatus isEqual:@"已取消截图"],"native right mouse event must cancel capture and release all overlays");
    Check(!d.captureFrames.count,"cancellation must release frozen screen images");
    for(CaptureWindow *overlay in windows) Check(!overlay.visible && ((CaptureView *)overlay.contentView).finished && !((CaptureView *)overlay.contentView).snapshot,"cancellation must hide and invalidate overlays and release images on every display");
    [view mouseUp:Mouse(NSEventTypeLeftMouseUp,window,NSMakePoint(150,150))];
    Check(!d.translations,"cancelled capture must not translate on a late mouse-up");

    // Right-click while already dragging must also cancel instead of completing.
    [d capture:nil]; window=d.captureWindows.lastObject; view=(CaptureView *)window.contentView;
    [view mouseDown:Mouse(NSEventTypeLeftMouseDown,window,NSMakePoint(20,20))];
    [view mouseDragged:Mouse(NSEventTypeLeftMouseDragged,window,NSMakePoint(120,120))];
    [NSApp sendEvent:Mouse(NSEventTypeRightMouseDown,window,NSMakePoint(120,120))];
    Check(!d.captureInProgress && !view.dragging && !d.translations,"right-click during a drag must cancel without OCR or translation");
    [d capture:nil]; window=d.captureWindows.lastObject;
    NSEvent *escape=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil characters:@"\033" charactersIgnoringModifiers:@"\033" isARepeat:NO keyCode:53];
    [NSApp sendEvent:escape]; Check(!d.captureInProgress,"Escape cancellation must still work");

    // A normal drag still completes once, with a screen-coordinate rectangle.
    window=[[CaptureWindow alloc] initWithContentRect:NSMakeRect(100,100,200,200) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO]; window.releasedWhenClosed=NO;
    view=[[CaptureView alloc] initWithFrame:NSMakeRect(0,0,200,200)]; window.contentView=view;
    __block NSUInteger completions=0; __block NSRect selected=NSZeroRect;
    view.completion=^(NSRect rect){completions++;selected=rect;};
    [view mouseDown:Mouse(NSEventTypeLeftMouseDown,window,NSMakePoint(10,10))];
    [view mouseUp:Mouse(NSEventTypeLeftMouseUp,window,NSMakePoint(70,50))];
    [view rightMouseDown:Mouse(NSEventTypeRightMouseDown,window,NSZeroPoint)];
    Check(completions==1 && NSEqualRects(selected,NSMakeRect(110,110,60,40)),"normal drag must retain screen coordinates and complete exactly once");
    DeferredCaptureTestDelegate *deferred=[DeferredCaptureTestDelegate new];
    [deferred capture:nil];
    Check(deferred.captureFramesPreparing && !deferred.captureWindows.count,"asynchronous capture must not show overlays until snapshots are ready");
    void (^oldCompletion)(NSArray *)=deferred.snapshotCompletion;
    [deferred finishCapture:NSZeroRect];
    [deferred capture:nil];
    oldCompletion(nil);
    Check(deferred.captureInProgress && deferred.captureFramesPreparing && !deferred.errorWindows,"late callback from a cancelled snapshot must not affect a new capture");
    deferred.snapshotCompletion(nil);
    Check(!deferred.captureInProgress && !deferred.captureFramesPreparing && deferred.errorWindows==1,"snapshot failure must clear preparation and show a useful error");
    deferred.snapshotCompletion=nil;
    puts("PASS: status-menu capture deferral, opening mouse-up ignored, native right-click/drag/Escape cancellation, all-display cleanup and normal selection.");
    puts("PASS: asynchronous snapshot gating, cancelled-session isolation and failed-snapshot recovery.");
} return 0; }
