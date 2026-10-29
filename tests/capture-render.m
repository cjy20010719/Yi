#define main YiApplicationMain
#import "../Sources/main.m"
#undef main
static void Check(BOOL ok,const char *message){if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
static NSBitmapImageRep *Render(CaptureView *view) {
    NSBitmapImageRep *output=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:(NSInteger)view.bounds.size.width pixelsHigh:(NSInteger)view.bounds.size.height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    memset(output.bitmapData,0,output.bytesPerRow*output.pixelsHigh);
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:output];
    [view drawRect:view.bounds];
    [NSGraphicsContext restoreGraphicsState];return output;
}
int main(int argc,const char *argv[]){@autoreleasepool{
    [NSApplication sharedApplication];
    NSImage *menu=[[NSImage alloc] initWithSize:NSMakeSize(320,200)];
    [menu lockFocus];[NSColor.whiteColor setFill];NSRectFill(NSMakeRect(0,0,320,200));
    [@"Reload Config" drawAtPoint:NSMakePoint(44,112) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:21],NSForegroundColorAttributeName:NSColor.blackColor}];
    [menu unlockFocus];
    CaptureView *view=[[CaptureView alloc] initWithFrame:NSMakeRect(0,0,320,200)];view.snapshot=menu;
    NSBitmapImageRep *rendered=Render(view);NSUInteger pixel[4];[rendered getPixel:pixel atX:10 y:10];
    Check(pixel[0]>245 && pixel[1]>245 && pixel[2]>245 && pixel[3]==255,"capture must preserve original screen brightness without a dimming overlay");
    view.dragging=YES;view.selection=NSMakeRect(30,90,230,65);rendered=Render(view);
    [rendered getPixel:pixel atX:35 y:100];
    Check(pixel[0]>205 && pixel[0]<225 && pixel[1]>205 && pixel[1]<225 && pixel[2]>205 && pixel[2]<225 && pixel[3]==255,"selected region must have a subtle gray tint over opaque frozen pixels");
    [rendered getPixel:pixel atX:10 y:10];
    Check(pixel[0]>245 && pixel[1]>245 && pixel[2]>245 && pixel[3]==255,"dragging must keep the area outside the selection at original brightness");
    NSError *error=nil;NSString *text=RecognizeImage(rendered.CGImage,&error);
    Check(!error && [text.lowercaseString containsString:@"reload"],"frozen menu text must survive overlay rendering and remain readable by OCR");
    if(argc==2) {
        NSImage *scene=[[NSImage alloc] initWithSize:NSMakeSize(720,480)];[scene lockFocus];
        NSGradient *background=[[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedRed:0.94 green:0.95 blue:0.97 alpha:1] endingColor:[NSColor colorWithCalibratedRed:0.84 green:0.87 blue:0.91 alpha:1]];
        [background drawInRect:NSMakeRect(0,0,720,480) angle:-60];
        [[NSColor colorWithCalibratedWhite:1 alpha:0.95] setFill];[[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(60,112,600,300) xRadius:18 yRadius:18] fill];
        [@"工作空间" drawAtPoint:NSMakePoint(92,365) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:19 weight:NSFontWeightLight],NSForegroundColorAttributeName:[NSColor colorWithCalibratedWhite:0.20 alpha:1]}];
        [@"让文字自由流动。" drawAtPoint:NSMakePoint(92,338) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:12],NSForegroundColorAttributeName:NSColor.grayColor}];
        [@"Capture a better idea." drawAtPoint:NSMakePoint(92,281) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:17 weight:NSFontWeightLight],NSForegroundColorAttributeName:[NSColor colorWithCalibratedWhite:0.3 alpha:1]}];
        [@"Read. Select. Translate." drawAtPoint:NSMakePoint(92,254) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:12],NSForegroundColorAttributeName:NSColor.grayColor}];
        [NSGraphicsContext saveGraphicsState];NSShadow *shadow=[NSShadow new];shadow.shadowOffset=NSMakeSize(0,-4);shadow.shadowBlurRadius=16;shadow.shadowColor=[NSColor colorWithCalibratedWhite:0 alpha:0.12];[shadow set];
        [NSColor.whiteColor setFill];[[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(376,155,252,218) xRadius:14 yRadius:14] fill];[NSGraphicsContext restoreGraphicsState];
        NSArray *labels=@[@"Reload Config",@"Open Config",@"Console…",@"Preferences…",@"Check for Updates…"];
        for(NSUInteger i=0;i<labels.count;i++) [labels[i] drawAtPoint:NSMakePoint(396,337-i*37) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:14],NSForegroundColorAttributeName:[NSColor colorWithCalibratedWhite:0.2 alpha:1]}];
        [scene unlockFocus];CaptureView *preview=[[CaptureView alloc] initWithFrame:NSMakeRect(0,0,720,480)];preview.snapshot=scene;preview.dragging=YES;preview.selection=NSMakeRect(368,147,268,234);
        NSString *path=[NSString stringWithUTF8String:argv[1]];[NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
        Check([[Render(preview) representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES],"capture design preview must be saved");
    }
    puts("PASS: capture preserves original brightness and opaque pixels; selection and frozen menu text remain readable by OCR.");
}return 0;}
