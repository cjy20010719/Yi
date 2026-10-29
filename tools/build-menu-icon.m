#import <Cocoa/Cocoa.h>
int main(void) { @autoreleasepool {
    // Derive the menu mark from the supplied artwork, preserving its exact silhouette.
    NSImage *art=[[NSImage alloc] initWithContentsOfFile:@"Assets/Yi.png"];
    NSBitmapImageRep *source=[[NSBitmapImageRep alloc] initWithData:art.TIFFRepresentation];
    NSInteger w=source.pixelsWide,h=source.pixelsHigh;
    NSBitmapImageRep *mask=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:w pixelsHigh:h bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    NSInteger minX=w,minY=h,maxX=0,maxY=0;
    for(NSInteger y=0;y<h;y++) for(NSInteger x=0;x<w;x++) {
        NSColor *c=[[source colorAtX:x y:y] colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
        CGFloat darkness=1.0-MAX(c.redComponent,MAX(c.greenComponent,c.blueComponent));
        CGFloat alpha=c.alphaComponent*darkness;
        [mask setColor:[NSColor colorWithDeviceRed:0 green:0 blue:0 alpha:alpha] atX:x y:y];
        if(alpha>.15) {minX=MIN(minX,x);minY=MIN(minY,y);maxX=MAX(maxX,x);maxY=MAX(maxY,y);}
    }
    NSImage *silhouette=[[NSImage alloc] initWithSize:NSMakeSize(w,h)];[silhouette addRepresentation:mask];
    NSRect crop=NSMakeRect(minX,h-maxY-1,maxX-minX+1,maxY-minY+1);
    NSImage *mark=[NSImage imageWithSize:NSMakeSize(18,18) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        CGFloat scale=16/MAX(crop.size.width,crop.size.height);
        NSSize size=NSMakeSize(crop.size.width*scale,crop.size.height*scale);
        [silhouette drawInRect:NSMakeRect((18-size.width)/2,(18-size.height)/2,size.width,size.height) fromRect:crop operation:NSCompositingOperationSourceOver fraction:1];
        return YES;
    }];
    mark.template=YES;

    NSBitmapImageRep *output=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:72 pixelsHigh:72 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    [NSGraphicsContext saveGraphicsState];[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:output]];
    [mark drawInRect:NSMakeRect(0,0,72,72) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1];
    [NSGraphicsContext restoreGraphicsState];
    NSData *png=[output representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return [png writeToFile:@"Assets/MenuBarIcon.png" atomically:YES] ? 0 : 1;
} }
