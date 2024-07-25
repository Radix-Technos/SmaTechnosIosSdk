

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "SmaSeatInfo.h"
#import "SmaHRHisInfo.h"
#import "SmaAlarmInfo.h"
#import "SmaBusinessTool.h"
#import "SmaNoDisInfo.h"
#import "SmaVibrationInfo.h"
#import "SMAWeatherInfo.h"

typedef enum {
    SMA_EXERCISE_TYPE_RUNNING=0,
    SMA_EXERCISE_TYPE_CYCLING
}SMA_EXERCISE_TYPE;

typedef enum {
    SMA_EXERCISE_STATE_STOPPED=0,
    SMA_EXERCISE_STATE_STARTED,
    SMA_EXERCISE_STATE_GOING
}SMA_EXERCISE_STATE;

typedef enum {
    BAND =0,      //绑定信息
    LOGIN ,       //登录
    SPORTDATA,    //运动数据
    SLEEPDATA,    //睡眠数据
    SLEEPSETDATA, //睡眠设定数据
    SETSLEEPAIDS, //设置睡眠辅助监测（07）
    ALARMCLOCK,   //闹钟列表
    SYSTEMTIME,   //系统时间
    ELECTRIC,     //电量
    VERSION,      //系统版本
    OTA,          //是否进入OTA
    BOTTONSTYPE,  //按键返回
    MAC,          //MAC返回
    WATHEARTDATA, //手表心率返回
    CUFFSPORTDATA,  //07运动数据
    CUFFHEARTRATE,  //心率数据(05、07)
    CUFFSLEEPDATA,  //07睡眠数据
    CYCLINGDATA,    //骑行数据（B2）
    BLUTDRUCK,      //血压
    WATCHFACE,     //获取设备表盘（10-A）
    XMODEM,          //进入XODEM模式（10-A）
    RUNMODE,         //运动模式
    NOTIFICATION,    //更改通知
    GOALCALLBACK,   //运动目标返回
    LONGTIMEBACK,   //久坐设置返回
    FINDPHONE,      //寻找手机
    GPS,            //GPS数据
    SWIM,            //游泳数据
    EXERCISE        //Exercise change state (Real time)
}SMA_INFO_MODE;
/*
 @param BAND            反馈绑定信息，反馈数组内若为1，绑定成功，若为0，绑定失败
 @param LOGIN           反馈登录信息，反馈数组内若为1，登录成功，若为0，登录失败
 @param SPORTDATA       反馈运动数据信息，反馈数组参数
 sport_date：运动日期
 sport_steps：运动步数，sport_cal：消耗卡路里（单位：cal/10000）
 sport_dist：运动距离（单位：m）
 sport_time：运动时间（单位：m/15）
 sport_actTime：运动时间
 @param SLEEPDATA       反馈睡眠数据，反馈数组参数
 sleep_date：睡眠日期
 sleep_timeStamp：睡眠反馈时间（从Date 0点开始的分钟数。此值可能会大于 1440(24小时*60分钟=1440分钟),如果大 于1440,则表示为隔天的时间）
 sleep_mode：睡眠类型（1：深睡，2：浅睡，3：未进入睡眠）详细描述：1-3深睡到未睡---深睡时间；2-1清醒到深睡---浅睡时间；2-3清醒到未睡---浅睡时间；3-2未睡到清醒---清醒时间
 @param SLEEPSETDATA    反馈睡眠设定数据，反馈数组参数
 sleep_date：睡眠日期
 sleep_timeStamp：睡眠设定反馈时间（从Date 0点开始的分钟数。此值可能会大于 1440(24小时*60分钟=1440分钟),如果大 于1440,则表示为隔天的时间）
 sleep_mode：睡眠设定类型（1：进入睡眠状态，2：退出睡眠状态）
 @param SETSLEEPAIDS    设置是否开启睡眠辅助监测功能，用于更准确判断用户是否戴表睡觉
 @param ALARMCLOCK      反馈闹钟数据，反馈数组参数，闹钟个数最多为8个，数组对象为SmaAlarmInfo
 @param SYSTEMTIME      反馈系统时间，反馈数组日期格式为：yyyyMMddHHmmss
 @param ELECTRIC        反馈设备电池电量，反馈数组为电量百分比
 @param VERSION         反馈设备系统版本
 @param OTA             反馈进入OTA状态信息，反馈数组若为1，进入成功，
 当数组同时反馈@[0,PowerIsNormal]，进入OTA失败，无错误信息，
 若反馈@[0,PowerIsTooLow]，进入OTA失败，电量过低
 @param BOTTONSTYPE        反馈设备按键，反馈数组为键类型 1:确定键（02系列上键） 2:返回键  17:(02系列下键)
 @param MAC             反馈设备MAC地址，反馈数组为--:--:--:--:--:--,若出现04:03:00:00:00:00,为错误地址，建议重启设备
 @param WATHEARTDATA    反馈05手表最后一次监测的心率数据
 @param CUFFSPORTDATA   反馈07手环运动数据，数据一次最多返回20组，若仍有运动数据，需要重新请求
 DATE：运动时间
 STEP：运动步数
 @param CUFFHEARTRATE   反馈07手环心率数据，数据一次最多返回20组，若仍有心率数据，需要重新请求
 DATE：心率监测时间
 HEART：监测到的心率数值
 @param CUFFSLEEPDATA   反馈07手环睡眠数据，数据一次最多返回20组，若仍有睡眠数据，需要重新请求
 DATE：睡眠监测时间
 MODE：睡眠类型（若返回17则为进入睡眠时刻数据，34则为退出睡眠时刻数据，1：深睡，2：浅睡，3：未进入睡眠）
 SOFTLY：睡眠时轻动响应次数
 STRONG：睡眠时剧动响应次数
 @param BLUTDRUCK       反馈血压数据
 DATE: 时间
 SHRINK：收缩压
 RELAXATION：舒张压
 @param CYCLINGDATA     反馈B2系列骑行模式下数据 MODE 0：开始 2：结束
 DATE: 时间
 CAL: 卡路里
 HEART: 心率
 @param CUFFSWITCHS     反馈10系列手表表盘编号
 @param XMODEM          10系列进入XMODE模式（用于表盘切换）
 @param RUNMODE         反馈10系列运动模式下数据 MODE 32：开始 33：运动中  47：结束 （&&&&**i-Med 定制项目 48：6m开始  49：12m开始 63：结束 ****Version = 1 V1版本运动数据，Version = 2 V2版本运动数据 ****&&&&
 @param NOTIFICATION    R1系列设备更改通知（@"96":闹钟设置更改通知； @"97":计步目标更改通知; @"100":久坐设置更改通知; @"103":手表相机界面开启通知）
 @param GOALCALLBACK    R1系列设备运动目标返回
 @param NOTIFICATION    R1系列设备久坐设置返回
 @param FINDPHONE       R1系列设备寻找手机指令返回（@"0":关闭寻找手机； @"1"/@"2":蜂鸣强度）
 */

