#import <CommonCrypto/CommonCrypto.h>

// Web protocol adapter, independently implemented with Foundation/CommonCrypto.
static NSData *WebMD5Data(NSString *value) {
    NSData *bytes=[value dataUsingEncoding:NSUTF8StringEncoding]; unsigned char digest[CC_MD5_DIGEST_LENGTH];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CC_MD5(bytes.bytes,(CC_LONG)bytes.length,digest);
#pragma clang diagnostic pop
    return [NSData dataWithBytes:digest length:sizeof(digest)];
}
static NSString *WebMD5(NSString *value) {
    NSMutableString *hex=[NSMutableString new];
    NSData *data=WebMD5Data(value);const unsigned char *bytes=data.bytes;
    for(NSUInteger i=0;i<data.length;i++) [hex appendFormat:@"%02x",bytes[i]];return hex;
}
static NSString *YoudaoLanguage(NSString *code) {
    return (@{@"zh-CN":@"zh-CHS",@"zh-TW":@"zh-CHT",@"fr":@"fr",@"iw":@"he"}[code] ?: code);
}
static NSError *YoudaoError(NSString *detail) {
    return [NSError errorWithDomain:@"Translation.Youdao" code:1 userInfo:@{NSLocalizedDescriptionKey:detail ?: @"有道网页版未返回有效译文，接口可能暂时不可用。"}];
}
static NSMutableDictionary *YoudaoParameters(NSString *key, NSString *keyID) {
    NSString *time=[NSString stringWithFormat:@"%.0f",NSDate.date.timeIntervalSince1970*1000];
    NSString *signature=WebMD5([NSString stringWithFormat:@"client=fanyideskweb&mysticTime=%@&product=webfanyi&key=%@",time,key]);
    return [@{@"client":@"fanyideskweb",@"product":@"webfanyi",@"appVersion":@"1.0.0",@"vendor":@"web",@"pointParam":@"client,mysticTime,product",@"keyfrom":@"fanyi.web",@"keyid":keyID,@"mysticTime":time,@"sign":signature} mutableCopy];
}
static NSMutableURLRequest *YoudaoRequest(NSDictionary *params, BOOL translate) {
    NSURLComponents *url=[NSURLComponents componentsWithString:translate ? @"https://dict.youdao.com/webtranslate" : @"https://dict.youdao.com/webtranslate/key"];
    NSMutableArray *items=[NSMutableArray new];for(NSString *name in params) [items addObject:[NSURLQueryItem queryItemWithName:name value:params[name]]];
    NSURLComponents *form=[NSURLComponents new];form.queryItems=items;
    if(!translate) url.percentEncodedQuery=form.percentEncodedQuery;
    NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:url.URL];
    static NSString *anonymousCookie;static dispatch_once_t once;dispatch_once(&once, ^{ anonymousCookie=[NSString stringWithFormat:@"OUTFOX_SEARCH_USER_ID=%u@127.0.0.1;",arc4random_uniform(2000000000)]; });
    [r setValue:anonymousCookie forHTTPHeaderField:@"Cookie"];
    [r setValue:@"https://fanyi.youdao.com/" forHTTPHeaderField:@"Referer"];
    [r setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36" forHTTPHeaderField:@"User-Agent"];
    if(translate) {
        r.HTTPMethod=@"POST";
        r.HTTPBody=[[form.percentEncodedQuery stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"] dataUsingEncoding:NSUTF8StringEncoding];
        [r setValue:@"application/x-www-form-urlencoded; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    }
    return r;
}
static NSString *YoudaoDecode(NSData *response, NSDictionary *keys) {
    NSString *encoded=[[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
    encoded=[[encoded stringByReplacingOccurrencesOfString:@"-" withString:@"+"] stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    while(encoded.length%4) encoded=[encoded stringByAppendingString:@"="];
    NSData *cipher=[[NSData alloc] initWithBase64EncodedString:encoded options:0];
    if(!cipher.length || ![keys[@"aesKey"] isKindOfClass:NSString.class] || ![keys[@"aesIv"] isKindOfClass:NSString.class]) return nil;
    NSData *key=WebMD5Data(keys[@"aesKey"]), *iv=WebMD5Data(keys[@"aesIv"]);
    NSMutableData *plain=[NSMutableData dataWithLength:cipher.length+kCCBlockSizeAES128];size_t count=0;
    if(CCCrypt(kCCDecrypt,kCCAlgorithmAES,kCCOptionPKCS7Padding,key.bytes,key.length,iv.bytes,cipher.bytes,cipher.length,plain.mutableBytes,plain.length,&count)!=kCCSuccess) return nil;
    plain.length=count;id json=[NSJSONSerialization JSONObjectWithData:plain options:0 error:nil];
    if(![json isKindOfClass:NSDictionary.class] || [json[@"code"] integerValue]!=0 || ![json[@"translateResult"] isKindOfClass:NSArray.class]) return nil;
    NSMutableString *text=[NSMutableString new];
    for(id group in json[@"translateResult"]) if([group isKindOfClass:NSArray.class]) for(id segment in group) if([segment isKindOfClass:NSDictionary.class] && [segment[@"tgt"] isKindOfClass:NSString.class]) [text appendString:segment[@"tgt"]];
    return text.length ? text : nil;
}
