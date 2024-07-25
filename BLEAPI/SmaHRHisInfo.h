

#import <Foundation/Foundation.h>

@interface SmaHRHisInfo : NSObject
@property (nonatomic,strong) NSString *dayFlags;   //循环周期 @"124" (1111100 的十进制);代表周一到周六开启，周末关闭
@property (nonatomic,strong) NSString *beginhour0; //第一个心率设置开启时间，可通过isopen0决定是否开启
@property (nonatomic,strong) NSString *endhour0;   //第一个心率设置结束时间，可通过isopen0决定是否开启
@property (nonatomic,strong) NSString *beginhour1; //第二个心率设置开启时间，可通过isopen1决定是否开启
@property (nonatomic,strong) NSString *endhour1;   //第二个心率设置结束时间，可通过isopen1决定是否开启
@property (nonatomic,strong) NSString *beginhour2; //第三个心率设置开启时间，可通过isopen2决定是否开启
@property (nonatomic,strong) NSString *endhour2;   //第三个心率设置结束时间，可通过isopen2决定是否开启
@property (nonatomic,strong) NSString *tagname; //检测周期
@property (nonatomic,strong) NSString *isopen;  //是否开启（开启时若子开头也开启，心率才会开启，若关闭则所有心率设置均关闭）
@property (nonatomic,strong) NSString *isopen0; //是否开启
@property (nonatomic,strong) NSString *isopen1; //是否开启
@property (nonatomic,strong) NSString *isopen2; //是否开启
//@property (nonatomic,strong) NSString *nextDay; //是否跨天
@end