@protocol SmaCoreBlueToolDelegate <NSObject>

@optional
/*发送指令序号标识，用于识别应答数据指令序号
 @param identifier 接收到应答数据反馈指令序号标识
 @discussion       当向设备发送一条指令（如设置系统时间指令：setSystemTime），当应用程序调用:handleResponseValue:后回调
 */
- (void)sendIdentifier:(int)identifier;

/*数据反馈处理
 @param mode     数据属于的类型枚举：SMA_INFO_MODE
 @param array    数据处理数组，组合类型查看DEMO
 @discussion     将设备反馈数据进行处理，并通过反馈数据类型：mode来区分属于哪类数据（如：睡眠数据，运动数据），当应用程序调用:handleResponseValue:后回调
 */
- (void)bleDataParsingWithMode:(SMA_INFO_MODE)mode dataArr:(NSMutableArray *)array Checkout:(BOOL)check;

/*
 @param type    exercise type: SMA_EXERCISE_TYPE
 @param state   exercise state: SMA_EXERCISE_STATE
 */
- (void)onExerciseType:(SMA_EXERCISE_TYPE) type changeWithState:(SMA_EXERCISE_STATE) state;

/*数据发送超时
 @param mode     数据属于的类型枚举：SMA_INFO_MODE
 */
- (void)sendBLETimeOutWithMode:(SMA_INFO_MODE)mode;
//更新进度（表盘）
- (void)updateProgress:(float)pregress;
- (void)updateProgressEnd:(BOOL)success;
@end

