#define main YiApplicationMain
#import "../Sources/main.m"
#undef main
static void Require(BOOL condition,const char *message) { if(!condition) { fprintf(stderr,"FAIL: %s\n",message); exit(1); } }
static void Put(NSPasteboard *board,NSString *text) { [board clearContents]; [board setString:text forType:NSPasteboardTypeString]; }
int main(void) {
    @autoreleasepool {
        CompatibilityReader *reader=[CompatibilityReader new]; reader.pasteboard=[NSPasteboard pasteboardWithUniqueName];
        NSPasteboard *board=reader.pasteboard;
        NSPasteboardItem *original=[NSPasteboardItem new]; NSData *binary=[NSData dataWithBytes:"\0\1\2\3" length:4];
        [original setString:@"old clipboard must not be translated" forType:NSPasteboardTypeString]; [original setData:binary forType:@"test.binary"];
        [board clearContents]; Require([board writeObjects:@[original]],"original clipboard fixture must be written successfully");
        __block BOOL completed=NO;
        [reader readCopy:^BOOL{ Put(board,@"Change visibility"); return YES; } valid:^BOOL{ return YES; } completion:^(NSString *text){
            completed=YES; Require([text isEqual:@"Change visibility"],"only the freshly copied selection should be returned");
        }];
        Require(completed && [[board stringForType:NSPasteboardTypeString] isEqual:@"old clipboard must not be translated"] && [[board dataForType:@"test.binary"] isEqual:binary],"all original clipboard formats must be restored");
        [reader readCopy:^BOOL{ Put(board,@"/tmp/file"); [board setString:@"file:///tmp/file" forType:NSPasteboardTypeFileURL]; return YES; } valid:^BOOL{ return YES; } completion:^(NSString *text){ Require(!text,"file copies must not become translations"); }];
        [reader readCopy:^BOOL{ return NO; } valid:^BOOL{ return YES; } completion:^(NSString *text){ Require(!text,"failed Copy must not translate the previous clipboard"); }];
        __block BOOL valid=YES;
        [reader readCopy:^BOOL{ Put(board,@"newer user copy"); valid=NO; return YES; } valid:^BOOL{ return valid; } completion:^(NSString *text){ Require(!text,"invalidated context must not publish a selection"); }];
        Require([[board stringForType:NSPasteboardTypeString] isEqual:@"newer user copy"],"a newer user copy must never be overwritten");
        valid=YES; Put(board,@"unchanged clipboard"); completed=NO;
        [reader readCopy:^BOOL{ return YES; } valid:^BOOL{ return YES; } completion:^(NSString *text){
            Require(!text,"a no-op Copy must time out instead of translating old clipboard contents"); completed=YES;
            Require([[board stringForType:NSPasteboardTypeString] isEqual:@"unchanged clipboard"],"timeout must preserve old clipboard");
            [board releaseGlobally]; puts("PASS: fresh-copy only, full-format restoration, file rejection, failed/no-op copy, and newer-copy protection."); exit(0);
        }];
        Require(!completed && reader.busy,"no-op copy must wait for a real clipboard change");
        [NSRunLoop.mainRunLoop run];
    }
    return 0;
}
