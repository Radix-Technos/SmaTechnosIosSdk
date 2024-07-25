

#import <Foundation/Foundation.h>

@interface SmaVibrationInfo : NSObject
/*
 @“1”  绑定
 @“2”  绑定完成
 @“3”  消息提醒
 @“4”  来电提醒
 @“5”  闹钟
 @“6”  久坐
 @“7”  拍照
 @“8”  丢失
 @“9”  有氧运动
 @“10” 激烈运动
 */
@property (nonatomic, strong) NSString *type;  //震动类型
@property (nonatomic, strong) NSString *level; //预留
@property (nonatomic, strong) NSString *freq;  //震动次数（0~15）
@end
