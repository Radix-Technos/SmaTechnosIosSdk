//
//  SmaSeatInfo.h
//  SmaLife
//
//  Created by 有限公司 深圳市 on 15/4/14.
//  Copyright (c) 2015年 SmaLife. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SmaSeatInfo : NSObject<NSCoding>
//是否开启  0：关闭  1:开启
@property (nonatomic,strong) NSString *isOpen;
//步数阈值 （0~65535）
@property (nonatomic,strong) NSString *stepValue;
//检测周期（0~255）
@property (nonatomic,strong) NSString *seatValue;
//开始时间
@property (nonatomic,strong) NSString *beginTime0;
//结束时间
@property (nonatomic,strong) NSString *endTime0;
//是否开启提醒0
@property (nonatomic,strong) NSString *isOpen0;
//开始时间
@property (nonatomic,strong) NSString *beginTime1;
//结束时间
@property (nonatomic,strong) NSString *endTime1;
//是否开启提醒1
@property (nonatomic,strong) NSString *isOpen1;
//重复周
@property (nonatomic,strong) NSString *repeatWeek;//循环周期 @"124" (1111100 的十进制);代表周一到周六开启，周末关闭

@end
