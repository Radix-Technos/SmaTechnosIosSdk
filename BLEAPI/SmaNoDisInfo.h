

#import <Foundation/Foundation.h>

@interface SmaNoDisInfo : NSObject
//是否开启  0：关闭  1:开启
@property (nonatomic,strong) NSString *isOpen;
//开始时间
@property (nonatomic,strong) NSString *beginTime1;
//结束时间
@property (nonatomic,strong) NSString *endTime1;
//是否开启  0：关闭  1:开启
@property (nonatomic,strong) NSString *isOpen1;
//开始时间
@property (nonatomic,strong) NSString *beginTime2;
//结束时间
@property (nonatomic,strong) NSString *endTime2;
//是否开启  0：关闭  1:开启
@property (nonatomic,strong) NSString *isOpen2;
//开始时间
@property (nonatomic,strong) NSString *beginTime3;
//结束时间
@property (nonatomic,strong) NSString *endTime3;
//是否开启  0：关闭  1:开启
@property (nonatomic,strong) NSString *isOpen3;
//重复周
@property (nonatomic,strong) NSString *repeatWeek;
@end
