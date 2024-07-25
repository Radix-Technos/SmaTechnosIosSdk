//
//  AFNetRequestManager.h
//  10T
//
//  Created by zshuo50 on 2018/5/15.
//  Copyright © 2018年 SMA. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef void (^ResponseSuccess)(id responseObject);
typedef void (^ResponseFail)(NSError *error);

typedef NS_ENUM(NSUInteger, RequestType) {  //请求类型
    RequestTypeJSON = 1,    //JSON
    RequestTypePlainText   //默认，普通text/plain
};

typedef NS_ENUM(NSUInteger, ResponseType) {  //输出类型
    ResponseTypeJSON = 1,  //默认JSON
    ResponseTypeXML,       //XML
    ResponseTypeData       //Data  二进制数据
};


@interface AFNetRequestManager : NSObject

+ (void)configRequestType:(RequestType)requestType;
+ (void)configResponseType:(ResponseType)responseType;

#pragma mark - 请求接口数据  Get/Post
+ (NSURLSessionDataTask *)getWithURL:(NSString *)URLString parameters:(NSDictionary *)parameters success:(ResponseSuccess)success fail:(ResponseFail)fail;

+ (NSURLSessionDataTask *)postWithURL:(NSString *)URLString parameters:(NSDictionary *)parameters success:(ResponseSuccess)success fail:(ResponseFail)fail;

+ (NSURLSessionDownloadTask *)DownloadFileWithURL:(NSString *)UrlString Success:(ResponseSuccess)success fail:(ResponseFail)fail;

//Get the current timestamp (seconds)
+(NSString *)getNowTimeTimestamp2;

//hmacmd5
+ (NSString *)hmac_MD5:(NSString *)plaintext withKey:(NSString *)key;
@end