@interface SmaBLE : NSObject
@property (nonatomic, assign, readonly) NSInteger serialNum;//发送指令序号标识
@property (nonatomic,strong)  CBPeripheral*p;//连接的设备
@property (nonatomic,strong)  CBCharacteristic*Write;//连接的设备的写特征
@property (nonatomic, weak) id<SmaCoreBlueToolDelegate> delegate;
@property (nonatomic, assign) BOOL isUPDateSwitch;
@property (nonatomic, assign) BOOL isUPDateFont;
+ (instancetype)sharedCoreBlue; //创建对象

/*处理设备反馈数据
 @param characteristic 设备更新数据特征
 @discussion           当应用程序触发:peripheral:didUpdateValueForCharacteristic:error:后调用
 */
- (void)handleResponseValue:(CBCharacteristic *)characteristic;

/*绑定手表
 @param userid 目前支持纯数字，如电话号码
 @discussion   用于向设备注册ID为userid的用户，以达到数据正常传输（运动，睡眠数据）
 */
-(void)bindUserWithUserID:(NSString *)userid;

/*解除绑定
 @discussion   解除用户绑定，清除设备内部设定用户数据
 */
-(void)relieveWatchBound;

/*登录命令
 @param userid 目前支持纯数字，如电话号码
 @discussion   登录用户ID必须为绑定设置的用户ID，否则导致数据无法同步（运动，睡眠数据）
 */
-(void)LoginUserWithUserID:(NSString *)userid;

/*退出登录
 @discussion   退出用户登录，可导致设备短时间断开连接
 */
-(void)logOut;

/*设置用户信息
 @param he    身高（cm）精确度为0.5cm
 @param we    体重 (kg) 精确度为0.5kg
 @param sex   性别 (0:女，1：男)
 @param age   年龄 （0~127）
 @discussion  向设备设置用户身高，体重，性别和年龄信息
 */
-(void)setUserMnerberInfoWithHeight:(float)he weight:(float)we sex:(int)sex age:(int)age;

/*设置系统时间
 @discussion  向设备设置手机当前时间
 */
-(void)setSystemTime;

/*设置防丢
 @param bol   YES:开启；NO:关闭
 */
-(void)setDefendLose:(BOOL)bol;


/**
 设置防丢提醒信息
 
 @param name 名字
 @param phone 电话号码
 */
- (void)setDefendLoseName:(NSString *)name phone:(NSString *)phone;

/** 相机开关
 *  @param bol   YES:开启；NO:关闭
 */
- (void)setBLcomera:(BOOL)bol;

/*手机来电
 @param bol YES:开启；NO:关闭
 */
-(void)setphonespark:(BOOL)bol;

/*短信
 @param bol YES:开启；NO:关闭
 */
-(void)setSmspark:(BOOL)bol;

/*设置记步目标
 @param count 步数
 */
-(void)setStepNumber:(int)count;

/*勿扰设置(05)
 @param bol YES:开启；NO:关闭
 */
- (void)setNoDisturb:(BOOL)bol;

/*背光设置(05、10)
 @param time 背光时间（0~10s）
 */
- (void)setBacklight:(int)time;

/*震动设置（05、10）
 @param freq 震动次数（0~10次）
 */
- (void)setVibrationFrequency:(int)freq;

/*震动设置（07、10）
 @param info 详见SmaVibrationInfo类
 */
- (void)setVibration:(SmaVibrationInfo *)info;

/*设置久坐
 @param week  传入类型如 @"0~127" 解析：124 即 1111100 的10进制;//代表周一到周五开启，周六、周日关闭
 @param begin 开始时间
 @param end   结束时间
 @param seat  久坐时间  如设置5分钟，将在以0分钟开始，每5分钟会检查一次久坐情况并不是从设置久坐后5分钟检查久坐情况
 */
-(void)seatLongTimeWithWeek:(NSString *)week beginTime:(int)begin endTime:(int)end seatTime:(int)seat;

/*关闭久坐
 */
