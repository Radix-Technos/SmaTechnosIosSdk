//
//  AFNetRequestManager.m
//  10T
//
//  Created by 有限公司 深圳市 on 2018/5/15.
//  Copyright © 2018年 SMA. All rights reserved.
//

#import "AFNetRequestManager.h"
#import <CommonCrypto/CommonDigest.h>
#import "AFNetworking.h"

/*上线需要切换服务器*/
//static NSString *const ServerURL = @"http://iottest.adups.com";   //Test server
static NSString *const ServerURL = @"http://iotapi.adups.com";   //Official server


static RequestType sma_requestType = RequestTypeJSON;
static ResponseType sma_responseType = ResponseTypeJSON;

@implementation AFNetRequestManager

+ (void)configRequestType:(RequestType)requestType {
    sma_requestType = requestType;
}

+ (void)configResponseType:(ResponseType)responseType {
    sma_responseType = responseType;
}

+ (NSURLSessionDataTask *)getWithURL:(NSString *)URLString parameters:(NSDictionary *)parameters success:(ResponseSuccess)success fail:(ResponseFail)fail {
    return [[self SMAmanager] GET:URLString parameters:parameters headers:nil progress:^(NSProgress * _Nonnull downloadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        if (success) {
            success(responseObject);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if (fail) {
            fail(error);
        }
    }];
    
}

+ (NSURLSessionDataTask *)postWithURL:(NSString *)URLString parameters:(NSDictionary *)parameters success:(ResponseSuccess)success fail:(ResponseFail)fail {
    NSString *url = [NSString stringWithFormat:@"%@/%@",ServerURL,URLString];
    NSLog(@"url==%@",url);
    return [[self SMAmanager] POST:url parameters:parameters headers:nil progress:^(NSProgress * _Nonnull uploadProgress) {
        NSLog(@"uploadprogress--%@",uploadProgress);  //    请求进度
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        if (success) {
      
            success(responseObject);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if (fail) {
            fail(error);
        }
    }];
}

+ (NSURLSessionDownloadTask *)DownloadFileWithURL:(NSString *)UrlString Success:(ResponseSuccess)success fail:(ResponseFail)fail {
    /* 创建网络下载对象 */
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    /* 下载地址 */
    NSURL *url = [NSURL URLWithString:UrlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    /* 下载路径 */
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *filePath = [path stringByAppendingPathComponent:url.lastPathComponent];
    
    /* 开始请求下载 */
    NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
        
        NSLog(@"下载进度：%.0f％", downloadProgress.fractionCompleted * 100);
        
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        
        /* 设定下载到的位置 */
        return [NSURL fileURLWithPath:filePath];
        
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        
        NSLog(@"下载完成--%@",filePath);
        if (error) {
            if (fail) {
                fail(error);
            }
        }else {
            if (success) {
                success(filePath);
            }
        }
        
    }];
    [downloadTask resume];
    return downloadTask;
    
}


#pragma mark - MD5 加密
+ (NSString *)md5:(NSString *)input {
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5( data.bytes, (unsigned int)data.length, digest );
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    
    return output;
}

#pragma mark - SHA1 加密
+ (NSString *)sha1:(NSString *)input {
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (unsigned int)data.length, digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for(int i=0; i<CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    
    return output;
}
#pragma mark - AFNetworking
+ (AFHTTPSessionManager *)SMAmanager{
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json",@"text/json",@"text/javascript",@"text/html",nil];

    switch (sma_requestType) {
        case RequestTypeJSON: {
            manager.requestSerializer = [AFJSONRequestSerializer serializer];
            [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
            break;
        }
        case RequestTypePlainText: {
            manager.requestSerializer = [AFHTTPRequestSerializer serializer];
            break;
        }
    }

    switch (sma_responseType) {
        case ResponseTypeJSON: {
            AFJSONResponseSerializer *serial = [AFJSONResponseSerializer serializer];
         //   [serial setRemovesKeysWithNullValues:YES];
            [manager setResponseSerializer:serial];
            break;
        }
        case ResponseTypeXML: {
            manager.responseSerializer = [AFXMLParserResponseSerializer serializer];
            break;
        }
        case ResponseTypeData: {
            manager.responseSerializer = [AFHTTPResponseSerializer serializer];
            break;
        }
    }

    manager.requestSerializer.stringEncoding = NSUTF8StringEncoding;
    manager.operationQueue.maxConcurrentOperationCount = 3;

    //重新设置回默认值，只在需要改的地方调用configResquestType/configResponseType
    sma_requestType = RequestTypeJSON;
    sma_responseType = ResponseTypeJSON;
    return manager;
}

#pragma mark - 公有方法，直接使用
//类型识别:将所有的NSNull类型转化成@""
+(id)changeType:(id)myObj
{
    if ([myObj isKindOfClass:[NSDictionary class]])
    {
        return [self nullDic:myObj];
    }
    else if([myObj isKindOfClass:[NSArray class]])
    {
        return [self nullArr:myObj];
    }
    else if([myObj isKindOfClass:[NSString class]])
    {
        return [self stringToString:myObj];
    }
    else if([myObj isKindOfClass:[NSNull class]])
    {
        return [self nullToString];
    }
    else
    {
        return myObj;
    }
}

#pragma mark - 私有方法
//将NSDictionary中的Null类型的项目转化成@""
+(NSDictionary *)nullDic:(NSDictionary *)myDic
{
    NSArray *keyArr = [myDic allKeys];
    NSMutableDictionary *resDic = [[NSMutableDictionary alloc]init];
    for (int i = 0; i < keyArr.count; i ++)
    {
        id obj = [myDic objectForKey:keyArr[i]];
        obj = [self changeType:obj];
        [resDic setObject:obj forKey:keyArr[i]];
    }
    return resDic;
}

//将NSArray中的Null类型的项目转化成@""
+(NSArray *)nullArr:(NSArray *)myArr
{
    NSMutableArray *resArr = [[NSMutableArray alloc] init];
    for (int i = 0; i < myArr.count; i ++)
    {
        id obj = myArr[i];
        obj = [self changeType:obj];
        [resArr addObject:obj];
    }
    return resArr;
}

//将NSString类型的原路返回
+(NSString *)stringToString:(NSString *)string
{
    return string;
}

//将Null类型的项目转化成@""
+(NSString *)nullToString
{
    return @"<NSNull>";
}


+(NSString *)getNowTimeTimestamp2{
    
    
    
    NSDate* dat = [NSDate dateWithTimeIntervalSinceNow:0];
    
    NSTimeInterval a=[dat timeIntervalSince1970];
    
    NSString*timeString = [NSString stringWithFormat:@"%0.f", a];//转为字符型
 
    return timeString;
    
}

+ (NSString *)hmac_MD5:(NSString *)plaintext withKey:(NSString *)key
{
    const char *cKey  = [key cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cData = [plaintext cStringUsingEncoding:NSUTF8StringEncoding];
    const unsigned int blockSize =64;   //散列函数的分割数据长度为64
    char ipad[blockSize];
    char opad[blockSize];
    char keypad[blockSize];
    
    unsigned int keyLen = strlen(cKey); //密钥的长度
    CC_MD5_CTX ctxt;
    if (keyLen > blockSize) {  //密钥长度大于分割数据长度，则先进行md5运算，运算结果拷贝到keypad中
        CC_MD5_Init(&ctxt);
        CC_MD5_Update(&ctxt, cKey, keyLen);
        CC_MD5_Final((unsigned char *)keypad, &ctxt);
        keyLen = CC_MD5_DIGEST_LENGTH;  //使keylength为16字节
    }
    else {
        memcpy(keypad, cKey, keyLen);  //否则直接拷贝到keypad字符串中
    }
    
    memset(ipad,0x36, blockSize);  //设置ipad为0x36
    memset(opad,0x5c, blockSize);  //设置opad为0x5c
    
    int i;
    for (i =0; i < keyLen; i++) {
        ipad[i] ^= keypad[i];   //keypad与ipad做异或运算
        opad[i] ^= keypad[i];   //可以pad与opad做异或运算
    }
    
    //将ipad加入到ctxt中，再将cdata加入到ctxt中，进行md5运算,结果放入md5字符串中
    CC_MD5_Init(&ctxt);
    CC_MD5_Update(&ctxt, ipad, blockSize);
    CC_MD5_Update(&ctxt, cData,strlen(cData));
    unsigned char md5[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(md5, &ctxt);
    
    //将opad加入到ctxt中，再将上一步的md5加入到ctxt中，进行md5运算，结果放入md5字符串中
    CC_MD5_Init(&ctxt);
    CC_MD5_Update(&ctxt, opad, blockSize);
    CC_MD5_Update(&ctxt, md5,CC_MD5_DIGEST_LENGTH);
    CC_MD5_Final(md5, &ctxt);
    
    //转成16进制
    const unsigned int hex_len =CC_MD5_DIGEST_LENGTH*2+2;
    char hex[hex_len];
    for(i =0; i < CC_MD5_DIGEST_LENGTH; i++) {
        snprintf(&hex[i*2], hex_len-i*2,"%02x", md5[i]);
    }
    
    NSData *HMAC = [[NSData alloc] initWithBytes:hex length:strlen(hex)];
    NSString *hash = [[NSString alloc] initWithData:HMAC encoding:NSUTF8StringEncoding];
    
    return hash;
}
@end















