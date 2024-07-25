

#import <Foundation/Foundation.h>

@interface SmaAlarmInfo : NSObject
@property (nonatomic,strong) NSString *dayFlags; //循环周期 @"124" (1111100 的十进制);代表周一到周六开启，周末关闭
@property (nonatomic,strong) NSString *aid;      //闹钟编号
@property (nonatomic,strong) NSString *minute;   //分钟
@property (nonatomic,strong) NSString *hour;     //小时
@property (nonatomic,strong) NSString *day;      //日期
@property (nonatomic,strong) NSString *mounth;   //月份
@property (nonatomic,strong) NSString *year;     //年份
@property (nonatomic,strong) NSString *tagname;  //闹钟名字(限07)
@property (nonatomic,strong) NSString *isOpen;   //是否开启
@property (nonatomic,strong) NSString *isWeb;    //是否同步服务器
@end