-(void)closeLongTimeInfo;

/*  久坐提醒V2 */
-(void)seatLongTimeInfoV2:(SmaSeatInfo *)info;

/*设置闹钟
 @param smaACs 闹钟数组，对象类型为SmaAlarmInfo
 @discussion   闹钟各属性请参考SmaAlarmInfo描述,闹钟个数最多为八个
 */
-(void)setCalarmClockInfo:(NSMutableArray *)smaACs;

/*设置闹钟V2
 @param smaACs 闹钟数组，对象类型为SmaAlarmInfo
 @discussion   闹钟各属性请参考SmaAlarmInfo描述,闹钟个数最多为八个
 */
-(void)setClockInfoV2:(NSMutableArray *)smaACs;

/*数据同步
 @param bol YES:开启；NO:关闭
 @discussion   仅适用于02、04、05设备
 */
-(void)Syncdata:(BOOL)bol;

/*设置OTA
 @discussion 进入OTA升级指令，用于升级设备软件，请参考IOS-nRF-Toolbox-master.zip，技术支持网站https://developer.nordicsemi.com/nRF51_SDK/nRF51_SDK_v8.x.x/doc/8.0.0/s110/html/a00103.html
 */
-(void)setOTAstate;

/*设置APP数据
 @param cal    卡路里（cal）
 @param metre  路程（m）
 @param step   步数
 @discussion   向设备设置卡路里，路程，步数数据（仅适用于02，04，05设备）
 */
- (void)setAppSportDataWithcal:(float)cal distance:(int)metre stepNnumber:(int)step;

/*设置中英文(手环仅星期变化)
 @param lanNumber  0：中文（fit coach韩文）  1：英文 2：土耳其文 3：未定义 4：俄文 5：西班牙文  6：意大利 7：韩文 8：葡萄牙语 10：捷克语 
 */
- (void)setLanguage:(int)lanNumber;

/*设置心率（07）
 @parmar info  心率设置对像（请参考该对象参数）
 */
- (void)setHRWithHR:(SmaHRHisInfo *)info;

/*设置抬手亮（07）
 @parmar open  YES开启，NO关闭
 */
- (void)setLiftBright:(BOOL)open;

/*竖屏设置（07）
 @parmar open   YES开启，NO关闭
 */
- (void)setVertical:(BOOL)open;

/* 设置勿扰时间（07）
 @parmar info  勿扰设置对像（各参数请参考该对象参数）
 */
- (void)setNoDisInfo:(SmaNoDisInfo *)info;

/*设置睡眠辅助监测
 @parmar open  YES开启，NO关闭
 */
- (void)setSleepAIDS:(BOOL)open;

/*BEACON广播设置
 @parmar interval(0~225min) time(0~225s)
 */
- (void)setRadioInterval:(int)interval Continuous:(int)time;

/*12/24小时制设置
 @parmar hourly  YES 12小时制，NO 24小时制
 */
- (void)setHourly:(BOOL) hourly;

/*公英制设置
 @parmar british  YES 英制，NO 公制
 */
- (void)setBritishSystem:(BOOL)british;

/*设置天气单位
 @parmer unit yes-华氏度 no-摄氏度
 */
- (void)setWeatherUnit:(BOOL)unit;

/*高速模式
 @parmar open  YES开启，NO关闭
 */
- (void)setHighSpeed:(BOOL)open;

/*停止校时
 @discussion 让指针在校时过程中停止校时操作，当指针在校时过程中调用起作用
 */
- (void)setStopTiming;

/*准备校时
 @discussion 当不在校时过程中的指针停止走动
 */
- (void)setPrepareTiming;

/*取消校时
 @discussion 取消校时准备状态，在校时进行前起作用，校时过程中不起作用
 */
- (void)setCancelTiming;

/*指针位置
 @param hour    手表时针所在位置（0~11）
 @param min     手表分针所在位置（0~59）
 @param second  手表秒针所在位置（0~59）
 */
- (void)setPointerHour:(int)hour minute:(int)min second:(int)second;

/*根据系统时间校时
 @discussion 根据手表系统时间进行校时
 */
- (void)setSystemTiming;

