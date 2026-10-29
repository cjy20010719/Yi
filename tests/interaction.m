#define main YiApplicationMain
#import "../Sources/main.m"
#undef main

@interface EventTestDelegate : AppDelegate
@property NSUInteger cancellations;
@end
@implementation EventTestDelegate
- (void)cancel { self.cancellations++; }
@end

static void Require(BOOL condition, const char *message) {
    if (!condition) { fprintf(stderr,"FAIL: %s\n",message); exit(1); }
}

static void ClickControl(NSView *view) {
    NSPoint point=[view convertPoint:NSMakePoint(NSMidX(view.bounds),NSMidY(view.bounds)) toView:nil];
    NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    NSEvent *up=[NSEvent mouseEventWithType:NSEventTypeLeftMouseUp location:point modifierFlags:0 timestamp:now+0.01 windowNumber:view.window.windowNumber context:nil eventNumber:4 clickCount:1 pressure:0];
    NSEvent *down=[NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:point modifierFlags:0 timestamp:now windowNumber:view.window.windowNumber context:nil eventNumber:3 clickCount:1 pressure:1];
    [NSApp postEvent:up atStart:YES]; [NSApp sendEvent:down];
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        EventTestDelegate *delegate=[EventTestDelegate new];
        NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,200,100) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
        window.releasedWhenClosed=NO; delegate.setupWindow=window;
        NSArray *mouseTypes=@[@(NSEventTypeLeftMouseDown),@(NSEventTypeLeftMouseUp),@(NSEventTypeRightMouseDown),@(NSEventTypeMouseMoved)];
        for (NSNumber *type in mouseTypes) {
            NSEvent *event=[NSEvent mouseEventWithType:type.unsignedIntegerValue location:NSMakePoint(20,20) modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil eventNumber:1 clickCount:1 pressure:1];
            @try { Require([delegate handleLocalEvent:event]==event,"mouse event must reach its control unchanged"); }
            @catch(NSException *exception) { fprintf(stderr,"FAIL: mouse event raised %s\n",exception.reason.UTF8String); return 2; }
        }
        Require(delegate.cancellations==1,"only a main-window mouse-down dismisses the old bubble");
        Bubble *bubble=[Bubble new];
        NSEvent *bubbleClick=[NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:NSMakePoint(20,20) modifierFlags:0 timestamp:0 windowNumber:bubble.panel.windowNumber context:nil eventNumber:2 clickCount:1 pressure:1];
        Require([delegate handleLocalEvent:bubbleClick]==bubbleClick,"bubble click must be delivered");
        Require(delegate.cancellations==1,"bubble controls must not cancel their own translation");
        NSEvent *escape=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil characters:@"\033" charactersIgnoringModifiers:@"\033" isARepeat:NO keyCode:53];
        [delegate handleLocalEvent:escape];
        Require(delegate.cancellations==2,"Escape should dismiss the bubble");
        delegate.captureInProgress=YES; [delegate handleLocalEvent:escape];
        Require(delegate.cancellations==2,"capture overlay must receive Escape itself");
        delegate.captureInProgress=NO;
        id monitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown|NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event){ return [delegate handleLocalEvent:event]; }];
        [window makeKeyAndOrderFront:nil];
        ClickControl([window standardWindowButton:NSWindowCloseButton]);
        Require(!window.visible,"native close button must close after mouse-down passes the monitor");
        __block NSString *selected=nil;
        bubble.targetChanged=^(NSString *code){ selected=code; };
        [bubble show:@"测试译文" anchor:NSMakeRect(150,150,20,20) result:YES];
        [bubble.panel makeKeyAndOrderFront:nil];
        ClickControl(bubble.swapButton);
        Require([selected isEqual:@"en"],"native bubble mouse click must invoke language switching");
        [bubble hide]; [NSEvent removeMonitor:monitor];
        puts("PASS: mouse events reach main and bubble controls without reading keyboard-only fields; Escape routing preserved.");
        puts("PASS: dispatched mouse clicks closed the native window and invoked the bubble language button.");
        return 0;
    }
}
