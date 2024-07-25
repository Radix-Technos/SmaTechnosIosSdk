//
//  DfuUpdate.m
//  SMABLE
//
//  Created by 有限公司 深圳市 on 2017/1/4.
//  Copyright © 2017年 SMA BLE. All rights reserved.
//

#import "DfuUpdate.h"

@implementation DfuUpdate
@synthesize firmware,dfuController;
static id _instace;

+ (instancetype)sharedDfuUpdate
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instace = [[self alloc] init];
    });
    return _instace;
}

+ (id)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instace = [super allocWithZone:zone];
    });
    return _instace;
}

- (id)copyWithZone:(NSZone *)zone
{
    return _instace;
}

- (id)init{
    self = [super init];
    if (self) {
//        iNum = 0;
//        dfuOperations = [[DFUOperations alloc] initWithDelegate:self];
//        dfuHelper = [[DFUHelper alloc] initWithData:dfuOperations];
    }
    return self;
}

- (void)setFileUrl:(NSURL *)fileUrl{
    _fileUrl = fileUrl;
    [self onFileSelected:_fileUrl];
}

-(void)onFileSelected:(NSURL *)url{
    NSString *fineName = [[NSBundle mainBundle] pathForResource: @"sma10b_firmware_v1.1.8" ofType:@"zip"];
//    url=[[NSURL alloc] initWithString:fineName];
    NSString *selectedFileName = [[url path] lastPathComponent];
    NSString *extension = [selectedFileName substringFromIndex: [selectedFileName length] - 3];
    if ([extension isEqualToString:@"zip"]) {
        firmware = [[DFUFirmwareBle alloc] initWithUrlToZipFile:url];
    }
}

- (void)performDFUwithManager:(CBCentralManager *)manager periphral:(CBPeripheral *)p{
    NSLog(@"performDFUwithManager===%@",p);
    DFUServiceInitiatorBle *initiator = [[DFUServiceInitiatorBle alloc] initWithCentralManager:manager target:p];
    initiator.forceDfu = YES;
    initiator.packetReceiptNotificationParameter = 12;
    initiator.delegate = self;
    initiator.logger = self;
    initiator.progressDelegate = self;
    [initiator withFirmware:firmware];
    dfuController = [initiator start];
}

- (void)abort{
    [dfuController abort];
}

- (void)logWith:(enum LogLevel)level message:(NSString * _Nonnull)message{
    if (self.dfuDelegate && [self.dfuDelegate respondsToSelector:@selector(dfuUploadlogWith:message:)]) {
        [self.dfuDelegate dfuUploadlogWith:level message:message];
    }
}

- (void)dfuStateDidChangeTo:(enum DFUState)state{
     
    if (state == 6 || state == 7) {
        self.dfuMode = NO;
    }
    if (self.dfuDelegate && [self.dfuDelegate respondsToSelector:@selector(dfuUploadStateDidChangeTo:)]) {
        [self.dfuDelegate dfuUploadStateDidChangeTo:state];
    }
}


- (void)dfuError:(enum DFUError)error didOccurWithMessage:(NSString *)message{
    self.dfuMode = NO;
    if (self.dfuDelegate && [self.dfuDelegate respondsToSelector:@selector(dfuUploadError:didOccurWithMessage:)]) {
        [self.dfuDelegate dfuUploadError:error didOccurWithMessage:message];
    }
    NSLog(@"dfuError %ld  didOccurWithMessage %@",(long)error,message);
}

- (void)dfuProgressDidChangeFor:(NSInteger)part outOf:(NSInteger)totalParts to:(NSInteger)progress currentSpeedBytesPerSecond:(double)currentSpeedBytesPerSecond avgSpeedBytesPerSecond:(double)avgSpeedBytesPerSecond{
    if (self.dfuDelegate && [self.dfuDelegate respondsToSelector:@selector(dfuUploadProgressDidChangeFor:outOf:to:currentSpeedBytesPerSecond:avgSpeedBytesPerSecond:)]) {
        [self.dfuDelegate dfuUploadProgressDidChangeFor:part outOf:totalParts to:progress currentSpeedBytesPerSecond:currentSpeedBytesPerSecond avgSpeedBytesPerSecond:avgSpeedBytesPerSecond];
    }
    NSLog(@"dfuProgressDidChangeFor %ld ; outOf %ld ; \n to %ld ; currentSpeedBytesPerSecond %f ; avgSpeedBytesPerSecond %f",(long)part,(long)totalParts,(long)progress,currentSpeedBytesPerSecond,avgSpeedBytesPerSecond);
}

@end