/*指定时间校时
 @param hour    手表时针所在位置（0~11）
 @param min     手表分针所在位置（0~59）
 @param second  手表秒针所在位置（0~59）
 */
- (void)setCustomTimingHour:(int)hour minute:(int)min second:(int)second;

/*设置用户姓名及团队设定
 @param name 用户姓名
 @param group 用户团队
 @discussion i-Med 定制项目额外接口
 */
- (void)setNickName:(NSString *)name group:(NSString *)group;

/**
 @discussion ANCS配对请求
 */
- (void)setPairAncs;


/**
 设置系统是否为IOS系统
 
 @param system 1: android ; 2: iOS
 */
- (void)setPhoneSystemState:(int)system;


/**
 场馆欢迎消息推送
 
 @param venue 机场：1； 体育馆：2； 华尔街：3； 滑冰场：4； 曲棍球场：5； 冰球场：6； 双人滑雪场：7
 */
- (void)setVenue:(int)venue;


/**
 天气预报设置

 @param weather  天气预报设置对像（各参数请参考该对象参数）
 */
- (void)setWeatherForecast:(NSArray<SMAWeatherInfo *> *)weather;


/**
  天气设置

 @param weather 天气设置对像（各参数请参考该对象参数）
 */
- (void)setLiveWeather:(SMAWeatherInfo *)weathe;
/**
 GPS数据同步（B 系列无GPS）

 @param speed 速度 单位：Km/h
 @param elevation 海拔 单位：m
 @param distance 距离 单位 Km
 */
- (void)setGpsWithSpeed:(int)speed elevation:(int)elevation distance:(float)distance;

/**
 *GPS数据同步 （New）
 @param speed 速度 单位：Km/h
 @param elevation 海拔 单位：m
 @param distance 距离 单位 Km
 */
- (void)setGPSWithSpeed:(float)speed Altitude:(int)altitude Distance:(float)distance;

/**
 推送消息V2
 
 @param tit 标题，最大长度为32Bytes
 @param mes 消息内容，最大长度为200 Bytes
 */
- (void)pushMessageTit:(NSString *)tit message:(NSString *)mes;

/*请求07运动数据
 @discussion 每次数据请求最多只能反馈20组数据，余下数据必须重新发送请求指令，直到获取到的数据少于20组
 */
-(void)requestCuffSportData;

/*请求07睡眠数据
 @discussion 每次数据请求最多只能反馈20组数据，余下数据必须重新发送请求指令，直到获取到的数据少于20组
 */
- (void)requestCuffSleepData;

/*请求07心率数据
 @discussion 每次数据请求最多只能反馈20组数据，余下数据必须重新发送请求指令，直到获取到的数据少于20组
 */
- (void)requestCuffHRData;

/*请求05最后一次检测到的心率
 @discussion 检测出来的心率为05手表最后一次监测到的心率值
 */
- (void)requestLastHRData;

/**
 请求骑行数据
 @discussion 每次数据请求最多只能反馈20组数据，余下数据必须重新发送请求指令，直到获取到的数据少于20组
 */
- (void)requestCyclingData;

/**
 请求GPS数据
 @discussion 每次数据请求最多只能反馈20组数据，余下数据必须重新发送请求指令，直到获取到的数据少于20组
 */
- (void)requestGpsData;

/**
 请求游泳数据
 @discussion 每次数据请求最多只能反馈20组数据，余下数据必须重新发送请求指令，直到获取到的数据少于20组
 */
- (void)requestSwimData;

/**寻找设备
 Description 寻找设备并根据鸣蜂强度促使设备播放音乐
 
 @param intensity 蜂鸣强度（intensity = 0 无蜂鸣（关闭）；intensity = 1 中等；intensity = 2 高等强度蜂鸣）
 */
- (void)requestFindDeviceWithBuzzing:(int)intensity;

/*复位手表
 @discussion 重启手表
 */
- (void)BLrestoration;

/*测试模式
 @param on YES:进入，NO：退出
 @discussion  可测试LED和马达工作情况（仅用于02、04）
 */
- (void)enterTextMode:(BOOL)on;

/*点亮LED
 @discussion  必须进入测试模式
 */
- (void)lightLED;

/*震动马达
 @discussion  必须进入测试模式
 */
