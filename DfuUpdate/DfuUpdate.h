//
//  DfuUpdate.h
//  SMABLE
//
//  Created by 有限公司 深圳市 on 2017/1/4.
//  Copyright © 2017年 SMA BLE. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import <iOSDFULibrary/iOSDFULibrary-Swift.h>
@import iOSDFULibrary;

@protocol DfuUpdateDelegate <NSObject>
- (void)dfuUploadlogWith:(LogLevel)level message:(NSString *)message;
- (void)dfuUploadStateDidChangeTo:( DFUState)state;
- (void)dfuUploadError:(DFUError)error didOccurWithMessage:(NSString *)message;
- (void)dfuUploadProgressDidChangeFor:(NSInteger)part outOf:(NSInteger)totalParts to:(NSInteger)progress currentSpeedBytesPerSecond:(double)currentSpeedBytesPerSecond avgSpeedBytesPerSecond:(double)avgSpeedBytesPerSecond;
@end

@interface DfuUpdate : NSObject<DFUServiceDelegate,DFUProgressDelegate,LoggerDelegate>
@property (strong, nonatomic) DFUFirmwareBle *firmware;
@property (strong, nonatomic) DFUServiceControllerBle *dfuController;
@property (strong, nonatomic) NSURL *fileUrl;
@property (assign, nonatomic) BOOL dfuMode;
@property (weak,   nonatomic) id<DfuUpdateDelegate> dfuDelegate;
+ (instancetype)sharedDfuUpdate;
- (void)performDFUwithManager:(CBCentralManager *)manager periphral:(CBPeripheral *)p;
- (void)abort;
@end
