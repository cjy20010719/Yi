#define main YiApplicationMain
#import "../Sources/main.m"
#undef main
static void Check(BOOL ok,const char *message){if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
static CGImageRef Fixture(CGColorSpaceRef space) CF_RETURNS_RETAINED {
    unsigned char pixels[]={32,32,32,255,64,64,64,255,128,128,128,255,200,200,200,255,210,70,40,255,35,150,90,255,40,90,210,255,170,80,180,255};
    CGContextRef context=CGBitmapContextCreate(NULL,8,1,8,32,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    memcpy(CGBitmapContextGetData(context),pixels,sizeof pixels);
    CGImageRef image=CGBitmapContextCreateImage(context);CGContextRelease(context);return image;
}
static BOOL Verify(CGColorSpaceRef space,const char *name) {
    CGImageRef source=Fixture(space); NSBitmapImageRep *copy=CopyCaptureBitmap(source);
    unsigned char output[32]={0};
    CGContextRef context=CGBitmapContextCreate(output,8,1,8,32,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGContextDrawImage(context,CGRectMake(0,0,8,1),copy.CGImage);CGContextRelease(context);
    CFDataRef original=CGDataProviderCopyData(CGImageGetDataProvider(source));
    const UInt8 *expected=CFDataGetBytePtr(original);int maximum=0;
    for(NSUInteger i=0;i<32;i++) if(i%4!=3) maximum=MAX(maximum,abs((int)output[i]-(int)expected[i]));
    printf("%s capture round-trip maximum channel change: %d / 255\n",name,maximum);fflush(stdout);
    BOOL tagged=CFEqual(CGImageGetColorSpace(copy.CGImage),space);
    printf("Source color profile retained: %s\n",tagged ? "yes" : "no");
    NSBitmapImageRep *rendered=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:8 pixelsHigh:1 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:32 bitsPerPixel:32];
    rendered=[rendered bitmapImageRepByRetaggingWithColorSpace:[[NSColorSpace alloc] initWithCGColorSpace:space]];
    CaptureView *view=[[CaptureView alloc] initWithFrame:NSMakeRect(0,0,8,1)];
    view.snapshot=[[NSImage alloc] initWithCGImage:copy.CGImage size:NSMakeSize(8,1)]; view.snapshot.cacheMode=NSImageCacheNever;
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:rendered];
    NSRectClip(view.bounds); [view drawRect:view.bounds]; [NSGraphicsContext restoreGraphicsState];
    int paintedMaximum=0;
    for(NSUInteger i=0;i<32;i++) if(i%4!=3) paintedMaximum=MAX(paintedMaximum,abs((int)rendered.bitmapData[i]-(int)expected[i]));
    printf("AppKit capture panel drawing maximum channel change: %d / 255\n",paintedMaximum);
    CFRelease(original);CGImageRelease(source);return maximum<=1 && paintedMaximum<=1 && tagged;
}
static void VerifyUnmanagedCapture(void) {
    CGColorSpaceRef p3=CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3),device=CGColorSpaceCreateDeviceRGB(),srgb=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGImageRef expectedImage=Fixture(p3),unmanaged=CGImageCreateCopyWithColorSpace(expectedImage,device);
    NSBitmapImageRep *copy=CopyConfiguredCaptureBitmap(unmanaged,p3);
    unsigned char expected[32]={0},actual[32]={0};
    CGContextRef context=CGBitmapContextCreate(expected,8,1,8,32,srgb,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGContextDrawImage(context,CGRectMake(0,0,8,1),expectedImage);CGContextRelease(context);
    context=CGBitmapContextCreate(actual,8,1,8,32,srgb,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGContextDrawImage(context,CGRectMake(0,0,8,1),copy.CGImage);CGContextRelease(context);
    int maximum=0; for(NSUInteger i=0;i<32;i++) if(i%4!=3) maximum=MAX(maximum,abs((int)expected[i]-(int)actual[i]));
    printf("Unmanaged screenshot to sRGB display maximum channel change: %d / 255\n",maximum);fflush(stdout);
    Check(maximum<=1 && CFEqual(CGImageGetColorSpace(copy.CGImage),p3),"unmanaged screenshot must use its explicitly configured output profile");
    CGImageRef taggedSRGB=Fixture(srgb);
    NSBitmapImageRep *preserved=CopyConfiguredCaptureBitmap(taggedSRGB,p3);
    Check(CFEqual(CGImageGetColorSpace(preserved.CGImage),srgb),"valid screenshot ICC must not be replaced by the requested output profile");CGImageRelease(taggedSRGB);
    for(NSScreen *screen in NSScreen.screens) {
        CGColorSpaceRef display=screen.colorSpace.CGColorSpace;
        if(!display) continue;
        CGImageRef taggedDisplay=Fixture(display),deviceDisplay=CGImageCreateCopyWithColorSpace(taggedDisplay,device);
        NSBitmapImageRep *fallback=CopyConfiguredCaptureBitmap(deviceDisplay,display);
        Check(CFEqual(CGImageGetColorSpace(fallback.CGImage),display),"Quartz fallback must resolve DeviceRGB with the actual display ICC");
        CGImageRelease(deviceDisplay);CGImageRelease(taggedDisplay);
    }
    CGImageRelease(unmanaged);CGImageRelease(expectedImage);CGColorSpaceRelease(p3);CGColorSpaceRelease(device);CGColorSpaceRelease(srgb);
}
int main(void){@autoreleasepool{
    [NSApplication sharedApplication];
    VerifyUnmanagedCapture();
    BOOL passed=YES;
    for(NSString *name in @[(__bridge NSString *)kCGColorSpaceSRGB,(__bridge NSString *)kCGColorSpaceDisplayP3,(__bridge NSString *)kCGColorSpaceGenericRGB]) {
        CGColorSpaceRef space=CGColorSpaceCreateWithName((__bridge CFStringRef)name);passed=Verify(space,name.UTF8String) && passed;CGColorSpaceRelease(space);
    }
    for(NSScreen *screen in NSScreen.screens) {
        CGColorSpaceRef space=screen.colorSpace.CGColorSpace;
        if(space && CGColorSpaceGetModel(space)==kCGColorSpaceModelRGB) passed=Verify(space,"Current display ICC") && passed;
    }
    Check(passed,"capture must preserve pixel colors, mid-gray brightness and source profiles");
    puts("PASS: sRGB, Display P3, generic RGB and connected-display color profiles retain brightness and color.");
}return 0;}