- (void)vibrationMotor;

/*获取闹钟列表
 @discussion 当应用程序触发:peripheral:didUpdateValueForCharacteristic:error:之后后调用:handleResponseValue:触发bleDataParsingWithMode: dataArr
 */
-(void)getCalarmClockList;

/*获取07闹钟列表
 @discussion 当应用程序触发:peripheral:didUpdateValueForCharacteristic:error:之后后调用:handleResponseValue:触发bleDataParsingWithMode: dataArr
 */
-(void)getCuffCalarmClockList;


/*请求运动数据
 @discussion 当应用程序触发:peripheral:didUpdateValueForCharacteristic:error:之后后调用:handleResponseValue:触发bleDataParsingWithMode: dataArr
 */
-(void)requestExerciseData;

/**请求锻炼数据V2
  @discussion 当应用程序触发:peripheral:didUpdateValueForCharacteristic:error:之后后调用:handleResponseValue:触发bleDataParsingWithMode: dataArr
 */
- (void)requestSportDataV2;

/**请求血压数据
 @discussion 当应用程序触发:peripheral:didUpdateValueForCharacteristic:error:之后后调用:handleResponseValue:触发bleDataParsingWithMode: dataArr
 */
- (void)getBloodPressure;

/*获取设备时间
 @discussion 当应用程序触发:peripheral:didUpdateValueForCharacteristic:error:之后后调用:handleResponseValue:触发bleDataParsingWithMode: dataArr
 */
- (void)getWatchDate;

/*获取电量
 @discussion 当应用程序触发:peripheral:didUpdateValueForCharacteristic:error:之后后调用:handleResponseValue:触发bleDataParsingWithMode: dataArr
 */
-(void)getElectric;

/*获取蓝牙硬件版本
 @discussion 当应用程序触发:peripheral:didUpdateValueForCharacteristic:error:之后后调用:handleResponseValue:触发bleDataParsingWithMode: dataArr
 */
- (void)getBLVersion;

/*获取MAC地址
 @discussion 当应用程序触发:peripheral:didUpdateValueForCharacteristic:error:之后后调用:handleResponseValue:触发bleDataParsingWithMode: dataArr
 */
- (void)getBLmac;

/*获取表盘编号（10-A）
 */
- (void)getSwitchNumber;


/**获取用户目标步数 (R1系列)
 Description 当应用程序触发:peripheral:didUpdateValueForCharacteristic:error:之后后调用:handleResponseValue:触发bleDataParsingWithMode: dataArr
 */
- (void)getGoal;


/**久坐设置获取 (R1系列)
 Description 当应用程序触发:peripheral:didUpdateValueForCharacteristic:error:之后后调用:handleResponseValue:触发bleDataParsingWithMode: dataArr
 */
- (void)getLongTime;

/*进入XOMDEM模式（10-A，07(指定固件)）
 */
- (void)enterXmodem;

/*结束XOMDEM模式（10-A，07(指定固件)）
 */
- (void)endXMODEM;

/*计算路程
 @parmar height 用户身高（cm）
 @parmar step   步数
 */
- (float )countDisWithHeight:(NSString *)height Step:(NSString *)step;

/*计算卡路里
 @parmar sex 用户性别
 @parmar weight 用户体重
 @parmar step   步数
 */
- (float)countCalWithSex:(NSString *)sex userWeight:(NSString *)weight step:(NSString *)step;

/*解析表盘数据包
 @parmar data 解析对应的表盘bin文件的16进制数据
 @parmar number 需要替换表盘的位置（1，2，3）
 */

- (NSInteger)countStepsWithSex:(NSString *)sex userWeight:(NSString *)weight cal:(NSInteger)cal;

- (void)analySwitchs:(NSString *)name replace:(int )number;

- (void)analySwitchsWithdata:(NSData *)data replace:(int)number;

/*解析字库数据包
 @parmar data 解析对应的bin文件的16进制数据
 */
- (void)setFontBin:(NSData *)data;

/*设置本地时区
 */
- (void)setTimeZone;

/*设置经纬度海拔
 */
- (void)setLongitude:(float)longitude Latitude:(float)latitude Altitude:(float)altitude;
@end


