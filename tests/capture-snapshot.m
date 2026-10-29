#define main YiApplicationMain
#import "../Sources/main.m"
#undef main
static void Check(BOOL ok,const char *message){ if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);} }
int main(void){ @autoreleasepool {
    NSBitmapImageRep *blank=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:100 pixelsHigh:100 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    memset(blank.bitmapData,0,blank.bytesPerRow*blank.pixelsHigh);
    Check(!CaptureBitmapHasVisiblePixels(blank),"blank screen frame must not become an opaque black capture panel");
    memset(blank.bitmapData,255,blank.bytesPerRow*blank.pixelsHigh);
    NSBitmapImageRep *owned=CopyCaptureBitmap(blank.CGImage);
    memset(blank.bitmapData,0,blank.bytesPerRow*blank.pixelsHigh);
    Check(CaptureBitmapHasVisiblePixels(owned),"snapshot must retain independent pixels after its source buffer changes");
    for(NSNumber *factor in @[@1,@2]) {
        NSInteger scale=factor.integerValue;
        NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:200*scale pixelsHigh:100*scale bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        // Distinct top/bottom and left/right pixels expose flipped or offset crops.
        for(NSInteger y=0;y<100*scale;y++) for(NSInteger x=0;x<200*scale;x++) {
            NSUInteger rgba[4]={x<100*scale ? 255 : 0,y<50*scale ? 255 : 0,0,255}; [bitmap setPixel:rgba atX:x y:y];
        }
        CaptureFrame *source=[CaptureFrame new]; source.frame=NSMakeRect(-300,150,200,100); source.bitmap=CopyCaptureBitmap(bitmap.CGImage);
        CGImageRef crop=CreateCaptureCrop(source,NSMakeRect(-290,220,40,20));
        Check(crop && CGImageGetWidth(crop)==40*scale && CGImageGetHeight(crop)==20*scale,"crop must respect Retina scale and negative display coordinates");
        NSBitmapImageRep *result=[[NSBitmapImageRep alloc] initWithCGImage:crop]; NSUInteger pixel[4]; [result getPixel:pixel atX:0 y:0];
        Check(pixel[0]==255 && pixel[1]==255,"AppKit top selection must map to top image pixels"); CGImageRelease(crop);
        crop=CreateCaptureCrop(source,NSMakeRect(-180,160,40,20));
        result=[[NSBitmapImageRep alloc] initWithCGImage:crop]; [result getPixel:pixel atX:0 y:0];
        Check(pixel[0]==0 && pixel[1]==0,"bottom-right selection must not be flipped or shifted"); CGImageRelease(crop);
        Check(!CreateCaptureCrop(source,NSZeroRect) && !CreateCaptureCrop(source,NSMakeRect(500,500,20,20)),"empty/outside selection must be rejected");
    }
    puts("PASS: frozen-image crops preserve pixel position, orientation, Retina scaling and secondary-display coordinates; invalid selection rejected.");
} return 0; }
