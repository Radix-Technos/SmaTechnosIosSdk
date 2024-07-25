//
//  SmaBLE.m
//  SmaBLE
//
//  Created by 有限公司 深圳市 on 16/1/15.
//  Copyright © 2016年 SmaLife. All rights reserved.
//

#import "SmaBLE.h"
#import "AFNetRequestManager.h"


@interface SmaBLE ()
{
    NSTimer *receiveBLTimer;
    int binNum ;  //当前发第几包
    BOOL numbstart;
    BOOL numbend;
    NSData *epoFileData;
}
@property (nonatomic,assign) int sendNum;//指令发送次数
@property (nonatomic, assign) BOOL canSend;//是否能发送下一条指令
/*蓝牙指令数组*/
@property (nonatomic, strong) NSMutableArray *BLInstructionArr;
@property (nonatomic,strong) NSTimer *sendBLTimer;//指令超时定时器
@property (nonatomic,strong) NSMutableArray *BinArr;
@property (nonatomic, assign) int switchNumber;
@end

@implementation SmaBLE
@synthesize serialNum;
typedef enum {
    AWAIT_RECEVER1=0,//等待接收
    ALREADY_RECEVER1=1,//已经接收
    VERIFT_RECEVER1=2
}RECEVER_STATUS_TYPE1;
static  int receive_state=0;//数据接收状态
static  int sum_length_to_receive=0;//数据接收总长度
static  int length_to_receive=0;//数据长度
static Byte received_buffer[256];
static SmaBLE *_instace;

//+(instancetype)sharedCoreBlue {
//    static SmaBLE* instance = nil;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        instance = [[self alloc] init];
//    });
//    return instance;
//}

+ (id)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instace = [super allocWithZone:zone];
    });
    return _instace;
}

+ (instancetype)sharedCoreBlue
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instace = [[self alloc] init];
    });
    [[NSNotificationCenter defaultCenter] addObserver:_instace selector:@selector(serialN:) name:@"serialNUN" object:nil];
    return _instace;
}

- (id)copyWithZone:(NSZone *)zone
{
    return _instace;
}

- (void)serialN:(NSNotification *)Num{
    serialNum = [Num.userInfo[@"SERIANUM"] intValue];
}

- (NSMutableArray *)BLInstructionArr{
    if (!_BLInstructionArr || _BLInstructionArr.count == 0) {
        _BLInstructionArr = [[NSMutableArray alloc] init];
    }
    return _BLInstructionArr;
}

//处理非应答数据
- (void)handleResponseValue:(CBCharacteristic *)characteristic{
    Byte *testByte = (Byte *)[characteristic.value bytes];
    int len=(int)characteristic.value.length;
    if(testByte && [SmaBusinessTool checkNckBytes:testByte])//非应答信号
    {
        if (self.isUPDateSwitch){
            if (testByte[0] == 0x43 && (self.isUPDateFont? (binNum == 0) : (binNum == 1)) && numbstart) {
                numbend = NO;
                numbstart = YES;
                [self writeFirmware:binNum];
                binNum++;
            }
            
            else if (testByte[0] == 0x15 && binNum !=0){
                binNum --;
                [self writeFirmware:binNum];
                binNum++;
            }
            else if (testByte[0] == 0x06  && binNum !=0){
                if (self.BinArr.count == binNum && numbend == NO) {
                    //结束下载表盘
                    numbend = YES;
                    Byte endByte[1];
                    endByte[0] =0x04;
                    [self.p writeValue:[NSData dataWithBytes:endByte length:1] forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
                }
                else if (self.BinArr.count == binNum && numbend ){
                    //退出XMODEM模式
                    numbstart = NO;
                    self.isUPDateSwitch = NO;
                    Byte endByte1[1];
                    endByte1[0] =0x71;
                    [self.p writeValue:[NSData dataWithBytes:endByte1 length:1] forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
                    if ([self.delegate respondsToSelector:@selector(updateProgressEnd:)]) {
                        [self.delegate updateProgressEnd:YES];
                    }
                }
                if (self.BinArr.count != binNum){
                    [self writeFirmware:binNum];
                    binNum++;
                }
            }
            //                        [self writeFirmware:binNum];
            //                        binNum++;
        }
        else{
            if (testByte[0]==0xAB && characteristic.value.length==1) {
                return;
            }
            if(receive_state==AWAIT_RECEVER1 && testByte[0]==0xAB)//等待接受
            {
                //获取此批次需要接收的长度
                int i=(int)(testByte[3]|testByte[2]<<8);
                sum_length_to_receive=(i+8);
                length_to_receive=0;
            }
            
            [self getSpliceByte:testByte len:len totallenght:sum_length_to_receive];
        }
    }
    else{
        
        
        if (![[[self.BLInstructionArr firstObject] lastObject] isEqualToString:@"GET"]) {
            if (self.sendBLTimer) {
                [self.sendBLTimer invalidate];
                self.sendBLTimer = nil;
            }
            self.canSend = YES;
            self.sendNum = 0;
            if (self.BLInstructionArr.count > 0) {
                [self.BLInstructionArr removeObjectAtIndex:0];
            }
            [self sendBLInstruction];
        }
        if (_delegate && [_delegate respondsToSelector:@selector(sendIdentifier:)]) {
            //            NSLog(@"jgrighh==%@",[NSData dataWithBytes:testByte length:len]);
            [_delegate sendIdentifier:(testByte[len - 2]<<8) + (testByte[len - 1]<<0)];
        }
        
        
//        int serNum = (testByte[len - 2]<<8) + (testByte[len - 1]<<0);
//        if (serNum == self.serialNum && epoIndex > 0) {
//            [self epoFileWrite];
//        }
    }
}

//组装蓝牙返回的数据
-(void)getSpliceByte:(Byte [])testBytes len:(int)len totallenght:(int)totallenght
{
    if(receive_state==AWAIT_RECEVER1)
    {
        if(testBytes[0]!=0xAB)//开始接收包
            return;
        
        receive_state=ALREADY_RECEVER1;//继续等待接收
        memcpy(&received_buffer,testBytes,len);//拷贝到对应的Byte 数组中
        length_to_receive=len;//已经接收的长度
        if(totallenght==length_to_receive)//一次就全部接收完成
        {
            BOOL bol= [SmaBusinessTool checkCRC16:received_buffer];
            //检查命令类型
            [self checkCmdKeyType:received_buffer len:totallenght bol:bol];
            //完成操作
            receive_state=AWAIT_RECEVER1;
        }
    }else if(receive_state==ALREADY_RECEVER1)
    {
        
        //        if(testBytes[0]!=0xAB)//开始接收包
        if (receiveBLTimer) {
            [receiveBLTimer invalidate];
            receiveBLTimer = nil;
        }
        receiveBLTimer = [NSTimer scheduledTimerWithTimeInterval:8 target:self selector:@selector(receiveTimeOut) userInfo:nil repeats:NO];
        memcpy(&received_buffer[length_to_receive],testBytes,len);
        length_to_receive=length_to_receive+len;
        
        if(length_to_receive>=totallenght)//接收完毕
        {
            if (receiveBLTimer) {
                [receiveBLTimer invalidate];
                receiveBLTimer = nil;
            }
            sum_length_to_receive=0;
            length_to_receive=0;
            receive_state=AWAIT_RECEVER1;
            BOOL bol= [SmaBusinessTool checkCRC16:received_buffer];
            //检查命令类型
            [self checkCmdKeyType:received_buffer len:totallenght bol:bol];
        }
    }
    //    }
}

//检查命令类型
-(void)checkCmdKeyType:(Byte *)bytes len:(int)len bol:(BOOL)bol {

    [self retAckAndNackBol:bol ckByte:((received_buffer[6]<<8)+received_buffer[7])];
    if ([[[self.BLInstructionArr firstObject] lastObject] isEqualToString:@"GET"]&&self.BLInstructionArr.count > 0&&self.canSend == NO  && !(bytes[8]==0x05 && bytes[10]==0x03) && !(bytes[8]==0x05 && bytes[10]==0x02) &&!(bytes[8]==0x05 &&  bytes[10]==0x05)) {
        
        if (self.sendBLTimer) {
            [self.sendBLTimer invalidate];
            self.sendBLTimer = nil;
        }
        self.canSend = YES;
        self.sendNum = 0;
        if (self.BLInstructionArr.count > 0) {
            [self.BLInstructionArr removeObjectAtIndex:0];
        }
        [self sendBLInstruction];
    }
    
    SMA_INFO_MODE mode = 1000;
    NSMutableArray *array ;
    if(bytes[8]==0x01 && bytes[10]==0x02 && bol){
        mode = OTA;
        int Status = bytes[12];
        int error = bytes[13];
        if (Status) {
            array = [NSMutableArray arrayWithObjects:@"1", nil];
        }
        else{
            array = [NSMutableArray arrayWithObjects:@"0",@"PowerIsNormal", nil];
            if (error) {
                array = [NSMutableArray arrayWithObjects:@"0",@"PowerIsTooLow", nil];
            }
        }
    }
    else if (bytes[8]==0x01 && bytes[10]==0x22 && bol) {//进入XMODEM模式
        mode = XMODEM;
        array =[NSMutableArray arrayWithObjects:@"1", nil];
        if (bytes[13]==0x00 && bytes[14]==0x00) {
            self.isUPDateSwitch = YES;
            numbstart = YES;
            numbend = NO;
            binNum = 0;
            if (!self.isUPDateFont) {
                [self performSelector:@selector(timeoutToStopConnectAction) withObject:nil afterDelay:1];//延时1S再发送表盘数据，保证数据正常发送
            }
        }
        else if(bytes[13]==0x01 && bytes[14]==0x02){
            array =[NSMutableArray arrayWithObjects:@"updateTimeOut", nil];
            if ([self.delegate respondsToSelector:@selector(updateProgressEnd:)]) {
                [self.delegate updateProgressEnd:NO];
            }
        }
    }
    
    else if (bytes[8]==0x01 && bytes[10]==0x32 && bol) {
        mode = WATCHFACE;
        array = [NSMutableArray array];
        for (int i = 0; i < bytes[13]; i++) {
            [array addObject:[NSString stringWithFormat:@"%d",((uint16_t)bytes[14+i*4]<<24)+((uint16_t)bytes[15+i*4]<<16)+((uint16_t)bytes[16+i*4]<<8)+((uint16_t)bytes[17+i*4]<<0)]];
        }
    }
    else if(bytes[8]==0x03 && bytes[10]==0x02 && bol)//绑定请求返回命令,验证是否
    {
        mode = BAND;
        int error = bytes[13];
        array =[NSMutableArray arrayWithObjects:@"0", nil];
        if (error == 0) {
            array =[NSMutableArray arrayWithObjects:@"1", nil];
        }
    }
    else if(bytes[8]==0x03 && bytes[10]==0x04 )//登录请求返还命令,验证登录是否成功
    {
        mode = LOGIN;
        array =[NSMutableArray arrayWithObjects:@"0", nil];
        if (bol) {
            array =[NSMutableArray arrayWithObjects:@"1", nil];
        }
    }
    else if(bytes[8]==0x02 && bytes[10]==0x04 && bol)//返回闹钟列表
    {
        mode = ALARMCLOCK;
        array = [self analysisAlarmClockData:bytes len:len];
        if (array.count == 0) {
            NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:@"NODATA",@"NODATA", nil];
            [array addObject:dic];
        }
    }
    else if(bytes[8]==0x02 && bytes[10]==0x2E && bol)//返回07闹钟列表
    {
        mode = ALARMCLOCK;
        array = [self analysisCuffAlarmClockData:bytes len:len];
        if (array.count == 0) {
            NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:@"NODATA",@"NODATA", nil];
            [array addObject:dic];
        }
    }
    
    else if (bytes[8]==0x02 && bytes[10]==0x07 && bol){
        mode = SYSTEMTIME;
        array = [self analysisSystemData:bytes len:len];
    }
    else if (bytes[8]==0x02 && bytes[10]==0x0B && bol) {
        mode = VERSION;
        NSString *version = [NSString stringWithFormat:@"%hhu.%hhu.%hhu",bytes[13],bytes[14],bytes[15]];
        NSString *BLEversion = [NSString stringWithFormat:@"%hhu.%hhu.%hhu",bytes[16],bytes[17],bytes[18]];
        array =[NSMutableArray arrayWithObjects:version,BLEversion, nil];
    }
    else if(bytes[8]==0x02 && bytes[10]==0x09 && bol)
    {
        mode = ELECTRIC;
        NSString* text = [[NSString alloc] initWithFormat:@"%d%%", bytes[13]];
        array = [NSMutableArray arrayWithObjects:text, nil];
    }
    else if (bytes[8]==0x02 && bytes[10]==0x0D && bol) {
        mode = MAC;
        NSString *macStr = [[[[NSData dataWithBytes:bytes length:len] description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]] stringByReplacingOccurrencesOfString:@" " withString:@""];
        NSString *version = [NSString stringWithFormat:@"%@:%@:%@:%@:%@:%@",[[macStr substringWithRange:NSMakeRange(26, 2)] uppercaseString],[[macStr substringWithRange:NSMakeRange(28, 2)] uppercaseString],[[macStr substringWithRange:NSMakeRange(30, 2)] uppercaseString],[[macStr substringWithRange:NSMakeRange(32, 2)] uppercaseString],[[macStr substringWithRange:NSMakeRange(34, 2)] uppercaseString],[[macStr substringWithRange:NSMakeRange(36, 2)] uppercaseString]];
        array =[NSMutableArray arrayWithObjects:version, nil];
    }
    else if(bytes[8]==0x05 && bytes[10]==0x02 && bol)
    {
        mode = SPORTDATA;
        array = [self analySportData:bytes len:len];
    }
    else if(bytes[8]==0x05 && bytes[10]==0x03 && bol){
        mode = SLEEPDATA;
        array = [self analysisSleepData:bytes len:len];
    }
    else if(bytes[8]==0x05 && bytes[10]==0x05 && bol){
        mode = SLEEPSETDATA;
        array = [self analysisSetSleepData:bytes len:len];
    }
    else if(((bytes[8]==0x05 && bytes[10]==0x34) || (bytes[8]==0x05 && bytes[10]==0x36)) && bol){
        mode = RUNMODE;
        if (bytes[8]==0x05 && bytes[10]==0x34) {
            array = [self manualSportRunWithData:bytes Len:len];
        }
        else if (bytes[8]==0x05 && bytes[10]==0x36){
            array = [self manualSportV2RunWithData:bytes Len:len];
        }
    }
    else if(bytes[8]==0x07 && bytes[10]==0x01 && bol){
        mode = BOTTONSTYPE;
        array =[NSMutableArray arrayWithObjects:[NSString stringWithFormat:@"%d",bytes[13]], nil];
    }
    else if(bytes[8]==0x05 && bytes[10]==0x21 && bol){
        mode = WATHEARTDATA;
        array =  [self analysisHRData:bytes len:len];
    }
    else if(bytes[8]==0x05 && bytes[10]==0x42 && bol){
        mode = CUFFSPORTDATA;
        array = [self manualSportWithData:bytes Len:len];
    }
    
    else if(bytes[8]==0x05 && bytes[10]==0x44 && bol){
        mode = CUFFHEARTRATE;
        array =  [self analysisCuffHRData:bytes len:len];
    }
    else if(bytes[8]==0x05 && bytes[10]==0x46 && bol){
        mode = CUFFSLEEPDATA;
        array = [self analysisCuffSleepData:bytes len:len];
    }
    else if(bytes[8]==0x02 && bytes[10]==0x60 && bol){
        mode = NOTIFICATION;
        array =[NSMutableArray arrayWithObjects:[NSString stringWithFormat:@"%d",bytes[10]], nil];
    }
    else if(bytes[8]==0x02 && bytes[10]==0x61 && bol){
        mode = NOTIFICATION;
        array =[NSMutableArray arrayWithObjects:[NSString stringWithFormat:@"%d",bytes[10]], nil];
    }
    else if(bytes[8]==0x02 && bytes[10]==0x64 && bol){
        mode = NOTIFICATION;
        array =[NSMutableArray arrayWithObjects:[NSString stringWithFormat:@"%d",bytes[10]], nil];
    }
    else if(bytes[8]==0x02 && bytes[10]==0x67 && bol){
        mode = NOTIFICATION;
        array =[NSMutableArray arrayWithObjects:[NSString stringWithFormat:@"%d",bytes[10]], nil];
    }
    else if (bytes[8]==0x02 && bytes[10]==0x63 && bol){
        mode = GOALCALLBACK;
        Byte goalByte[4] = {0};
        goalByte[0] = bytes[14];
        goalByte[1] = bytes[15];
        goalByte[2] = bytes[16];
        goalByte[3] = bytes[17];
        //        NSLog(@"ijogor   %d ",((bytes[13] & 0xff)<<24) | ((bytes[14] & 0xff)<<16) | ((bytes[15] & 0xff)<<8 | ((bytes[16] & 0xff))));
        //        NSLog(@"fwegr g   = %f", (bytes[13] * pow(16, 6)) + (bytes[14] * pow(16, 4)) + (bytes[15]* pow(16, 2)) + (bytes[16]));
        array =[NSMutableArray arrayWithObjects:[NSString stringWithFormat:@"%d",((bytes[13] & 0xff)<<24) | ((bytes[14] & 0xff)<<16) | ((bytes[15] & 0xff)<<8 | ((bytes[16] & 0xff)))], nil];
    }
    else if (bytes[8]==0x02 && bytes[10]==0x66 && bol){
        mode = LONGTIMEBACK;
        array = [self analysisLongTimeData:bytes len:len];
    }
    else if(bytes[8]==0x04 && bytes[10]==0x60 && bol){
        mode = FINDPHONE;
        array =[NSMutableArray arrayWithObjects:[NSString stringWithFormat:@"%d",bytes[13]], nil];
    }
    else if (bytes[8]==0x05 && bytes[10]==0x4a && bol){
        mode = BLUTDRUCK;
        array = [self manualMbWithData:bytes Len:len];
    }
    else if (bytes[8]==0x05 && bytes[10]==0x4d && bol){
        mode = CYCLINGDATA;
        array = [self analysisCuffcylingData:bytes len:len];
    }
    else if (bytes[8]==0x05 && bytes[10]==0x48 && bol){
        mode = GPS;
        array = [self analysisGpsData:bytes len:len];
    }
    else if (bytes[8]==0x05 && bytes[10]==0x4f && bol){
        mode = SWIM;
        array = [self analysisSwimData:bytes len:len];
    }
    else if (bytes[8] == 0x02 && bytes[10] == 0x6a && bol) {  //设备通用请求指令
        NSLog(@"设备通用请求指令");
//        [self getDeviceRequestData:bytes len:len];
    }
    if (mode <= 27 && array.count > 0) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(bleDataParsingWithMode:dataArr:Checkout:)]) {
            [self.delegate bleDataParsingWithMode:mode dataArr:array Checkout:bol];
        }
    }
}
//－－－－－－－－－－－－－－绑定手表
-(void)bindUserWithUserID:(NSString *)userid
{
    [self.BLInstructionArr removeAllObjects];
    if(_p && _Write)
    {
        [self bindBloacUserID:userid characteristic:_Write ident:0];//绑定
    }
}

//解除绑定
-(void)relieveWatchBound{
    [self.BLInstructionArr removeAllObjects];
    Byte results[14];
    [SmaBusinessTool getSpliceCmdBand:0x03 Key:0x05 bytes1:nil len:0 results:results];//解除绑定
    NSData * data1 = [NSData dataWithBytes:results length:20];
    if(self.p && self.Write)
    {
        [self.p writeValue:data1 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

//登录命令
-(void)LoginUserWithUserID:(NSString *)userid
{
    self.isUPDateSwitch = NO;
    [self.BLInstructionArr removeAllObjects];
    if(_p && _Write)
        [self bindBloacUserID:userid characteristic:_Write ident:1];//登陆
}

//退出登录
-(void)logOut{
    [self.BLInstructionArr removeAllObjects];
    Byte results[14];
    Byte buf[1];
    buf[0] = 0x00;
    [SmaBusinessTool getSpliceCmd:0x03 Key:0x06 bytes1:buf len:1 results:results];
    NSData * data0 = [NSData dataWithBytes:results length:14];
    if(_p && _Write){
        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
    
}

/**
 *  <#Description#> 设置用户信息
 */
-(void)setUserMnerberInfoWithHeight:(float)he weight:(float)we sex:(int)sex age:(int)age
{
    userprofile_union_t user_info;
    user_info.bit_field.reserved = 0;
    user_info.bit_field.weight =we*2;
    user_info.bit_field.hight = he*2;
    user_info.bit_field.age = age;
    user_info.bit_field.gender =sex;
    Byte buf[4];
    buf[0] = user_info.data>>24;
    buf[1] = user_info.data>>16;
    buf[2] = user_info.data>>8;
    buf[3] = user_info.data>>0;
    Byte results[17];
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x10 bytes1:buf len:4 results:results];
    NSData * data0 = [NSData dataWithBytes:results length:17];
    if (self.p) {
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        NSMutableArray *senArr = [NSMutableArray array];
        //        [senArr addObject:data0];
        //        [senArr addObject:@"SET"];
        //        [self.BLInstructionArr addObject:senArr];
        //        [self sendBLInstruction];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
    
}

//设置系统时间
-(void)setSystemTime{
    NSDate *now = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSUInteger unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    NSDateComponents *dateComponent = [calendar components:unitFlags fromDate:now];
    
    usercdata_union_t user_data;
    user_data.bit_field.second = (int)[dateComponent second];
    user_data.bit_field.minute =  (int)[dateComponent minute];
    user_data.bit_field.hour  = (int)[dateComponent hour];
    user_data.bit_field.day =  (int)[dateComponent day];
    user_data.bit_field.Month = (int)[dateComponent month];
    user_data.bit_field.Year = [dateComponent year]%2000;
    
    
    Byte buf[4];
    buf[0] = user_data.data>>24;
    buf[1] = user_data.data>>16;
    buf[2] = user_data.data>>8;
    buf[3] = user_data.data>>0;
    
    Byte results[17];
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x01 bytes1:buf len:4 results:results];//绑定
    
    NSData * data0 = [NSData dataWithBytes:results length:17];
    [self arrangeBLData:data0 type:@"SET" sendNum:1];
    //    NSMutableArray *senArr = [NSMutableArray array];
    //    [senArr addObject:data0];
    //    [senArr addObject:@"SET"];
    //    [self.BLInstructionArr addObject:senArr];
    //    [self sendBLInstruction];
    //    [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
}

/*******************蓝牙命令发送与请求   being*******************/
-(void)bindBloacUserID:(NSString *)userID characteristic:(CBCharacteristic *)characteristic ident:(int)ident {
    username_union_t username_id;
    username_id.bit_field.userId =[userID intValue];
    
    Byte buf[32];
    buf[0] = username_id.data>>24;
    buf[1] = username_id.data>>16;
    buf[2] = username_id.data>>8;
    buf[3] = username_id.data>>0;
    for (int i=4; i<32; i++) {
        buf[i]=0x00;
    }
    Byte results[45];
    if(ident==0)
    {
        [SmaBusinessTool getSpliceCmd:0x03 Key:0x01 bytes1:buf len:32 results:results];//绑定
    }else
    {
        [SmaBusinessTool getSpliceCmd:0x03 Key:0x03 bytes1:buf len:32 results:results];//登陆
    }
    Byte but0[20];
    int j=0;
    for (int i=0; i<20; i++) {
        but0[i]=results[i];
        j++;
    }
    
    NSData * data0 = [NSData dataWithBytes:but0 length:20];
    [_p writeValue:data0 forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
    
    Byte but1[20];
    for (int i=0; i<20; i++) {
        but1[i]=results[j];
        j++;
        
    }
    NSData * data1 = [NSData dataWithBytes:but1 length:20];
    [_p writeValue:data1 forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
    
    Byte but2[5];
    for (int i=0; i<5; i++) {
        but2[i]=results[j];
        j++;
        
    }
    NSData * data2 = [NSData dataWithBytes:but2 length:5];
    [_p writeValue:data2 forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
    
}


//ack 或Nack 回应
-(void)retAckAndNackBol:(BOOL)bol ckByte:(int16_t)ckByte
{
    if(bol)//绑定成功
    {
        [SmaBusinessTool setAckCmdSeqId:ckByte peripheral:_p characteristic:_Write];//登录成功
    }else//绑定失败
    {
        [SmaBusinessTool setNackCmdSeqId:ckByte peripheral:_p characteristic:_Write];//登录失败
    }
}

/**
 *   设置防止丢失
 */
-(void)setDefendLose:(BOOL)bol
{
    defendlose_union_t defendlose_t;
    defendlose_t.bit_fieldreserve.mode = bol?2:0;
    defendlose_t.bit_fieldreserve.reserve=0;
    Byte buf[1];
    buf[0] = defendlose_t.data    ;
    Byte results[14];
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x20 bytes1:buf len:1 results:results];
    if(_p && _Write)
    {
        NSData * data0 = [NSData dataWithBytes:results length:14];
        NSMutableArray *senArr = [NSMutableArray array];
        [senArr addObject:data0];
        [senArr addObject:@"SET"];
        //        [self.BLInstructionArr addObject:senArr];
        //        [self sendBLInstruction];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

- (void)setDefendLoseName:(NSString *)name phone:(NSString *)p{
    Byte result[13 + 22 + p.length];
    NSData *nData = [name dataUsingEncoding:NSUTF8StringEncoding];
    NSData *pData = [p dataUsingEncoding:NSUTF8StringEncoding];
    Byte nByte [22] = {0};
    //    Byte pByte [p.length];
    Byte *testByte = (Byte *)[nData bytes];
    for (int j = 0; j < nData.length; j ++) {
        nByte[j] = testByte[j];
    }
    NSMutableData *resultData = [[NSMutableData alloc] init];
    [resultData appendData:[NSData dataWithBytes:nByte length:22]];
    [resultData appendData:pData];
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x48 bytes1:(Byte *)[resultData bytes] len:(int)(22 + pData.length) results:result];
    if (self.p && self.Write) {
        int rscount = (int)(13 + 22 + p.length);
        int degree=rscount/20;
        int surplus=rscount%20;
        if(surplus>0)
            degree=degree+1;
        for (int i=0; i<degree; i++) {
            int alen = (((degree-1)==i && surplus > 0)?surplus:20);
            Byte arr[alen];
            memcpy(&arr,&result[0+(20*i)],alen);//拷贝到对应的Byte 数组中
            NSData * data0 = [NSData dataWithBytes:arr length:alen];
            [self arrangeBLData:data0 type:@"SET" sendNum:degree];
        }
    }
}

/**
 *  相机
 */
- (void)setBLcomera:(BOOL)bol{
    
    Byte buf[1];
    if (bol) {
        buf[0] = 0x01;
    }
    else{
        buf[0] = 0x00;
    }
    Byte results[14];
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x42 bytes1:buf len:1 results:results];
    NSData * data0 = [NSData dataWithBytes:results length:14];
    [self arrangeBLData:data0 type:@"SET" sendNum:1];
}

//SM04手机来电
-(void)setphonespark:(BOOL)bol
{
    if(self.p && self.Write)
    {
        Byte buf[1];
        if(bol)
            buf[0]=0x01;
        else
            buf[0]=0x00;
        
        Byte results[14];
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x26 bytes1:buf len:1 results:results];//来电提醒
        NSData * data0 = [NSData dataWithBytes:results length:14];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

//SM04短信
-(void)setSmspark:(BOOL)bol
{
    if(self.p && self.Write){
        Byte buf[1];
        if(bol)
            buf[0]=0x01;
        else
            buf[0]=0x00;
        Byte results[14];
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x27 bytes1:buf len:1 results:results];//短信提醒
        NSData * data0 = [NSData dataWithBytes:results length:14];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

/**
 *  <#Description#> 久坐提醒
 */
-(void)seatLongTimeWithWeek:(NSString *)week beginTime:(int)begin endTime:(int)end seatTime:(int)seat
{
    //    NSArray *array = [week componentsSeparatedByString:@","];
    NSArray *array = [[self toBinarySystemWithDecimalSystem:week] componentsSeparatedByString:@","];
    burntheplanks_week_union_t week_t1;
    week_t1.bit_week.monday=([array[0] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.tuesday=([array[1] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.wednesday=([array[2] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.thursday=([array[3] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.friday=([array[4] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.saturday=([array[5] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.sunday=([array[6] isEqualToString:@"0"])?0x00:0x01;
    
    burntheplanks_union_t burnthe_t;
    burnthe_t.bit_plank.dayflags = week_t1.week;
    burnthe_t.bit_plank.endtime =end;
    burnthe_t.bit_plank.begintime =begin;
    burnthe_t.bit_plank.whenminute = seat;
    burnthe_t.bit_plank.enable=1;
    burnthe_t.bit_plank.thresholdvalue = 30;//[info.seatValue intValue];
    Byte buf1[8];
    buf1[0] = burnthe_t.data>>56;
    buf1[1] = burnthe_t.data>>48;
    buf1[2] = burnthe_t.data>>40;
    buf1[3] = burnthe_t.data>>32;
    buf1[4] = burnthe_t.data>>24;
    buf1[5] = burnthe_t.data>>16;
    buf1[6] = burnthe_t.data>>8;
    buf1[7] = burnthe_t.data>>0;
    Byte results[21];
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x21 bytes1:buf1 len:8 results:results];//久坐设置
    int degree=21/20;
    int surplus=21%20;
    if(surplus>0)
        degree=degree+1;
    if(self.p && self.Write)
    {
        for (int i=0; i<degree; i++) {
            int alen=(((degree-1)==i)?surplus:20);
            Byte arr[alen];
            
            memcpy(&arr,&results[0+(20*i)],alen);//拷贝到对应的Byte 数组中
            
            NSData * data0 = [NSData dataWithBytes:arr length:(((degree-1)==i)?surplus:20)];
            [self arrangeBLData:data0 type:@"SET" sendNum:degree];
            //            [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
            
        }
    }
}

//关闭久坐
-(void)closeLongTimeInfo
{
    Byte buf[8];
    buf[0] = 0x00;
    buf[1] = 0x00;
    buf[2] = 0x00;
    buf[3] = 0x00;
    buf[4] = 0x00;
    buf[5] = 0x00;
    buf[6] = 0x00;
    buf[7] = 0x00;
    
    Byte buf2[1];
    buf2[0] = 0x00;
    
    if(self.p && self.Write)
    {
        Byte results[21];
        [SmaBusinessTool getSpliceCmd1:0x02 Key:0x21 bytes1:buf len:8 results:results];//久坐设置
        Byte arr1[20];
        memcpy(&arr1,&results[0],20);
        NSData * data01 = [NSData dataWithBytes:arr1 length:20];
        //        [self.p writeValue:data01 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
        [self arrangeBLData:data01 type:@"SET" sendNum:2];
        Byte arr2[1];
        memcpy(&arr2,&results[20],1);
        NSData * data02 = [NSData dataWithBytes:arr2 length:1];
        [self arrangeBLData:data02 type:@"SET" sendNum:2];
        //        [self.p writeValue:data02 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

/*  <#Description#> 久坐提醒V2
 */
-(void)seatLongTimeInfoV2:(SmaSeatInfo *)info{
    //    NSArray *array = [info.repeatWeek componentsSeparatedByString:@","];
    NSArray *array = [[self toBinarySystemWithDecimalSystem:info.repeatWeek] componentsSeparatedByString:@","];
    burntheplanks_week_union_t week_t1;
    week_t1.bit_week.monday=([array[0] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.tuesday=([array[1] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.wednesday=([array[2] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.thursday=([array[3] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.friday=([array[4] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.saturday=([array[5] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.sunday=([array[6] isEqualToString:@"0"])?0x00:0x01;
    burntheplanksV2_union_t burnthe_t;
    burnthe_t.bit_plank.dayflags = week_t1.week;
    burnthe_t.bit_plank.endTime1 = info.isOpen0.intValue? [info.endTime0 intValue] : 25;
    burnthe_t.bit_plank.beginTim1 = info.isOpen0.intValue? [info.beginTime0 intValue] : 25;
    burnthe_t.bit_plank.endTime2 = info.isOpen1.intValue? [info.endTime1 intValue] : 25;
    burnthe_t.bit_plank.beginTim2 = info.isOpen1.intValue? [info.beginTime1 intValue] : 25;
    burnthe_t.bit_plank.cycle = [info.seatValue intValue];
    burnthe_t.bit_plank.isopen=[info.isOpen intValue];
    burnthe_t.bit_plank.thresholdvalue = [info.stepValue intValue];
    Byte buf1[8];
    buf1[0] = burnthe_t.data>>56;
    buf1[1] = burnthe_t.data>>48;
    buf1[2] = burnthe_t.data>>40;
    buf1[3] = burnthe_t.data>>32;
    buf1[4] = burnthe_t.data>>24;
    buf1[5] = burnthe_t.data>>16;
    buf1[6] = burnthe_t.data>>8;
    buf1[7] = burnthe_t.data>>0;
    Byte results[21];
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x2A bytes1:buf1 len:8 results:results];//久坐设置
    int degree=21/20;
    int surplus=21%20;
    if(surplus>0)
        degree=degree+1;
    if(self.p && self.Write)
    {
        for (int i=0; i<degree; i++) {
            int alen=(((degree-1)==i)?surplus:20);
            Byte arr[alen];
            memcpy(&arr,&results[0+(20*i)],alen);//拷贝到对应的Byte 数组中
            NSData * data0 = [NSData dataWithBytes:arr length:(((degree-1)==i)?surplus:20)];
            [self arrangeBLData:data0 type:@"SET" sendNum:degree];
        }
    }
}

//设置闹钟
-(void)setCalarmClockInfo:(NSMutableArray *)smaACs
{
    int counts=(int)smaACs.count;
    int rscount=13+(counts*5);
    Byte results1[rscount];
    Byte buf[5*counts];
    for (int i=0; i<counts; i++) {
        SmaAlarmInfo *smaAcInfo=smaACs[i];
        alarm_union_t clock_data;
        NSArray *array = [[self toBinarySystemWithDecimalSystem:smaAcInfo.dayFlags] componentsSeparatedByString:@","];
        //         NSArray* reversedArray = [[array reverseObjectEnumerator] allObjects];
        burntheplanks_week_union_t week_t1;
        week_t1.bit_week.monday=([array[0] isEqualToString:@"0"])?0x00:0x01;
        week_t1.bit_week.tuesday=([array[1] isEqualToString:@"0"])?0x00:0x01;
        week_t1.bit_week.wednesday=([array[2] isEqualToString:@"0"])?0x00:0x01;
        week_t1.bit_week.thursday=([array[3] isEqualToString:@"0"])?0x00:0x01;
        week_t1.bit_week.friday=([array[4] isEqualToString:@"0"])?0x00:0x01;
        week_t1.bit_week.saturday=([array[5] isEqualToString:@"0"])?0x00:0x01;
        week_t1.bit_week.sunday=([array[6] isEqualToString:@"0"])?0x00:0x01;
        clock_data.alarm.day_repeat_flag =week_t1.week;
        //clock_data.alarm.reserved = 52;
        clock_data.alarm.id=[smaAcInfo.aid intValue];
        clock_data.alarm.minute =[smaAcInfo.minute intValue];
        clock_data.alarm.hour = [smaAcInfo.hour intValue];
        clock_data.alarm.day = [smaAcInfo.day intValue];
        clock_data.alarm.month=[smaAcInfo.mounth intValue];
        clock_data.alarm.year=[smaAcInfo.year intValue]%100;
        buf[0+(5*i)] = clock_data.data>>32;
        buf[1+(5*i)] = clock_data.data>>24;
        buf[2+(5*i)] = clock_data.data>>16;
        buf[3+(5*i)] = clock_data.data>>8;
        buf[4+(5*i)] = clock_data.data>>0;
    }
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x02 bytes1:buf len:(5*counts) results:results1];//绑定
    if(self.p && self.Write)
    {
        int degree=rscount/20;
        int surplus=rscount%20;
        if(surplus>0)
            degree=degree+1;
        for (int i=0; i<degree; i++) {
            int alen=(((degree-1)==i)?surplus:20);
            Byte arr[alen];
            memcpy(&arr,&results1[0+(20*i)],alen);//拷贝到对应的Byte 数组中
            NSData * data0 = [NSData dataWithBytes:arr length:(((degree-1)==i)?surplus:20)];
            [self arrangeBLData:data0 type:@"SET" sendNum:degree];
            //            [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
        }
    }
}

//设置手环闹钟
-(void)setClockInfoV2:(NSMutableArray *)smaACs {
    int counts=(int)smaACs.count;
    int rscount=13+(counts*23);
    Byte results1[rscount];
    Byte buf[23*counts];
    
    for (int i=0; i<counts; i++) {
        SmaAlarmInfo *smaAcInfo=smaACs[i];
        alarm_union_t clock_data;
        // NSArray *array = [smaAcInfo.dayFlags componentsSeparatedByString:@","];
        NSArray *array = [[self toBinarySystemWithDecimalSystem:smaAcInfo.dayFlags] componentsSeparatedByString:@","];
        burntheplanks_week_union_t week_t1;
        week_t1.bit_week.monday=([array[0] isEqualToString:@"0"])?0x00:0x01;
        week_t1.bit_week.tuesday=([array[1] isEqualToString:@"0"])?0x00:0x01;
        week_t1.bit_week.wednesday=([array[2] isEqualToString:@"0"])?0x00:0x01;
        week_t1.bit_week.thursday=([array[3] isEqualToString:@"0"])?0x00:0x01;
        week_t1.bit_week.friday=([array[4] isEqualToString:@"0"])?0x00:0x01;
        week_t1.bit_week.saturday=([array[5] isEqualToString:@"0"])?0x00:0x01;
        week_t1.bit_week.sunday=([array[6] isEqualToString:@"0"])?0x00:0x01;
        
        clock_data.alarm.day_repeat_flag =week_t1.week;
        //clock_data.alarm.reserved = 52;
        clock_data.alarm.id=[smaAcInfo.aid intValue];
        clock_data.alarm.minute =[smaAcInfo.minute intValue];
        clock_data.alarm.hour = [smaAcInfo.hour intValue];
        clock_data.alarm.day = [smaAcInfo.day intValue];
        clock_data.alarm.month=[smaAcInfo.mounth intValue];
        clock_data.alarm.year=[smaAcInfo.year intValue]%100;
        clock_data.alarm.reserved = [smaAcInfo.isOpen intValue];
        
        buf[0+(23*i)] = clock_data.data>>32;
        buf[1+(23*i)] = clock_data.data>>24;
        buf[2+(23*i)] = clock_data.data>>16;
        buf[3+(23*i)] = clock_data.data>>8;
        buf[4+(23*i)] = clock_data.data>>0;
        NSData *tagname = [smaAcInfo.tagname dataUsingEncoding:NSUTF8StringEncoding];
        Byte *byte = (Byte *)tagname.bytes;
        
        Byte alarm[18];
        Byte fill[1];
        fill[0] = 0x00;
        memcpy(&alarm[0], &byte[0], tagname.length);
        for (int j = 0; j<18-tagname.length; j++) {
            memcpy(&alarm[tagname.length+j], &fill[0],1);
        }
        memcpy(&buf[5+(23*i)], &alarm[0], 18);
    }
    
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x2c bytes1:buf len:(23*counts) results:results1];//绑定
    
    if(self.p && self.Write)
    {
        int degree=rscount/20;
        int surplus=rscount%20;
        if(surplus>0)
            degree=degree+1;
        for (int i=0; i<degree; i++) {
            int alen=(((degree-1)==i)?surplus:20);
            Byte arr[alen];
            memcpy(&arr,&results1[0+(20*i)],alen);//拷贝到对应的Byte 数组中
            NSData * data0 = [NSData dataWithBytes:arr length:(((degree-1)==i)?surplus:20)];
            [self arrangeBLData:data0 type:@"SET" sendNum:degree];
        }
    }
}


/**
 *  <#Description#> 设置记步目标
 */
-(void)setStepNumber:(int)count
{
    stepnumber_union_t stepnumber;
    stepnumber.step_number.stepnumber =count;
    
    Byte buf[4];
    buf[0] = stepnumber.data>>24;
    buf[1] = stepnumber.data>>16;
    buf[2] = stepnumber.data>>8;
    buf[3] = stepnumber.data>>0;
    
    Byte results[17];
    
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x05 bytes1:buf len:4 results:results];
    NSData * data0 = [NSData dataWithBytes:results length:17];
    if(_p && _Write)
    {
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
    
}

//勿扰设置（05）
- (void)setNoDisturb:(BOOL)bol{
    Byte buf[1];
    if(bol)
        buf[0]=0x01;
    else
        buf[0]=0x00;
    
    Byte results[14];
    if(_p && _Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x28 bytes1:buf len:1 results:results];
        NSData * data0 = [NSData dataWithBytes:results length:14];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

//背光设置（05）
- (void)setBacklight:(int)time{
    Byte buf[1];
    buf[0] = (Byte)((time>>0)&0xff);
    Byte results[14];
    if (self.p && self.Write) {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x29 bytes1:buf len:1 results:results];
        NSData * data0 = [NSData dataWithBytes:results length:14];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

//震动设置(05)
- (void)setVibrationFrequency:(int)freq{
    Byte buf[1];
    buf[0] = (Byte)((freq>>0)&0xff);
    Byte results[14];
    if (self.p && self.Write) {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x33 bytes1:buf len:1 results:results];
        NSData * data0 = [NSData dataWithBytes:results length:14];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

//震动设置（07）
- (void)setVibration:(SmaVibrationInfo *)info{
    vibration_union vibration;
    vibration.vibrationData.level = info.level.intValue;
    vibration.vibrationData.number = info.freq.intValue;
    Byte buf[2];
    buf[0] = (Byte)((info.type.intValue>>0)&0xff);
    buf[1] = vibration.data;
    Byte results[15];
    if (self.p && self.Write) {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x2F bytes1:buf len:2 results:results];
        NSData * data0 = [NSData dataWithBytes:results length:15];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
    
}

//打开关闭同步（02、04）
-(void)Syncdata:(BOOL)bol
{
    Byte buf[1];
    if(bol)
        buf[0]=0x01;
    else
        buf[0]=0x00;
    
    Byte results[14];
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x05 Key:0x06 bytes1:buf len:1 results:results];//关闭同步
        NSData * data0 = [NSData dataWithBytes:results length:14];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

-(void)setOTAstate
{
    //    Byte buf[13];
    //    buf[0] = 0xAB;
    //    buf[1] = 0x00;
    //    buf[2] = 0x00;
    //    buf[3] = 0x05;
    //    buf[4] = 0x00;
    //    buf[5] = 0x6C;
    //    buf[6] = 0x00;
    //    buf[7] = 0x00;
    //    buf[8] = 0x01;
    //    buf[9] = 0x00;
    //    buf[10] = 0x01;
    //    buf[11] = 0x00;
    //    buf[12] = 0x00;
    if(self.p && self.Write)
    {
        NSData * data01 = [SmaBusinessTool getOTAdata];
        //        [self.p writeValue:data01 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
        [self arrangeBLData:data01 type:@"SET" sendNum:1];
    }
}

- (void)setAppSportDataWithcal:(float)cal distance:(int)metre stepNnumber:(int)step{
    sport_data soprt_da;
    step_data step_da;
    soprt_da.stort_data.calor = cal*1000;
    soprt_da.stort_data.distance = metre;
    step_da.St_data.step = step;
    Byte buf [12];
    buf[0] = step_da.data >> 24;
    buf[1] = step_da.data >> 16;
    buf[2] = step_da.data >> 8;
    buf[3] = step_da.data >> 0;
    buf[4] = soprt_da.data >> 56;
    buf[5] = soprt_da.data >> 48;
    buf[6] = soprt_da.data >> 40;
    buf[7] = soprt_da.data >> 32;
    buf[8] = soprt_da.data >> 24;
    buf[9] = soprt_da.data >> 16;
    buf[10] = soprt_da.data >> 8;
    buf[11] = soprt_da.data >> 0;
    Byte results[25];
    [SmaBusinessTool getSpliceCmd:0x05 Key:0x09 bytes1:buf len:12 results:results];
    
    Byte buf0[20];
    memcpy(&buf0, &results[0], 20);
    Byte buf1[5];
    memcpy(&buf1, &results[20], 5);
    NSData *data0 = [NSData dataWithBytes:buf0 length:20];
    NSData *data1 = [NSData dataWithBytes:buf1 length:5];
    if(self.p && self.Write)
    {
        [self arrangeBLData:data0 type:@"SET" sendNum:2];
        [self arrangeBLData:data1 type:@"SET" sendNum:2];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
        //        [self.p writeValue:data1 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

//设置手环首页中英文（星期）
- (void)setLanguage:(int)lanNumber{
    Byte buf[1];
    buf[0]=(Byte)(lanNumber&0xff);
    Byte results[14];
    if(self.p && self.Write){
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x34 bytes1:buf len:1 results:results];
        NSData * data0 = [NSData dataWithBytes:results length:14];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

/**
 *设置心率
 */
- (void)setHRWithHR:(SmaHRHisInfo *)info {
    //    NSArray *weekArr = [info.dayFlags componentsSeparatedByString:@","];
    NSArray *weekArr = [[self toBinarySystemWithDecimalSystem:info.dayFlags] componentsSeparatedByString:@","];
    burntheplanks_week_union_t week_t1;
    week_t1.bit_week.monday=([weekArr[0] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.tuesday=([weekArr[1] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.wednesday=([weekArr[2] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.thursday=([weekArr[3] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.friday=([weekArr[4] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.saturday=([weekArr[5] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.sunday=([weekArr[6] isEqualToString:@"0"])?0x00:0x01;
    week_t1.bit_week.isopen=info.isopen.intValue?0x00:0x01;
    
    hrtheplanks_week_union_t hr_type;
    hr_type.bit_planks.dayflags = week_t1.week;
    hr_type.bit_planks.time = info.tagname.intValue;
    hr_type.bit_planks.start1_hour = info.isopen0.intValue? info.beginhour0.intValue : 25;
    hr_type.bit_planks.end1_hour = info.isopen0.intValue? info.endhour0.intValue : 25;
    hr_type.bit_planks.start2_hour = info.isopen1.intValue? info.beginhour1.intValue : 25;
    hr_type.bit_planks.end2_hour = info.isopen1.intValue? info.endhour1.intValue : 25;
    hr_type.bit_planks.start3_hour = info.isopen2.intValue? info.beginhour2.intValue : 25;
    hr_type.bit_planks.end3_hour = info.isopen2.intValue? info.endhour2.intValue : 25;
    Byte buf[8];
    buf[7] = hr_type.data>>56;
    buf[6] = hr_type.data>>48;
    buf[5] = hr_type.data>>40;
    buf[4] = hr_type.data>>32;
    buf[3] = hr_type.data>>24;
    buf[2] = hr_type.data>>16;
    buf[1] = hr_type.data>>8;
    buf[0] = hr_type.data>>0;
    //    Byte buf2[1];
    //    buf2[0] = burnthe_t.data>>0;
    Byte results[21];
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x44 bytes1:buf len:8 results:results];//绑定
    if(self.p && self.Write)
    {
        Byte but0[20];
        for (int i=0; i<20; i++) {
            but0[i]=results[i];
        }
        NSData * data1 = [NSData dataWithBytes:but0 length:20];
        [self arrangeBLData:data1 type:@"SET" sendNum:2];
        //        [self.p writeValue:data1 forCharacteristic: self.Write type:CBCharacteristicWriteWithResponse];
        Byte but1[1];
        
        but1[0]=results[20];
        NSData * data2 = [NSData dataWithBytes:but1 length:1];
        [self arrangeBLData:data2 type:@"SET" sendNum:2];
        //        [self.p writeValue:data2 forCharacteristic: self.Write type:CBCharacteristicWriteWithResponse];
    }
}

//设置抬手亮
- (void)setLiftBright:(BOOL)open{
    Byte buf[1];
    if(open)
        buf[0]=0x01;
    else
        buf[0]=0x00;
    Byte results[14];
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x35 bytes1:buf len:1 results:results];//
        NSData * data0 = [NSData dataWithBytes:results length:14];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

//竖屏设置
- (void)setVertical:(BOOL)open{
    Byte buf[1];
    if(open)
        buf[0]=0x01;
    else
        buf[0]=0x00;
    
    Byte results[14];
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x36 bytes1:buf len:1 results:results];//
        NSData * data0 = [NSData dataWithBytes:results length:14];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

// 设置勿扰时间
- (void)setNoDisInfo:(SmaNoDisInfo *)info{
    int rscount = 26;
    Byte result[26];
    Byte buf[13];
    buf[0] = info.isOpen.intValue?info.isOpen1.intValue:info.isOpen2.intValue?info.isOpen2.intValue:info.isOpen3.intValue?info.isOpen3.intValue:0x00;
    buf[1] = info.isOpen1.intValue?[self returnHour:info.beginTime1]&0xff:0x00;
    buf[2] = info.isOpen1.intValue?[self returnMinute:info.beginTime1]&0xff:0x00;
    buf[3] = info.isOpen1.intValue?[self returnHour:info.endTime1]&0xff:0x00;
    buf[4] = info.isOpen1.intValue?[self returnMinute:info.endTime1]&0xff:0x00;
    buf[5] = info.isOpen2.intValue?[self returnHour:info.beginTime2]&0xff:0x00;
    buf[6] = info.isOpen2.intValue?[self returnMinute:info.beginTime2]&0xff:0x00;
    buf[7] = info.isOpen2.intValue?[self returnHour:info.endTime2]&0xff:0x00;
    buf[8] = info.isOpen2.intValue?[self returnMinute:info.endTime2]&0xff:0x00;
    buf[9] = info.isOpen3.intValue?[self returnHour:info.beginTime3]&0xff:0x00;
    buf[10] = info.isOpen3.intValue?[self returnMinute:info.beginTime3]&0xff:0x00;
    buf[11] = info.isOpen3.intValue?[self returnHour:info.endTime3]&0xff:0x00;
    buf[12] = info.isOpen3.intValue?[self returnMinute:info.endTime3]&0xff:0x00;
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x2B bytes1:buf len:13 results:result];
    if(self.p&& self.Write)
    {
        int degree=rscount/20;
        int surplus=rscount%20;
        if(surplus>0)
            degree=degree+1;
        for (int i=0; i<degree; i++) {
            int alen=(((degree-1)==i)?surplus:20);
            Byte arr[alen];
            memcpy(&arr,&result[0+(20*i)],alen);//拷贝到对应的Byte 数组中
            NSData * data0 = [NSData dataWithBytes:arr length:(((degree-1)==i)?surplus:20)];
            [self arrangeBLData:data0 type:@"SET" sendNum:degree];
            //            [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
        }
    }
}

//设置睡眠检测心率
- (void)setSleepAIDS:(BOOL)open{
    Byte buf[1];
    if(open)
        buf[0]=0x01;
    else
        buf[0]=0x00;
    
    Byte results[14];
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x39 bytes1:buf len:1 results:results];//
        NSData * data0 = [NSData dataWithBytes:results length:14];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

//BEACON广播设置
- (void)setRadioInterval:(int)interval Continuous:(int)time{
    Byte buf[2];
    buf[0] = (Byte)(interval&0xff);
    buf[1] = (Byte)(time&0xff);
    Byte results[15];
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x3A bytes1:buf len:2 results:results];
        NSData * data0 = [NSData dataWithBytes:results length:15];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
    }
}

//12/24小时制设置
- (void)setHourly:(BOOL) hourly{
    Byte buf[1];
    if(hourly)
        buf[0]=0x01;
    else
        buf[0]=0x00;
    
    Byte results[14];
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x3B bytes1:buf len:1 results:results];//
        NSData * data0 = [NSData dataWithBytes:results length:14];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
    }
}

- (void)setBritishSystem:(BOOL)british{
    Byte buf[1];
    if(british)
        buf[0]=0x01;
    else
        buf[0]=0x00;
    
    Byte results[14];
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x45 bytes1:buf len:1 results:results];//
        NSData * data0 = [NSData dataWithBytes:results length:14];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
    }
    
}

- (void)setWeatherUnit:(BOOL)unit {
    Byte buf[1];
    if(unit)
        buf[0]=0x01;
    else
        buf[0]=0x00;
    
    Byte results[14];
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x4C bytes1:buf len:1 results:results];//
        NSData * data0 = [NSData dataWithBytes:results length:14];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
    }
}
//高速模式
- (void)setHighSpeed:(BOOL)open{
    Byte results[17];
    Byte buf[4];
    buf[0] = 0xA5;
    buf[1] = 0xB5;
    buf[2] = 0xC5;
    buf[3] = 0xD5;
    if(self.p && self.Write)
    {
        if (open) {
            [SmaBusinessTool getSpliceCmd:0x02 Key:0x37 bytes1:buf len:4 results:results];
        }
        else{
            [SmaBusinessTool getSpliceCmd:0x02 Key:0x38 bytes1:buf len:4 results:results];
        }
        NSData * data0 = [NSData dataWithBytes:results length:17];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
    }
}

//停止校时
- (void)setStopTiming{
    Byte results[17];
    Byte buf[4];
    buf[0] = 0x00;
    buf[1] = 0x00;
    buf[2] = 0x00;
    buf[3] = 0x00;
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x46 bytes1:buf len:4 results:results];
        NSData * data0 = [NSData dataWithBytes:results length:17];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
    }
}

//准备校时
- (void)setPrepareTiming{
    Byte results[17];
    Byte buf[4];
    buf[0] = 0x01;
    buf[1] = 0x00;
    buf[2] = 0x00;
    buf[3] = 0x00;
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x46 bytes1:buf len:4 results:results];
        NSData * data0 = [NSData dataWithBytes:results length:17];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
    }
}

//取消校时
- (void)setCancelTiming{
    Byte results[17];
    Byte buf[4];
    buf[0] = 0x02;
    buf[1] = 0x00;
    buf[2] = 0x00;
    buf[3] = 0x00;
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x46 bytes1:buf len:4 results:results];
        NSData * data0 = [NSData dataWithBytes:results length:17];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
    }
}

//指针位置
- (void)setPointerHour:(int)hour minute:(int)min second:(int)second{
    Byte results[17];
    Byte buf[4];
    buf[0] = 0x03;
    buf[1] = (Byte)(hour&0xff);;
    buf[2] = (Byte)(min&0xff);;
    buf[3] = (Byte)(second&0xff);;
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x46 bytes1:buf len:4 results:results];
        NSData * data0 = [NSData dataWithBytes:results length:17];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
    }
}

//根据系统时间校时
- (void)setSystemTiming{
    Byte results[17];
    Byte buf[4];
    buf[0] = 0x04;
    buf[1] = 0x00;
    buf[2] = 0x00;
    buf[3] = 0x00;
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x46 bytes1:buf len:4 results:results];
        NSData * data0 = [NSData dataWithBytes:results length:17];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
    }
    
}

//指定时间校时
- (void)setCustomTimingHour:(int)hour minute:(int)min second:(int)second{
    Byte results[17];
    Byte buf[4];
    buf[0] = 0x05;
    buf[1] = (Byte)(hour&0xff);;
    buf[2] = (Byte)(min&0xff);;
    buf[3] = (Byte)(second&0xff);;
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x46 bytes1:buf len:4 results:results];
        NSData * data0 = [NSData dataWithBytes:results length:17];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
    }
}

//设置用户姓名及团队设定
- (void)setNickName:(NSString *)name group:(NSString *)group{
    Byte results[77];
    NSData *nameData = [name dataUsingEncoding:NSUTF8StringEncoding];
    NSData *groupData = [group dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *data = [[NSMutableData alloc] init];
    [data appendData:nameData];
    [data appendData:groupData];
    Byte nameByte[32];
    Byte groupByte[32];
    [nameData getBytes:(void *)nameByte range:NSMakeRange(0, nameData.length)];
    [groupData getBytes:(void *)groupByte range:NSMakeRange(0, groupData.length)];
    Byte all[64];
    memcpy(&all[0], &nameByte, 32);
    memcpy(&all[32], &groupByte, 32);
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x11 bytes1:all len:64 results:results];
        int degree=77/20;
        int surplus=77%20;
        if(surplus>0)
            degree=degree+1;
        for (int i=0; i<degree; i++) {
            int alen=(((degree-1)==i)?surplus:20);
            Byte arr[alen];
            memcpy(&arr,&results[0+(20*i)],alen);//拷贝到对应的Byte 数组中
            NSData * data0 = [NSData dataWithBytes:arr length:(((degree-1)==i)?surplus:20)];
            [self arrangeBLData:data0 type:@"SET" sendNum:degree];
        }
    }
}


/**
 ANCS配对请求
 */
- (void)setPairAncs{
    Byte results[13];
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x47 bytes1:nil len:0 results:results];//设定用户信息
        NSData * data0 = [NSData dataWithBytes:results length:13];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
    }
}

- (void)setPhoneSystemState:(int)system{
    Byte buf[1];
    buf[0] = (Byte)(system&0xff);
    Byte results[14];
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x23 bytes1:buf len:1 results:results];
        NSData * data0 = [NSData dataWithBytes:results length:14];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
    }
}

//设置场馆
- (void)setVenue:(int)venue{
    Byte buf[1];
    buf[0]=(Byte)(venue&0xff);
    Byte results[14];
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x04 Key:0x53 bytes1:buf len:1 results:results];
        NSData * data0 = [NSData dataWithBytes:results length:14];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

- (void)setWeatherForecast:(NSArray<SMAWeatherInfo *> *)weather{
    int counts=(int)weather.count;
    int rscount=13+(counts*4);
    Byte results1[rscount];
    Byte buf[4*counts];
    for (int i = 0; i < weather.count; i ++) {
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSUInteger unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
        NSDateComponents *dateComponent = [calendar components:unitFlags fromDate:[weather objectAtIndex:i].date];
        
        usercdata_union_t user_data;
        user_data.bit_field.second = (int)[dateComponent second];
        user_data.bit_field.minute =  (int)[dateComponent minute];
        user_data.bit_field.hour  = (int)[dateComponent hour];
        user_data.bit_field.day =  (int)[dateComponent day];
        user_data.bit_field.Month = (int)[dateComponent month];
        user_data.bit_field.Year = [dateComponent year]%2000;
        buf[0 + (4 * i)] = (Byte)((weather[i].maxTmp>>0)&0xff);
        buf[1 + (4 * i)] = (Byte)((weather[i].minTmp>>0)&0xff);
        buf[2 + (4 * i)] = (Byte)((weather[i].weatherIcon>>0)&0xff);
        buf[3 + (4 * i)] = (Byte)((weather[i].ultraviolet>>0)&0xff);
    }
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x4b bytes1:buf len:(4*counts) results:results1];//绑定
//    NSData *dat = [NSData dataWithBytes:results1 length:rscount];
    if(self.p && self.Write) {
        int degree=rscount/20;
        int surplus=rscount%20;
        if(surplus>0)
            degree=degree+1;
        for (int i=0; i<degree; i++) {
            int alen = (((degree-1)==i && surplus > 0)?surplus:20);
            Byte arr[alen];
            memcpy(&arr,&results1[0+(20*i)],alen);//拷贝到对应的Byte 数组中
            NSData * data0 = [NSData dataWithBytes:arr length:alen];
            [self arrangeBLData:data0 type:@"SET" sendNum:degree];
        }
    }
}

- (void)setLiveWeather:(SMAWeatherInfo *)weather{
    Byte results1[24];
    Byte buf[11];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSUInteger unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    NSDateComponents *dateComponent = [calendar components:unitFlags fromDate:weather.date];
    
    usercdata_union_t user_data;
    user_data.bit_field.second = (int)[dateComponent second];
    user_data.bit_field.minute =  (int)[dateComponent minute];
    user_data.bit_field.hour  = (int)[dateComponent hour];
    user_data.bit_field.day =  (int)[dateComponent day];
    user_data.bit_field.Month = (int)[dateComponent month];
    user_data.bit_field.Year = [dateComponent year]%2000;
    
    buf[0] = user_data.data>>24;
    buf[1] = user_data.data>>16;
    buf[2] = user_data.data>>8;
    buf[3] = user_data.data>>0;
    buf[4] = weather.nowTmp;
    buf[5] = (Byte)((weather.weatherIcon>>0)&0xff);
    buf[6] = (Byte)((weather.precipitation>>8)&0xff);
    buf[7] = (Byte)((weather.precipitation>>0)&0xff);
    buf[8] = (Byte)((weather.visibility>>0)&0xff);
    buf[9] = (Byte)((weather.windSpeed>>0)&0xff);
    buf[10] = (Byte)((weather.humidity>>0)&0xff);
    
    Byte b[1] ;
    b[0] = -1;
    NSData *dat1 = [NSData dataWithBytes:b length:1];
//    buf[9] = user_data.data>>24;
//    buf[8] = user_data.data>>16;
//    buf[7] = user_data.data>>8;
//    buf[6] = user_data.data>>0;
//    buf[5] = (Byte)((weather.nowTmp>>0)&0xff);
//    buf[4] = (Byte)((weather.weatherIcon>>0)&0xff);
//    buf[3] = (Byte)((weather.precipitation>>0)&0xff);
//    buf[2] = (Byte)((weather.visibility>>0)&0xff);
//    buf[1] = (Byte)((weather.windSpeed>>0)&0xff);
//    buf[0] = (Byte)((weather.humidity>>0)&0xff);
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x49 bytes1:buf len:11 results:results1];//绑定
    NSData *dat = [NSData dataWithBytes:results1 length:24];
    if(self.p && self.Write) {
        int degree=24/20;
        int surplus=24%20;
        if(surplus>0)
            degree=degree+1;
        for (int i=0; i<degree; i++) {
            int alen = (((degree-1)==i && surplus > 0)?surplus:20);
            Byte arr[alen];
            memcpy(&arr,&results1[0+(20*i)],alen);//拷贝到对应的Byte 数组中
            NSData * data0 = [NSData dataWithBytes:arr length:alen];
            [self arrangeBLData:data0 type:@"SET" sendNum:degree];
        }
    }
}

- (void)setGpsWithSpeed:(int)speed elevation:(int)elevation distance:(float)distance{
    Byte gpsByte[5];
    //    NSData *disData = [[NSString stringWithFormat:@"%.1f",distance * 10] dataUsingEncoding:NSUTF8StringEncoding];
    //    Byte *disByte = (Byte *)[disData bytes];
    int dis = (int)(distance * 10);
    gpsByte[4] = (Byte)((dis >> 0) & 0xff);
    gpsByte[3] = (Byte)((dis >> 8) & 0xff);
    gpsByte[2] = (Byte)((elevation >> 0) & 0xff);
    gpsByte[1] = (Byte)((elevation >> 8) & 0xff);
    gpsByte[0] = (Byte)((speed >> 0) & 0xff);
    Byte results1[13 + 5];
    
    if(self.p && self.Write){
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x4a bytes1:gpsByte len:(5) results:results1];//绑定
        NSData * data0 = [NSData dataWithBytes:results1 length:18];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

/**
 *GPS数据同步 （New）
 @param speed 速度 单位：Km/h
 @param elevation 海拔 单位：m
 @param distance 距离 单位 Km
 */
- (void)setGPSWithSpeed:(float)speed Altitude:(int)altitude Distance:(float)distance {
    Byte valueBuf[10];
    Byte speedBuf[4];
    Byte altitudeBuf[2];
    Byte distanceBuf[4];
    
    memcpy(speedBuf, &speed, 4);
    memcpy(altitudeBuf, &altitude, 2);
    memcpy(distanceBuf, &distance, 4);
    
    for (int i=0; i < 10; i++) {
        if (i < 4) {
            valueBuf[i] = speedBuf[3-i];
        }else if (i >= 4 && i < 6) {
            valueBuf[i] = altitudeBuf[5-i];
        }else if (i >= 6 && i < 10) {
            valueBuf[i] = distanceBuf[9-i];
        }
    }
    
    Byte results1[13 + 10];
    
    if(self.p && self.Write){
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x4a bytes1:valueBuf len:(10) results:results1];
        Byte arr1[20];
        memcpy(&arr1,&results1[0],20);
        NSData * data01 = [NSData dataWithBytes:arr1 length:20];
        [self arrangeBLData:data01 type:@"SET" sendNum:2];
        
        Byte arr2[3];
        memcpy(&arr2,&results1[20],3);
        NSData * data02 = [NSData dataWithBytes:arr2 length:3];
        [self arrangeBLData:data02 type:@"SET" sendNum:2];
        
    }
    
    
    
}

- (void)pushMessageTit:(NSString *)tit message:(NSString *)mes{
    Byte titByte[32] = {0};
    NSData *nData = [tit dataUsingEncoding:NSUTF8StringEncoding];
    Byte *testByte = (Byte *)[nData bytes];
    for (int j = 0; j < nData.length; j ++) {
        titByte[j] = testByte[j];
    }
    NSMutableData *resultData = [[NSMutableData alloc] init];
    [resultData appendData:[NSData dataWithBytes:titByte length:32]];
    NSData *pData = [mes dataUsingEncoding:NSUTF8StringEncoding];
    [resultData appendData:pData];
    Byte result[13 + resultData.length];
    [SmaBusinessTool getSpliceCmd:0x04 Key:0x52 bytes1:(Byte *)[resultData bytes] len:(int)(32 + pData.length) results:result];
    if (self.p && self.Write) {
        int rscount = (int)(13 + resultData.length);
        int degree=rscount/20;
        int surplus=rscount%20;
        if(surplus>0)
            degree=degree+1;
        for (int i=0; i<degree; i++) {
            int alen = (((degree-1)==i && surplus > 0)?surplus:20);
            Byte arr[alen];
            memcpy(&arr,&result[0+(20*i)],alen);//拷贝到对应的Byte 数组中
            NSData * data0 = [NSData dataWithBytes:arr length:alen];
            [self arrangeBLData:data0 type:@"SET" sendNum:degree];
        }
    }
}

/*请求07运动数据*/
-(void)requestCuffSportData
{
    Byte results[13];
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x05 Key:0x41 bytes1:nil len:0 results:results];//设定用户信息
        NSData * data0 = [NSData dataWithBytes:results length:13];
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

/*请求07睡眠数据*/
- (void)requestCuffSleepData{
    Byte results[13];
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x05 Key:0x45 bytes1:nil len:0 results:results];//设定用户信息
        NSData * data0 = [NSData dataWithBytes:results length:13];
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

/*请求07心率数据*/
- (void)requestCuffHRData{
    Byte results[13];
    [SmaBusinessTool getSpliceCmd:0x05 Key:0x43 bytes1:nil len:0 results:results];
    NSData * data0 = [NSData dataWithBytes:results length:13];
    if(self.p && self.Write)
    {
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

- (void)requestLastHRData{
    Byte results[13];
    [SmaBusinessTool getSpliceCmd:0x05 Key:0x20 bytes1:nil len:0 results:results];
    NSData * data0 = [NSData dataWithBytes:results length:13];
    if(self.p && self.Write)
    {
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
    }
}

- (void)requestCyclingData{
    Byte results[13];
    [SmaBusinessTool getSpliceCmd:0x05 Key:0x4c bytes1:nil len:0 results:results];
    NSData * data0 = [NSData dataWithBytes:results length:13];
    if(self.p && self.Write)
    {
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
    }
}

- (void)requestGpsData{
    Byte results[13];
    [SmaBusinessTool getSpliceCmd:0x05 Key:0x47 bytes1:nil len:0 results:results];
    NSData * data0 = [NSData dataWithBytes:results length:13];
    if(self.p && self.Write)
    {
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
    }
}

- (void)requestSwimData{
    Byte results[13];
    [SmaBusinessTool getSpliceCmd:0x05 Key:0x4e bytes1:nil len:0 results:results];
    NSData * data0 = [NSData dataWithBytes:results length:13];
    if(self.p && self.Write)
    {
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
    }
}

- (void)requestFindDeviceWithBuzzing:(int)intensity{
    Byte buf[1];
    buf[0] = (Byte)(((intensity > 1 ? 2:intensity)>>0)&0xff);
    Byte results[14];
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x04 Key:0x61 bytes1:buf len:1 results:results];//
        NSData * data0 = [NSData dataWithBytes:results length:14];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
    }
}

//复位手表
- (void)BLrestoration{
    Byte results[17];
    Byte buf[4];
    buf[0] = 0xA5;
    buf[1] = 0xB5;
    buf[2] = 0xC5;
    buf[3] = 0xD5;
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x41 bytes1:buf len:4 results:results];
        NSData * data0 = [NSData dataWithBytes:results length:17];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

//测试模式
- (void)enterTextMode:(BOOL)on{
    Byte results[13];
    if (on) {
        [SmaBusinessTool getSpliceCmd:0x06 Key:0x10 bytes1:nil len:0 results:results];
    }
    else{
        [SmaBusinessTool getSpliceCmd:0x06 Key:0x11 bytes1:nil len:0 results:results];
    }
    
    if(_p && _Write)
    {
        receive_state=0;
        NSData * data0 = [NSData dataWithBytes:results length:13];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [_p writeValue:data0 forCharacteristic:_Write type:CBCharacteristicWriteWithResponse];
    }
}

//点亮LED
- (void)lightLED{
    Byte results[13];
    [SmaBusinessTool getSpliceCmd:0x06 Key:0x05 bytes1:nil len:0 results:results];
    
    if(_p && _Write)
    {
        receive_state=0;
        NSData * data0 = [NSData dataWithBytes:results length:13];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [_p writeValue:data0 forCharacteristic:_Write type:CBCharacteristicWriteWithResponse];
    }
}

//震动马达
- (void)vibrationMotor{
    Byte results[13];
    [SmaBusinessTool getSpliceCmd:0x06 Key:0x06 bytes1:nil len:0 results:results];
    
    if(_p && _Write)
    {
        receive_state=0;
        NSData * data0 = [NSData dataWithBytes:results length:13];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [_p writeValue:data0 forCharacteristic:_Write type:CBCharacteristicWriteWithResponse];
    }
    
}
//获取闹钟列表
-(void)getCalarmClockList{
    Byte results[13];
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x03 bytes1:nil len:0 results:results];//绑定
    
    if(_p && _Write)
    {
        receive_state=0;
        NSData * data0 = [NSData dataWithBytes:results length:13];
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
        //        [_p writeValue:data0 forCharacteristic:_Write type:CBCharacteristicWriteWithResponse];
    }
}

//获取07闹钟列表
-(void)getCuffCalarmClockList{
    Byte results[13];
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x2d bytes1:nil len:0 results:results];//绑定
    if(self.p && self.Write)
    {
        receive_state=0;
        NSData * data0 = [NSData dataWithBytes:results length:13];
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

//请求运动数据
-(void)requestExerciseData{
    Byte results[13];
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x05 Key:0x01 bytes1:nil len:0 results:results];//设定用户信息
        NSData * data0 = [NSData dataWithBytes:results length:13];
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}


- (void)requestSportDataV2{
    Byte results[13];
    if(self.p && self.Write) {
        [SmaBusinessTool getSpliceCmd:0x05 Key:0x35 bytes1:nil len:0 results:results];//设定用户信息
        NSData * data0 = [NSData dataWithBytes:results length:13];
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
        //[self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

-(void)getBloodPressure{
    Byte results[13];
    if(self.p && self.Write)
    {
        [SmaBusinessTool getSpliceCmd:0x05 Key:0x49 bytes1:nil len:0 results:results];//设定用户信息
        NSData * data0 = [NSData dataWithBytes:results length:13];
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

/*获取手表时间*/
- (void)getWatchDate{
    Byte results[13];
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x06 bytes1:nil len:0 results:results];
    NSData * data0 = [NSData dataWithBytes:results length:13];
    if(self.p && self.Write)
    {
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

-(void)getElectric
{
    if(self.p && self.Write) {
        Byte results[13];
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x08 bytes1:nil len:0 results:results];
        NSData * data0 = [NSData dataWithBytes:results length:13];
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

//获取蓝牙硬件版本（05）
- (void)getBLVersion{
    Byte results[13];
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x0A bytes1:nil len:0 results:results];
    NSData * data0 = [NSData dataWithBytes:results length:13];
    if(self.p && self.Write)
    {
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

//获取蓝牙硬件MAC
- (void)getBLmac{
    Byte results[13];
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x0C bytes1:nil len:0 results:results];
    NSData * data0 = [NSData dataWithBytes:results length:13];
    if(self.p && self.Write)
    {
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
    
}

//获取表盘编号(10-A）
- (void)getSwitchNumber{
    Byte results[13];
    [SmaBusinessTool getSpliceCmd:0x01 Key:0x31 bytes1:nil len:0 results:results];
    NSData * data0 = [NSData dataWithBytes:results length:13];
    if(self.p && self.Write)
    {
        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

//获取计步目标
- (void)getGoal{
    Byte results[13];
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x62 bytes1:nil len:0 results:results];
    NSData * data0 = [NSData dataWithBytes:results length:13];
    if(self.p && self.Write)
    {
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
    }
}

- (void)getLongTime{
    Byte results[13];
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x65 bytes1:nil len:0 results:results];
    NSData * data0 = [NSData dataWithBytes:results length:13];
    if(self.p && self.Write)
    {
        [self arrangeBLData:data0 type:@"GET" sendNum:1];
    }
}

//进入XOMDEM模式（10-A）
- (void)enterXmodem{
    Byte results[13];
    [SmaBusinessTool getSpliceCmd:0x01 Key:0x21 bytes1:nil len:0 results:results];
    NSData * data0 = [NSData dataWithBytes:results length:13];
    if(self.p && self.Write)
    {
        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
}

- (void)endXMODEM{
    binNum = (int)self.BinArr.count;
    numbend = NO;
    _isUPDateSwitch = NO;
    _isUPDateFont = NO;
}

//解析表盘数据包
- (void)analySwitchs:(NSString *)name replace:(int)number {
    _switchNumber = number;
    NSData *data=[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:name ofType:@"bin"]];
    binNum = 0;
    [self.BinArr removeAllObjects];
    self.BinArr = nil;
    if (!self.BinArr) {
        self.BinArr = [NSMutableArray array];
    }
    Byte tempbyt[1]={(_switchNumber&0xff)+ 0x30};
    [self.BinArr addObject:[NSData dataWithBytes:tempbyt length:1]];
    int datNum = [NSString stringWithFormat:@"%lu",(unsigned long)data.length].intValue/128;
    Byte cmd_data[128];
    Byte result[133];
    for (int i = 0; i < datNum; i ++) {
        [data getBytes:(void *)cmd_data range:NSMakeRange(i*128,128)];
        [SmaBusinessTool setBinData:cmd_data result:result byteInt:i+1];
        [self.BinArr addObject:[NSData dataWithBytes:result length:133]];
    }
    
    Byte byt[1];
    byt[0] = 0x71;
    //    NSLog( @"self.BinArrSwitch==%@ %lu", self.BinArr, (unsigned long)self.BinArr.count);
}

//解析表盘数据包
- (void)analySwitchsWithdata:(NSData *)data replace:(int)number{
    _switchNumber = number;
    //    NSData *data=[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:name ofType:@"bin"]];
    binNum = 0;
    [self.BinArr removeAllObjects];
    self.BinArr = nil;
    if (!self.BinArr) {
        self.BinArr = [NSMutableArray array];
    }
    Byte tempbyt[1]={(_switchNumber&0xff)+ 0x30};
    [self.BinArr addObject:[NSData dataWithBytes:tempbyt length:1]];
    int datNum = [NSString stringWithFormat:@"%lu",(unsigned long)data.length].intValue/128;
    Byte cmd_data[128];
    Byte result[133];
    for (int i = 0; i < datNum; i ++) {
        [data getBytes:(void *)cmd_data range:NSMakeRange(i*128,128)];
        [SmaBusinessTool setBinData:cmd_data result:result byteInt:i+1];
        [ self.BinArr addObject:[NSData dataWithBytes:result length:133]];
    }
    
    Byte byt[1];
    byt[0] = 0x71;
    //    NSLog( @"self.BinArrSwitch==%@ %lu", self.BinArr, (unsigned long)self.BinArr.count);
}

//解析字库数据包
- (void)setFontBin:(NSData *)data {
    binNum = 0;
    [self.BinArr removeAllObjects];
    self.BinArr = nil;
    if (!self.BinArr) {
        self.BinArr = [NSMutableArray array];
    }
    int datNum = [NSString stringWithFormat:@"%lu",(unsigned long)data.length].intValue/128;
    Byte cmd_data[128];
    Byte result[133];
    for (int i = 0; i < datNum; i ++) {
        [data getBytes:(void *)cmd_data range:NSMakeRange(i*128,128)];
        [SmaBusinessTool setBinData:cmd_data result:result byteInt:i+1];
        [ self.BinArr addObject:[NSData dataWithBytes:result length:133]];
    }
}

/*用户ID begin*/
typedef struct
{
    uint32_t userId   :
    32; /*秒*/
}
username_bit_field_type_t;

typedef union {
    uint32_t data;
    username_bit_field_type_t bit_field;
} username_union_t;
/*用户ID begin*/

typedef struct
{
    uint8_t monday     :
    1;
    uint8_t  tuesday     :
    1;
    uint8_t  wednesday      :
    1;
    uint8_t thursday      :
    1;
    uint8_t  friday     :
    1;
    uint8_t saturday    :
    1;
    uint8_t  sunday     :
    1;
    uint8_t  isopen     :
    1;
    
}burntheplanks_pepeat_week_t;

typedef union {
    uint8_t week;
    burntheplanks_pepeat_week_t bit_week;
} burntheplanks_week_union_t;

/*闹钟结构体 begin*/
typedef struct
{
    uint64_t day_repeat_flag    :
    7;
    uint64_t reserved   :
    4;
    uint64_t id     :
    3;
    uint64_t minute     :
    6;
    uint64_t hour       :
    5;
    uint64_t day            :
    5;
    uint64_t month      :
    4;
    uint64_t year           :
    6;
}
alarm_clock_bit_field_type_t;

typedef union {
    uint64_t data;
    alarm_clock_bit_field_type_t alarm;
} alarm_union_t;

/*用户信息开始 begin*/
typedef struct
{
    uint32_t reserved   :
    5;
    uint32_t weight     :
    10; /** accuracy: 0.5 kg, */
    uint32_t hight      :
    9;  /** hight accuracy : 0.5 m */
    uint32_t age        :
    7;  /**age 0~127*/
    uint32_t gender     :
    1;  /**0: female, 1: male*/
}
userprofile_bit_field_type_t;


typedef union {
    uint32_t data;
    userprofile_bit_field_type_t bit_field;
} userprofile_union_t;
/*用户信息开始 end*/

/*闹钟结构体  end*/

/*系统时间结构 begin*/
typedef struct
{
    uint32_t second   :
    6; /*秒*/
    uint32_t minute     :
    6; /*分*/
    uint32_t hour      :
    5;  /*时*/
    uint32_t day     :
    5;  /*日*/
    uint32_t Month     :
    4;  /*月*/
    uint32_t Year     :
    6;  /*年*/
}
userdatatime_bit_field_type_t;

typedef union {
    uint32_t data;
    userdatatime_bit_field_type_t bit_field;
} usercdata_union_t;
/*系统时间结构 end*/

/* 防丢 begin */

typedef struct
{
    uint8_t mode   :
    5;
    uint8_t reserve     :
    3;
}
defendlose_bit_field_type_t;

typedef union {
    uint8_t data;
    defendlose_bit_field_type_t bit_fieldreserve;
} defendlose_union_t;

/*防丢信息结束 begin*/

/*久坐设置 begin*/
typedef struct
{
    uint64_t dayflags     :
    8;
    uint64_t endtime     :
    8;
    uint64_t begintime     :
    8;
    uint64_t whenminute     :
    8;
    uint64_t  thresholdvalue     :
    16;
    uint64_t enable    :
    8;
    uint64_t  reserve     :
    8;
}
burntheplanks_bit_field_type_t;

typedef union {
    uint64_t data;
    burntheplanks_bit_field_type_t bit_plank;
} burntheplanks_union_t;

/*久坐V2*/
typedef struct{
    uint64_t reserve:4;
    uint64_t isopen:8;
    uint64_t thresholdvalue:16;
    uint64_t cycle:8;
    uint64_t beginTim1:5;
    uint64_t endTime1:5;
    uint64_t beginTim2:5;
    uint64_t endTime2:5;
    uint64_t dayflags:
    8;
}burntheplanksV2_pepeat_week_t;

typedef union {
    uint64_t data;
    burntheplanksV2_pepeat_week_t bit_plank;
} burntheplanksV2_union_t;

///*久坐V2(2)*/
//typedef struct{
//    uint64_t reserve:4;
//    uint64_t isopen:8;
//    uint64_t thresholdvalue:16;
//    uint64_t cycle:8;
//    uint64_t sedentaryTime:20;
////    uint64_t endTime1:5;
////    uint64_t beginTim2:5;
////    uint64_t endTime2:5;
//    uint64_t dayflags:
//    8;
//}sedentaryV2_pepeat_week_t;
//
//typedef union {
//    uint64_t data;
//    sedentaryV2_pepeat_week_t bit_plank;
//} sedentaryV2_union_t;
//
//typedef struct{
//    uint64_t beginTime:5;
//    uint64_t endTime:5;
//}sedentaryTime_struct;
//
//typedef union{
//     uint64_t time;
//    sedentaryTime_struct bit_time;
//}sedentaryTime_union;

/*记步目标 begin*/
typedef struct
{
    uint32_t stepnumber   :
    32; /*秒*/
}
stepnumber_bit_field_type_t;

typedef union {
    uint32_t data;
    stepnumber_bit_field_type_t step_number;
} stepnumber_union_t;
/*记步目标 begin*/
//APP数据同步手表
typedef struct
{
    uint64_t calor : 32;
    uint64_t distance : 32;
    
}appSportData;

typedef union{
    uint64_t data;
    appSportData stort_data;
}sport_data;

typedef struct
{
    uint32_t step : 32;
}appStepData;

typedef union{
    uint32_t data;
    appStepData St_data;
}step_data;
/*运动数据结束 end*/

typedef struct
{
    uint16_t day   :
    5;
    uint16_t month  :
    4;
    uint16_t year   :
    6;
    uint16_t reserved   :
    1;
}
Date_bit_field_type_t;

typedef union
{
    uint16_t data;
    Date_bit_field_type_t date;
} Date_union_t;

typedef struct SportsHead
{
    uint8_t key;
    uint8_t length;
    Date_union_t Date;
}
SportsHead_t;

typedef struct
{
    uint64_t Distance  :
    16;
    uint64_t Calory   :
    19;
    uint64_t active_time :
    4;
    uint64_t steps   :
    12;
    uint64_t mode   :
    2;
    uint64_t offset   :
    11;
}
SportsData_bit_field_type_t;

typedef union SportsData {
    uint64_t data;
    SportsData_bit_field_type_t bits;
} SportsData_U;

typedef struct SleepHead
{
    Date_union_t Date;
    uint16_t length;
}
SleepHead_t;

typedef struct
{
    uint32_t mode   :
    4;
    uint32_t sleeping_flag :
    1;
    uint32_t reserved  :
    11;
    uint32_t timeStamp  :
    16;
}
SleepData_bit_field_type_t;

typedef union SleepDataU {
    uint32_t data;
    SleepData_bit_field_type_t bits;
} SleepData_U;

typedef struct{
    uint32_t second:6;
    uint32_t minute:6;
    uint32_t hour:5;
    uint32_t day:5;
    uint32_t month:4;
    uint32_t year:6;
}
systemDate;

typedef union{
    uint32_t data;
    systemDate date;
}systemDate_union;

/*心率设置 begin*/
typedef struct
{
    uint64_t dayflags:
    8;
    uint64_t time:
    8;
    uint64_t end1_hour:
    8;
    uint64_t start1_hour:
    8;
    uint64_t  end2_hour:
    8;
    uint64_t start2_hour:
    8;
    uint64_t  end3_hour :
    8;
    uint64_t  start3_hour :
    8;
}
hrtheplanks_bit_field_type_t;

typedef union {
    uint64_t data;
    hrtheplanks_bit_field_type_t bit_planks;
} hrtheplanks_week_union_t;

/*震动V2*/
typedef struct {
    uint8_t number:4;
    uint8_t level:4;//reserved
}vibration_data;

typedef union{
    uint8_t data;
    vibration_data vibrationData;
}vibration_union;


/*天气结构体 begin*/
typedef struct
{
    uint8_t nowTmp    :
    8;
    uint8_t maxTmp   :
    8;
    uint8_t minTmp     :
    8;
    uint8_t weatherIcon     :
    8;
    uint8_t precipitation       :
    8;
    uint8_t visibility            :
    8;
    uint8_t windSpeed      :
    8;
    uint8_t humidity           :
    8;
    uint8_t ultraviolet           :
    8;
}
weather_data;

//typedef union {
//    uint64_t data;
//    alarm_clock_bit_field_type_t alarm;
//} alarm_union_t;
//解析闹钟
-(NSMutableArray *)analysisAlarmClockData:(Byte *)bytes len:(int)len
{
    NSMutableArray *alarmArr = [NSMutableArray array];
    int begin=12;
    int listLen=(len-13)/5;
    for (int i=0; i<listLen; i++) {
        alarm_union_t user_clock;
        user_clock.data=(((uint64_t)bytes[begin+(1+(i*5))])<<32)+((uint64_t)bytes[begin+(2+(i*5))]<<24)+((uint64_t)bytes[begin+(3+(i*5))]<<16)+((uint64_t)bytes[begin+(4+(i*5))]<<8)+((uint64_t)bytes[begin+(5+(i*5))]<<0);
        
        SmaAlarmInfo *alarInfo=[[SmaAlarmInfo alloc]init];
        alarInfo.year=[NSString stringWithFormat:@"%d",user_clock.alarm.year + 2000];
        alarInfo.mounth=[NSString stringWithFormat:@"%d",user_clock.alarm.month];
        alarInfo.day=[NSString stringWithFormat:@"%d",user_clock.alarm.day];
        alarInfo.hour=[NSString stringWithFormat:@"%d",user_clock.alarm.hour];
        alarInfo.minute=[NSString stringWithFormat:@"%d",user_clock.alarm.minute];
        alarInfo.mounth=[NSString stringWithFormat:@"%d",user_clock.alarm.month];
        alarInfo.aid=[NSString stringWithFormat:@"%d",user_clock.alarm.id];
        
        burntheplanks_week_union_t week_t1;
        week_t1.week=user_clock.alarm.day_repeat_flag;
        //        NSString *str=[NSString stringWithFormat:@"%d%d%d%d%d%d%d",week_t1.bit_week.monday,week_t1.bit_week.tuesday,week_t1.bit_week.wednesday,week_t1.bit_week.thursday,week_t1.bit_week.friday,week_t1.bit_week.saturday,week_t1.bit_week.sunday];
        alarInfo.dayFlags=[NSString stringWithFormat:@"%d",user_clock.alarm.day_repeat_flag];
        //clock_data.alarm.day_repeat_flag =week_t1.week;
        //        alarInfo.dayFlags=str;
        [alarmArr addObject:alarInfo];
    }
    return alarmArr;
}

//解析07闹钟
-(NSMutableArray *)analysisCuffAlarmClockData:(Byte *)bytes len:(int)len
{
    //    NSLog(@"alarmData = %@", [[NSData alloc] initWithBytes:bytes length:len]);
    NSMutableArray *alarmArr = [NSMutableArray array];
    int begin=12;
    int listLen=(len-13)/23;
    for (int i=0; i<listLen; i++) {
        alarm_union_t user_clock;
        user_clock.data = (((uint64_t)bytes[begin+(1+(i*23))])<<32)+((uint64_t)bytes[begin+(2+(i*23))]<<24)+((uint64_t)bytes[begin+(3+(i*23))]<<16)+((uint64_t)bytes[begin+(4+(i*23))]<<8)+((uint64_t)bytes[begin+(5+(i*23))]<<0);
        
        SmaAlarmInfo *alarInfo = [[SmaAlarmInfo alloc]init];
        alarInfo.year = [NSString stringWithFormat:@"%d",user_clock.alarm.year + 2000];
        alarInfo.mounth = [NSString stringWithFormat:@"%@%d",user_clock.alarm.month > 9 ? @"":@"0",user_clock.alarm.month];
        alarInfo.day = [NSString stringWithFormat:@"%@%d",user_clock.alarm.day > 9 ? @"":@"0",user_clock.alarm.day];
        alarInfo.hour = [NSString stringWithFormat:@"%@%d",user_clock.alarm.hour > 9 ? @"":@"0",user_clock.alarm.hour];
        alarInfo.minute = [NSString stringWithFormat:@"%@%d",user_clock.alarm.minute > 9 ? @"":@"0",user_clock.alarm.minute];
        alarInfo.dayFlags = [NSString stringWithFormat:@"%d",user_clock.alarm.day_repeat_flag];
        alarInfo.aid = [NSString stringWithFormat:@"%d",user_clock.alarm.id];
        alarInfo.isOpen = [NSString stringWithFormat:@"%d",user_clock.alarm.reserved];
        
        burntheplanks_week_union_t week_t1;
        week_t1.week=user_clock.alarm.day_repeat_flag;
        
        //        NSString *str=[NSString stringWithFormat:@"%d,%d,%d,%d,%d,%d,%d",week_t1.bit_week.monday,week_t1.bit_week.tuesday,week_t1.bit_week.wednesday,week_t1.bit_week.thursday,week_t1.bit_week.friday,week_t1.bit_week.saturday,week_t1.bit_week.sunday];
        alarInfo.dayFlags= [self toDecimalSystemWithBinarySystem:[NSString stringWithFormat:@"%d%d%d%d%d%d%d",week_t1.bit_week.monday,week_t1.bit_week.tuesday,week_t1.bit_week.wednesday,week_t1.bit_week.thursday,week_t1.bit_week.friday,week_t1.bit_week.saturday,week_t1.bit_week.sunday]];
        //        alarInfo.dayFlags=str;
        
        Byte alarmName[18];
        memcpy(&alarmName[0],&bytes[begin+6+(i*23)], 18);
        NSString* str1 = [[NSString alloc] initWithData:[NSData dataWithBytes:alarmName length:18] encoding:NSUTF8StringEncoding];
        alarInfo.tagname = str1;
        [alarmArr addObject:alarInfo];
        //        MyLog(@"在组装闹钟 %@  %@",[NSData dataWithBytes:alarmName length:18],str1);
    }
    return alarmArr;
}

- (NSMutableArray *)analysisLongTimeData:(Byte *)bytes len:(int)len{
    //    NSLog(@"longTimeData = %@", [[NSData alloc] initWithBytes:bytes length:len]);
    NSMutableArray *longArr = [NSMutableArray array];
    burntheplanksV2_union_t burnthe_t;
    burnthe_t.data = (((uint64_t)bytes[13])<<56) + (((uint64_t)bytes[14])<<48) + (((uint64_t)bytes[15])<<40) + (((uint64_t)bytes[16])<<32) + (((uint64_t)bytes[17])<<24) + (((uint64_t)bytes[18])<<16) + (((uint64_t)bytes[19])<<8) + (((uint64_t)bytes[20])<<0);
    //     burnthe_t.data = (((uint64_t)0x00)<<56) + (((uint64_t)0x00)<<48) + (((uint64_t)0x00)<<40) + (((uint64_t)0x00)<<32) + (((uint64_t)0x00)<<24) + (((uint64_t)0x00)<<16) + (((uint64_t)0x00)<<8) + (((uint64_t)0x00)<<0);
    if (burnthe_t.data != 0) {
        SmaSeatInfo *info = [[SmaSeatInfo alloc] init];
        info.isOpen = [NSString stringWithFormat:@"%d",burnthe_t.bit_plank.isopen];
        burntheplanks_week_union_t week_t1;
        week_t1.week = burnthe_t.bit_plank.dayflags;
        info.repeatWeek = [self toDecimalSystemWithBinarySystem:[NSString stringWithFormat:@"%d%d%d%d%d%d%d",week_t1.bit_week.monday,week_t1.bit_week.tuesday,week_t1.bit_week.wednesday,week_t1.bit_week.thursday,week_t1.bit_week.friday,week_t1.bit_week.saturday,week_t1.bit_week.sunday]];
        info.seatValue = [NSString stringWithFormat:@"%d",burnthe_t.bit_plank.cycle];
        info.stepValue = [NSString stringWithFormat:@"%d",burnthe_t.bit_plank.thresholdvalue];
        info.beginTime0 = [NSString stringWithFormat:@"%d",burnthe_t.bit_plank.beginTim1];
        info.endTime0 = [NSString stringWithFormat:@"%d",burnthe_t.bit_plank.endTime1];
        info.isOpen0 = (burnthe_t.bit_plank.beginTim1 >= 24 || burnthe_t.bit_plank.endTime1 >= 24) ? @"0":@"1";
        info.beginTime1 = [NSString stringWithFormat:@"%d",burnthe_t.bit_plank.beginTim2];
        info.endTime1 = [NSString stringWithFormat:@"%d",burnthe_t.bit_plank.endTime2];
        info.isOpen1 = (burnthe_t.bit_plank.beginTim2 >= 24 || burnthe_t.bit_plank.endTime2 >= 24) ? @"0":@"1";
        [longArr addObject:info];
    }
    else{
        NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:@"NODATA",@"NODATA", nil];
        [longArr addObject:dic];
    }
    return longArr;
}

//--解析运动数据Ok
-(NSMutableArray *)analySportData:(Byte *)bytes1 len:(int)len
{
    NSMutableArray *infos=[NSMutableArray array];
    SportsHead_t sport_head;
    sport_head.Date.data=((uint16_t)bytes1[13]<<8)+((uint16_t)bytes1[14]<<0);
    sport_head.length=((uint8_t)bytes1[16]<<0);
    int count=sport_head.length;
    //    NSDateFormatter *dateFor = [[NSDateFormatter alloc] init];
    //    [dateFor setDateFormat:@"yyyyMMdd"];
    int begin=16;
    for (int i=0; i<count; i++) {
        SportsData_U sport_data;
        sport_data.data=((uint64_t)bytes1[begin+(1+(i*8))]<<56)+((uint64_t)bytes1[begin+(2+(i*8))]<<48)+((uint64_t)bytes1[begin+(3+(i*8))]<<40)+((uint64_t)bytes1[begin+(4+(i*8))]<<32)+((uint64_t)bytes1[begin+(5+(i*8))]<<24)+((uint64_t)bytes1[begin+(6+(i*8))]<<16)+((uint64_t)bytes1[begin+(7+(i*8))]<<8)+((uint64_t)bytes1[begin+(8+(i*8))]<<0);
        int temp=sport_head.Date.date.month;
        NSString *month=[NSString stringWithFormat:@"%d",temp];
        if(temp<10)
            month=[NSString stringWithFormat:@"%@%@",@"0",month];
        int temp1=sport_head.Date.date.day;
        NSString *day=[NSString stringWithFormat:@"%d",temp1];
        if(temp1<10)
            day=[NSString stringWithFormat:@"%@%@",@"0",day];
        NSString *sleep_date=[NSString stringWithFormat:@"%@%d%@%@",@"20",sport_head.Date.date.year,month,day];
        // NSDate *accurateDate = [NSDate dateWithTimeInterval:sport_data.bits.offset*15/1440 * 24*3600 sinceDate:[dateFor dateFromString:sleep_date]];
        // NSString *sleep_da = [dateFor stringFromDate:accurateDate];
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithObjectsAndKeys:sleep_date,@"sport_date",[NSString stringWithFormat:@"%d",sport_data.bits.steps],@"sport_steps",[NSString stringWithFormat:@"%llu",sport_data.bits.Calory],@"sport_cal",[NSString stringWithFormat:@"%llu",sport_data.bits.Distance],@"sport_dist",[NSString stringWithFormat:@"%llu",sport_data.bits.offset],@"sport_time",[NSString stringWithFormat:@"%llu",sport_data.bits.active_time],@"sport_actTime", nil];
        [infos addObject:dic];
    }
    return infos;
}

//07运动数据
static NSMutableArray *sportArr;
- (NSMutableArray *)manualSportWithData:(Byte *)byte Len:(int)len{
    if (!sportArr) {
        sportArr = [NSMutableArray array];
    }
    NSMutableArray *allSpArr=[NSMutableArray array];
    NSTimeZone* GTMzone = [NSTimeZone timeZoneForSecondsFromGMT:0];//解决不同时令相差1小时问题
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMddHHmmss"];
    [formatter setTimeZone:GTMzone];
    [formatter setLocale: [NSLocale systemLocale]];
    int dataLen = byte[11]*pow(16, 2) + byte[12];
    if (dataLen == 0) {
        if (sportArr.count == 0) {
            NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:@"NODATA",@"NODATA", nil];
            [allSpArr addObject:dic];
        }
        else{
            allSpArr = [sportArr mutableCopy];
            [sportArr removeAllObjects];
            sportArr = nil;
        }
    }
    NSString *step;
    NSString *mode;
    NSInteger time;
    //    NSLog(@"sportdata = %@",[NSData dataWithBytes:byte length:len]);
    for (int i = 0; i<dataLen/8; i++) {
        time = byte[13+8*i]*pow(16, 6) + byte[14+8*i]*pow(16, 4) + byte[15+8*i]*pow(16, 2) + byte[16+8*i];
        mode = [NSString stringWithFormat:@"%d",byte[17+8*i]];
        step = [NSString stringWithFormat:@"%.0f",/*byte[17+8*i]*pow(16, 6) +*/ byte[18+8*i]*pow(16, 4) + byte[19+8*i]*pow(16, 2) + byte[20+8*i]];
        NSDate *date = [[NSDate alloc] initWithTimeInterval:time sinceDate:[formatter dateFromString:@"20000101000000"]];
        NSString *timestr = [formatter stringFromDate:date];
        NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:timestr,@"DATE",step,@"STEP",mode,@"MODE", nil];
        [sportArr addObject:dic];
        if (i==dataLen/8-1&&dataLen==160) {
            [self requestCuffSportData];
        }
        if (i==dataLen/8-1&&dataLen!=160){
            allSpArr = [sportArr mutableCopy];
            [sportArr removeAllObjects];
            sportArr = nil;
        }
    }
    return allSpArr;
}

//07运动模式
static NSMutableArray *runArr;
- (NSMutableArray *)manualSportRunWithData:(Byte *)byte Len:(int)len{
    if (!runArr) {
        runArr = [NSMutableArray array];
    }
    NSMutableArray *allSpArr=[NSMutableArray array];
    NSTimeZone* GTMzone = [NSTimeZone timeZoneForSecondsFromGMT:0];//解决不同时令相差1小时问题
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMddHHmmss"];
    [formatter setLocale: [NSLocale systemLocale]];
    [formatter setTimeZone:GTMzone];
    int dataLen = byte[11]*pow(16, 2) + byte[12];
    if (dataLen == 0) {
        if (runArr.count == 0) {
            NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:@"NODATA",@"NODATA",@"1",@"VERSION", nil];
            [allSpArr addObject:dic];
        }
        else{
            allSpArr = [runArr mutableCopy];
            [runArr removeAllObjects];
            runArr = nil;
        }
    }
    NSString *step;
    NSString *mode;
    NSInteger time;
    //    NSLog(@"runArrsportdata = %@",[NSData dataWithBytes:byte length:len]);
    for (int i = 0; i<dataLen/8; i++) {
        time = byte[13+8*i]*pow(16, 6) + byte[14+8*i]*pow(16, 4) + byte[15+8*i]*pow(16, 2) + byte[16+8*i];
        mode = [NSString stringWithFormat:@"%d",byte[17+8*i]];
        step = [NSString stringWithFormat:@"%.0f",/*byte[17+8*i]*pow(16, 6) +*/ byte[18+8*i]*pow(16, 4) + byte[19+8*i]*pow(16, 2) + byte[20+8*i]];
        NSDate *date = [[NSDate alloc] initWithTimeInterval:time sinceDate:[formatter dateFromString:@"20000101000000"]];
        NSString *timestr = [formatter stringFromDate:date];
        NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:timestr,@"DATE",step,@"STEP",mode,@"MODE",@"1",@"VERSION", nil];
        [runArr addObject:dic];
        if (i==dataLen/8-1&&dataLen==160) {
            [self requestCuffSportData];
        }
        if (i==dataLen/8-1&&dataLen!=160){
            allSpArr = [runArr mutableCopy];
            [runArr removeAllObjects];
            runArr = nil;
        }
    }
    return allSpArr;
}

//07运动模式
static NSMutableArray *runArrV2;
- (NSMutableArray *)manualSportV2RunWithData:(Byte *)byte Len:(int)len{
    if (!runArrV2) {
        runArrV2 = [NSMutableArray array];
    }
    NSMutableArray *allSpArr=[NSMutableArray array];
    NSTimeZone* GTMzone = [NSTimeZone timeZoneForSecondsFromGMT:0];//解决不同时令相差1小时问题
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMddHHmmss"];
    [formatter setLocale: [NSLocale systemLocale]];
    [formatter setTimeZone:GTMzone];
    int dataLen = byte[11]*pow(16, 2) + byte[12];
    if (dataLen == 0) {
        if (runArrV2.count == 0) {
            NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:@"NODATA",@"NODATA",@"2",@"VERSION", nil];
            [allSpArr addObject:dic];
        }
        else{
            allSpArr = [runArrV2 mutableCopy];
            [runArrV2 removeAllObjects];
            runArrV2 = nil;
        }
    }
    NSString *step;
    NSString *mode;
    NSInteger starTime;
    NSInteger endTime;
    NSString *sportTime;
    NSString *elevation;//海拔
    NSString *pressure;//气压
    NSString *frequency;//步频
    NSString *distance;
    NSString *cal;
    NSString *speed;//速度
    NSString *pace;//配速
    
    NSLog(@"runArrsportdata222 = %@",[NSData dataWithBytes:byte length:len]);
    for (int i = 0; i<dataLen/34; i++) {
        starTime = byte[13+34*i]*pow(16, 6) + byte[14+34*i]*pow(16, 4) + byte[15+34*i]*pow(16, 2) + byte[16+34*i];
        endTime = byte[17+34*i]*pow(16, 6) + byte[18+34*i]*pow(16, 4) + byte[19+34*i]*pow(16, 2) + byte[20+34*i];
        sportTime = [NSString stringWithFormat:@"%.0f",byte[21+34*i]*pow(16, 6) + byte[22+34*i]*pow(16, 4) + byte[23+34*i]*pow(16, 2) + byte[24+34*i]];
        elevation = [NSString stringWithFormat:@"%.0f",byte[25+34*i]*pow(16, 2) + byte[26+34*i]];
        pressure = [NSString stringWithFormat:@"%.0f",byte[27+34*i]*pow(16, 2) + byte[28+34*i]];
        frequency = [NSString stringWithFormat:@"%d",byte[29+34*i]];
        mode = [NSString stringWithFormat:@"%d",byte[30+34*i]];
        step = [NSString stringWithFormat:@"%.0f",byte[31+34*i]*pow(16, 6) + byte[32+34*i]*pow(16, 4) + byte[33+34*i]*pow(16, 2) + byte[34+34*i]];
        distance = [NSString stringWithFormat:@"%f",(byte[35+34*i]*pow(16, 6) + byte[36+34*i]*pow(16, 4) + byte[37+34*i]*pow(16, 2) + byte[38+34*i])/1000.0];
        cal = [NSString stringWithFormat:@"%.0f",byte[39+34*i]*pow(16, 6) + byte[40+34*i]*pow(16, 4) + byte[41+34*i]*pow(16, 2) + byte[42+34*i]];
        speed = [NSString stringWithFormat:@"%.0f",byte[43+34*i]*pow(16, 2) + byte[44+34*i]];
        pace = [NSString stringWithFormat:@"%.0f",byte[45+34*i]*pow(16, 2) + byte[46+34*i]];
        
        NSDate *starDate = [[NSDate alloc] initWithTimeInterval:starTime sinceDate:[formatter dateFromString:@"20000101000000"]];
        NSDate *endDate = [[NSDate alloc] initWithTimeInterval:endTime sinceDate:[formatter dateFromString:@"20000101000000"]];
        NSString *starTimestr = [formatter stringFromDate:starDate];
        NSString *endTimestr = [formatter stringFromDate:endDate];
        NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:starTimestr,@"STARTDATE",endTimestr,@"ENDDATE",sportTime,@"RUNTIME",elevation,@"ELEVATION",pressure,@"AIRPRESSURE",frequency,@"STEPFREQUENCY",step,@"STEP",mode,@"MODE",distance,@"DISTANCE",cal,@"CAL",speed,@"SPEED",pace,@"PACE",@"2",@"VERSION", nil];
        [runArrV2 addObject:dic];
        if (i==dataLen/34-1&&dataLen==170) {
            [self requestSportDataV2];
        }
        if (i==dataLen/34-1&&dataLen!=170){
            allSpArr = [runArrV2 mutableCopy];
            [runArrV2 removeAllObjects];
            runArrV2 = nil;
        }
    }
    return allSpArr;
}

//－－－－－－－－－－－－－解析睡眠数据ok
-(NSMutableArray *)analysisSleepData:(Byte *)bytes1 len:(int)len
{
    NSMutableArray *infos=[NSMutableArray array];
    SleepHead_t sleep_head;
    sleep_head.Date.data=((uint16_t)bytes1[13]<<8)+((uint16_t)bytes1[14]<<0);
    sleep_head.length=((uint16_t)bytes1[15]<<8)+((uint16_t)bytes1[16]<<0);
    int count=sleep_head.length;
    int begin=16;
    for (int i=0; i<count; i++) {
        SleepData_U sleep_data;
        sleep_data.data=((uint32_t)bytes1[begin+(1+(i*4))]<<24)+((uint32_t)bytes1[begin+(2+(i*4))]<<16)+((uint32_t)bytes1[begin+(3+(i*4))]<<8)+((uint32_t)bytes1[begin+(4+(i*4))]<<0);
        int temp=sleep_head.Date.date.month;
        NSString *month=[NSString stringWithFormat:@"%d",temp];
        if(temp<10)
            month=[NSString stringWithFormat:@"%@%@",@"0",month];
        int temp1=sleep_head.Date.date.day;
        NSString *day=[NSString stringWithFormat:@"%d",temp1];
        if(temp1<10)
            day=[NSString stringWithFormat:@"%@%@",@"0",day];
        
        NSString *slee_da = [NSString stringWithFormat:@"%@%d%@%@",@"20",sleep_head.Date.date.year,month,day];
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithObjectsAndKeys:slee_da,@"sleep_date",[NSString stringWithFormat:@"%d",sleep_data.bits.mode],@"sleep_mode",[NSString stringWithFormat:@"%d",sleep_data.bits.timeStamp],@"sleep_timeStamp", nil];
        [infos addObject:dic];
    }
    return infos;
}

//－－－－－－－－－－－－－－－睡眠设定解析
-(NSMutableArray *)analysisSetSleepData:(Byte *)bytes1 len:(int)len
{
    NSMutableArray *infos=[NSMutableArray array];
    NSDateFormatter *format1 = [[NSDateFormatter alloc] init];
    [format1 setDateFormat:@"yyyyMMddHHmmssSSS"];
    SleepHead_t sleep_head;
    sleep_head.Date.data=((uint16_t)bytes1[13]<<8)+((uint16_t)bytes1[14]<<0);
    
    sleep_head.length=((uint16_t)bytes1[15]<<8)+((uint16_t)bytes1[16]<<0);
    int count=sleep_head.length;
    int begin=16;
    for (int i=0; i<count; i++) {
        SleepData_U sleep_data;
        sleep_data.data=((uint32_t)bytes1[begin+(1+(i*4))]<<24)+((uint32_t)bytes1[begin+(2+(i*4))]<<16)+((uint32_t)bytes1[begin+(3+(i*4))]<<8)+((uint32_t)bytes1[begin+(4+(i*4))]<<0);
        //睡眠数据
        int temp=sleep_head.Date.date.month;
        NSString *month=[NSString stringWithFormat:@"%d",temp];
        if(temp<10)
            month=[NSString stringWithFormat:@"%@%@",@"0",month];
        
        int temp1=sleep_head.Date.date.day;
        NSString *day=[NSString stringWithFormat:@"%d",temp1];
        if(temp1<10)
            day=[NSString stringWithFormat:@"%@%@",@"0",day];
        
        NSString *slee_da = [NSString stringWithFormat:@"%@%d%@%@",@"20",sleep_head.Date.date.year,month,day];
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithObjectsAndKeys:slee_da,@"sleep_date",[NSString stringWithFormat:@"%d",sleep_data.bits.mode],@"sleep_mode",[NSString stringWithFormat:@"%d",sleep_data.bits.timeStamp],@"sleep_timeStamp", nil];
        [infos addObject:dic];
        
    }
    return infos;
}

static NSMutableArray *infos;
-(NSMutableArray *)analysisCuffSleepData:(Byte *)byte len:(int)len{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    NSTimeZone* GTMzone = [NSTimeZone timeZoneForSecondsFromGMT:0];//解决不同时令相差1小时问题
    [formatter setDateFormat:@"yyyyMMddHHmmss"];
    [formatter setLocale: [NSLocale systemLocale]];
    [formatter setTimeZone:GTMzone];
    NSDateFormatter *formatter1 = [[NSDateFormatter alloc] init];
    [formatter1 setDateFormat:@"HH"];
    [formatter1 setTimeZone:GTMzone];
    if (!infos) {
        infos=[NSMutableArray array];
    }
    NSMutableArray *allSlArr = [NSMutableArray array];
    int dataLen = byte[11]*pow(16, 2) + byte[12];
    if (dataLen == 0) {
        if (infos.count == 0) {
            NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:@"NODATA",@"NODATA", nil];
            [allSlArr addObject:dic];
        }
        else{
            allSlArr = [infos mutableCopy];
            [infos removeAllObjects];
            infos = nil;
        }
    }
    //    NSLog(@"slArrdata = %@",[NSData dataWithBytes:byte length:len]);
    NSInteger time;
    for (int i = 0; i<dataLen/7; i++) {
        time = byte[13+7*i]*pow(16, 6) + byte[14+7*i]*pow(16, 4) + byte[15+7*i]*pow(16, 2) + byte[16+7*i];
        NSDate *date = [[NSDate alloc] initWithTimeInterval:time sinceDate:[formatter dateFromString:@"20000101000000"]];
        NSNumber *sleep_mode = [NSNumber numberWithInt:byte[17+7*i]];
        NSNumber *sleep_softly = [NSNumber numberWithInt:byte[18+7*i]];
        NSNumber *sleep_strong = [NSNumber numberWithInt:byte[19+7*i]];
        NSString *dateStr = [formatter stringFromDate:date];
        NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:dateStr,@"DATE",sleep_mode,@"MODE",sleep_softly,@"SOFTLY",sleep_strong,@"STRONG", nil];
        [infos addObject:dic];
        if (i==dataLen/7-1&&dataLen==140) {
            [self requestCuffSleepData];
        }
        if (i==dataLen/7-1&&dataLen!=140){
            allSlArr = [infos mutableCopy];
            [infos removeAllObjects];
            infos = nil;
        }
    }
    return allSlArr;
}

//血压
static NSMutableArray *mbArr;
- (NSMutableArray *)manualMbWithData:(Byte *)byte Len:(int)len{
    if (!mbArr) {
        mbArr = [NSMutableArray array];
    }
    NSMutableArray *allSpArr = [NSMutableArray array];
    NSTimeZone* GTMzone = [NSTimeZone timeZoneForSecondsFromGMT:0];//解决不同时令相差1小时问题
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMddHHmmss"];
    [formatter setLocale: [NSLocale systemLocale]];
    [formatter setTimeZone:GTMzone];
    int dataLen = byte[11]*pow(16, 2) + byte[12];
    if (dataLen == 0) {
        if (mbArr.count == 0) {
            NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:@"NODATA",@"NODATA", nil];
            [allSpArr addObject:dic];
        }
        else{
            allSpArr = [mbArr mutableCopy];
            [mbArr removeAllObjects];
            mbArr = nil;
        }
    }
    NSString *shrink;
    NSString *relaxation;
    NSInteger time;
    //    NSLog(@"BPdata = %@",[NSData dataWithBytes:byte length:len]);
    for (int i = 0; i<dataLen/6; i++) {
        time = byte[13+6*i]*pow(16, 6) + byte[14+6*i]*pow(16, 4) + byte[15+6*i]*pow(16, 2) + byte[16+6*i];
        shrink = [NSString stringWithFormat:@"%d",byte[17+6*i]];
        relaxation = [NSString stringWithFormat:@"%d",byte[18+6*i]];
        NSDate *date = [[NSDate alloc] initWithTimeInterval:time sinceDate:[formatter dateFromString:@"20000101000000"]];
        NSString *timestr = [formatter stringFromDate:date];
        //        NSLog(@"time =%@ \n SHRINK==%@ \n RELAXATION ==%@",timestr,shrink,relaxation);
        NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:timestr,@"DATE",relaxation,@"RELAXATION",shrink,@"SHRINK", nil];
        [mbArr addObject:dic];
        if (i==dataLen/6-1&&dataLen==120) {
            [self requestCuffSportData];
        }
        if (i==dataLen/6-1&&dataLen!=120){
            allSpArr = [mbArr mutableCopy];
            [mbArr removeAllObjects];
            mbArr = nil;
        }
    }
    return allSpArr;
}

//- - - -  - - - - - 07心率解释
static NSMutableArray *hrArr;
- (NSMutableArray *)analysisCuffHRData:(Byte *)byte len:(int)len{
    if (!hrArr) {
        hrArr=[NSMutableArray array];
    }
    NSMutableArray *allHrArr = [NSMutableArray array];
    NSTimeZone* GTMzone = [NSTimeZone timeZoneForSecondsFromGMT:0];//解决不同时令相差1小时问题
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMddHHmmss"];
    [formatter setLocale: [NSLocale systemLocale]];
    [formatter setTimeZone:GTMzone];
    NSDateFormatter *format1 = [[NSDateFormatter alloc] init];
    [format1 setDateFormat:@"yyyyMMddHHmm"];
    [format1 setTimeZone:GTMzone];
    int dataLen = byte[11]*pow(16, 2) + byte[12];
    if (dataLen == 0) {
        if (hrArr.count == 0) {
            NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:@"NODATA",@"NODATA", nil];
            [allHrArr addObject:dic];
        }
        else{
            allHrArr = [hrArr mutableCopy];
            [hrArr removeAllObjects];
            hrArr = nil;
            
        }
    }
    //    NSLog(@"hrArrdata = %@",[NSData dataWithBytes:byte length:len]);
    NSString *hr;
    NSInteger time;
    NSString *mode;
    for (int i = 0; i<dataLen/5; i++) {
        mode = @"0";
        time = byte[13+5*i]*pow(16, 6) + byte[14+5*i]*pow(16, 4) + byte[15+5*i]*pow(16, 2) + byte[16+5*i];
        if (time%60 == 1) {
            mode = @"2";
        }
        hr = [NSString stringWithFormat:@"%.0f",byte[17+5*i]*pow(16, 0)];
        NSDate *date = [[NSDate alloc] initWithTimeInterval:time sinceDate:[formatter dateFromString:@"20000101000000"]];
        NSString *timestr = [formatter stringFromDate:date];
        NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:timestr,@"DATE",hr,@"HEART",mode,@"HRMODE", nil];
        //        NSLog(@"hrtime =%@ \n mode==%@ \n step ==%@",timestr,mode,hr);
        [hrArr addObject:dic];
        if (i==dataLen/5-1&&dataLen==100) {
            [self requestCuffHRData];
        }
        if (i==dataLen/5-1&&dataLen!=100){
            allHrArr = [hrArr mutableCopy];
            [hrArr removeAllObjects];
            hrArr = nil;
        }
    }
    return allHrArr;
}

//- - - -  - - - - - 骑行数据
static NSMutableArray *cylingArr;
- (NSMutableArray *)analysisCuffcylingData:(Byte *)byte len:(int)len{
    if (!cylingArr) {
        cylingArr=[NSMutableArray array];
    }
    NSMutableArray *allHrArr = [NSMutableArray array];
    NSTimeZone* GTMzone = [NSTimeZone timeZoneForSecondsFromGMT:0];//解决不同时令相差1小时问题
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMddHHmmss"];
    [formatter setLocale: [NSLocale systemLocale]];
    [formatter setTimeZone:GTMzone];
    NSDateFormatter *format1 = [[NSDateFormatter alloc] init];
    [format1 setDateFormat:@"yyyyMMddHHmm"];
    [format1 setTimeZone:GTMzone];
    int dataLen = byte[11]*pow(16, 2) + byte[12];
    if (dataLen == 0) {
        if (cylingArr.count == 0) {
            NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:@"NODATA",@"NODATA", nil];
            [allHrArr addObject:dic];
        }
        else{
            allHrArr = [cylingArr mutableCopy];
            [cylingArr removeAllObjects];
            cylingArr = nil;
        }
    }
    NSLog(@"cylingArr = %@",[NSData dataWithBytes:byte length:len]);
    NSString *hr;
    NSString *cal;
    NSInteger time;
    NSString *mode;
    NSString *state;
    for (int i = 0; i<dataLen/7; i++) {
        mode = @"0";
        time = byte[13+7*i]*pow(16, 6) + byte[14+7*i]*pow(16, 4) + byte[15+7*i]*pow(16, 2) + byte[16+7*i];
        if (i%2 != 0) {
            mode = @"2";
        }
        cal = [NSString stringWithFormat:@"%.0f", byte[17+7*i]*pow(16, 2) + byte[18+7*i]];
        hr = [NSString stringWithFormat:@"%.0f", byte[19+7*i]*pow(16, 0)];
        NSDate *date = [[NSDate alloc] initWithTimeInterval:time sinceDate:[formatter dateFromString:@"20000101000000"]];
        NSDate *dateNow = [self getNowDateFromatAnDate:[NSDate date]];
        NSString *timestr = [formatter stringFromDate:date];
        if (time == 0) {
            state = @"32";
            timestr = [formatter stringFromDate:dateNow];
            [self.delegate onExerciseType:SMA_EXERCISE_TYPE_CYCLING changeWithState:SMA_EXERCISE_STATE_STARTED];
        }
        else if (time == 4294967294) {
            state = @"34";
            timestr = [formatter stringFromDate:dateNow];
            [self.delegate onExerciseType:SMA_EXERCISE_TYPE_CYCLING changeWithState:SMA_EXERCISE_STATE_GOING];
        }
        else if (time == 4294967295) {
            state = @"47";
            timestr = [formatter stringFromDate:dateNow];
            [self.delegate onExerciseType:SMA_EXERCISE_TYPE_CYCLING changeWithState:SMA_EXERCISE_STATE_STOPPED];
        }else{
            state = @"0";
        }
        NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:timestr,@"DATE",cal,@"CAL",hr,@"HEART",mode,@"MODE",state,@"TYPE", nil];
        NSLog(@"hrtime =%@ \n mode==%@ \n step ==%@",timestr,mode,hr);
        [cylingArr addObject:dic];
        if (i==dataLen/7-1&&dataLen==140) {
            [self requestCyclingData];
        }
        if (i==dataLen/7-1&&dataLen!=140){
            allHrArr = [cylingArr mutableCopy];
            [cylingArr removeAllObjects];
            cylingArr = nil;
        }
    }
    return allHrArr;
}

static NSMutableArray *gpsArr;
- (NSMutableArray *)analysisGpsData:(Byte *)byte len:(int)len{
    if (!gpsArr) {
        gpsArr=[NSMutableArray array];
    }
    NSMutableArray *allGpsArr = [NSMutableArray array];
    NSTimeZone* GTMzone = [NSTimeZone timeZoneForSecondsFromGMT:0];//解决不同时令相差1小时问题
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMddHHmmss"];
    [formatter setLocale: [NSLocale systemLocale]];
    [formatter setTimeZone:GTMzone];
    NSDateFormatter *format1 = [[NSDateFormatter alloc] init];
    [format1 setDateFormat:@"yyyyMMddHHmm"];
    [format1 setTimeZone:GTMzone];
    int dataLen = byte[11]*pow(16, 2) + byte[12];
    if (dataLen == 0) {
        if (gpsArr.count == 0) {
            NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:@"NODATA",@"NODATA", nil];
            [allGpsArr addObject:dic];
        }
        else{
            allGpsArr = [gpsArr mutableCopy];
            [gpsArr removeAllObjects];
            gpsArr = nil;
        }
    }
    
    NSInteger time;
    NSInteger runTime;
    NSInteger order;
    CGFloat longitude;
    CGFloat latitude;
    for (int i = 0; i<dataLen/16; i++) {
        time = byte[13+7*i]*pow(16, 6) + byte[14+7*i]*pow(16, 4) + byte[15+7*i]*pow(16, 2) + byte[16+7*i];
        runTime =  byte[17+7*i]*pow(16, 2) + byte[18+7*i];
        order =  byte[19+7*i]*pow(16, 2) + byte[20+7*i];
        latitude = (byte[21+7*i]*pow(16, 6) + byte[22+7*i]*pow(16, 4) + byte[23+7*i]*pow(16, 2) + byte[24+7*i])/1000000.0;
        longitude = (byte[25+7*i]*pow(16, 6) + byte[26+7*i]*pow(16, 4) + byte[27+7*i]*pow(16, 2) + byte[28+7*i])/1000000.0;
        NSDate *date = [[NSDate alloc] initWithTimeInterval:time + runTime sinceDate:[formatter dateFromString:@"20000101000000"]];
        NSString *timestr = [formatter stringFromDate:date];
        NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:timestr,@"DATE",[NSString stringWithFormat:@"%f",longitude],@"LONGITUDE",[NSString stringWithFormat:@"%f",latitude],@"LATITUDE",[NSString stringWithFormat:@"%ld",(long)order],@"ORDER", nil];
        [gpsArr addObject:dic];
        
        if (i==dataLen/16-1&&dataLen==160) {
            [self requestGpsData];
        }
        if (i==dataLen/16-1&&dataLen!=160){
            allGpsArr = [gpsArr mutableCopy];
            [gpsArr removeAllObjects];
            gpsArr = nil;
        }
    }
    return allGpsArr;
}

static NSMutableArray *swimInfos;
- (NSMutableArray *)analysisSwimData:(Byte *)byte len:(int)len{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    NSTimeZone* GTMzone = [NSTimeZone timeZoneForSecondsFromGMT:0];//解决不同时令相差1小时问题
    [formatter setDateFormat:@"yyyyMMddHHmmss"];
    [formatter setLocale: [NSLocale systemLocale]];
    [formatter setTimeZone:GTMzone];
    NSDateFormatter *formatter1 = [[NSDateFormatter alloc] init];
    [formatter1 setDateFormat:@"HH"];
    [formatter1 setTimeZone:GTMzone];
    if (!swimInfos) {
        swimInfos=[NSMutableArray array];
    }
    NSMutableArray *allSlArr = [NSMutableArray array];
    int dataLen = byte[11]*pow(16, 2) + byte[12];
    
    if (dataLen == 0) {
        if (swimInfos.count == 0) {
            NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:@"NODATA",@"NODATA", nil];
            [allSlArr addObject:dic];
        }
        else{
            allSlArr = [swimInfos mutableCopy];
            [swimInfos removeAllObjects];
            swimInfos = nil;
        }
    }
    //    NSLog(@"slArrdata = %@",[NSData dataWithBytes:byte length:len]);]
    NSInteger time;
    NSString *mode;
    for (int i = 0; i<dataLen/7; i++) {
        mode = @"0";
        if (i%2 != 0) {
            mode = @"2";
        }
        time = byte[13+7*i]*pow(16, 6) + byte[14+7*i]*pow(16, 4) + byte[15+7*i]*pow(16, 2) + byte[16+7*i];
        NSDate *date = [[NSDate alloc] initWithTimeInterval:time sinceDate:[formatter dateFromString:@"20000101000000"]];
        NSNumber *swim_cal = [NSNumber numberWithInt:byte[17+7*i]*pow(16, 2) + byte[18+7*i]];
        NSNumber *swim_hr = [NSNumber numberWithInt:byte[19+7*i]];
        NSString *dateStr = [formatter stringFromDate:date];
        NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:dateStr,@"DATE",swim_cal,@"CAL",swim_hr,@"HEART",mode,@"MODE", nil];
        [swimInfos addObject:dic];
        if (i==dataLen/7-1&&dataLen==140) {
            [self requestSwimData];
        }
        if (i==dataLen/7-1&&dataLen!=140){
            allSlArr = [swimInfos mutableCopy];
            [swimInfos removeAllObjects];
            swimInfos = nil;
        }
    }
    return allSlArr;
}

//－－－－－－－－－－－－－解析心率数据ok
-(NSMutableArray *)analysisHRData:(Byte *)bytes1 len:(int)len{
    NSMutableArray *hrArr=[NSMutableArray array];
    NSString *hr = [NSString stringWithFormat:@"%hhu",bytes1[13]];
    NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:hr,@"HEART", nil];
    [hrArr addObject:dic];
    return hrArr;
}

//－－－－－－－－－－－－－解析系统时间数据ok
-(NSMutableArray *)analysisSystemData:(Byte *)bytes1 len:(int)len{
    NSMutableArray *array = [NSMutableArray array];
    systemDate_union date1;
    date1.data = ((uint32_t)bytes1[13]<<24)+((uint32_t)bytes1[14]<<16)+((uint32_t)bytes1[15]<<8)+((uint32_t)bytes1[16]<<0);
    
    int temp=date1.date.month;
    NSString *month=[NSString stringWithFormat:@"%d",temp];
    if(temp<10)
        month=[NSString stringWithFormat:@"%@%@",@"0",month];
    
    int temp1=date1.date.day;
    NSString *day=[NSString stringWithFormat:@"%d",temp1];
    if(temp1<10)
        day=[NSString stringWithFormat:@"%@%@",@"0",day];
    
    int temp2=date1.date.hour;
    NSString *hour=[NSString stringWithFormat:@"%d",temp2];
    if(temp2<10)
        hour=[NSString stringWithFormat:@"%@%@",@"0",hour];
    
    int temp3=date1.date.minute;
    NSString *min=[NSString stringWithFormat:@"%d",temp3];
    if(temp3<10)
        min=[NSString stringWithFormat:@"%@%@",@"0",min];
    
    int temp4=date1.date.second;
    NSString *second=[NSString stringWithFormat:@"%d",temp4];
    if(temp4<10)
        second=[NSString stringWithFormat:@"%@%@",@"0",second];
    
    NSString *sysYear = [NSString stringWithFormat:@"%@%d%@%@%@%@%@",@"20",date1.date.year,month,day,hour,min,second];
    [array addObject:sysYear];
    return array;
}

- (void)receiveTimeOut{
    if (receiveBLTimer) {
        [receiveBLTimer invalidate];
        receiveBLTimer = nil;
    }
    receive_state=AWAIT_RECEVER1;
}

- (NSInteger)returnHour:(NSString *)time{
    NSInteger hour;
    hour = time.intValue/60;
    return hour;
}

- (NSInteger)returnMinute:(NSString *)time{
    NSInteger min;
    min = time.intValue%60;
    return min;
}

- (void)sendTimeOut{
    self.sendNum ++;
    if (self.sendNum == 2) {
        self.sendNum =0;
        self.canSend = YES;
        [self sendDataTimeOut:[self.BLInstructionArr firstObject]];
        if (self.BLInstructionArr.count > 0) {
            [self.BLInstructionArr removeObjectAtIndex:0];
        }
        [self sendBLInstruction];
    }
    else{
        self.canSend = YES;
        [self sendBLInstruction];
    }
}

//发送蓝牙指令
-  (void)sendBLInstruction{
    if (self.BLInstructionArr.count == 1||self.canSend) {
        if (self.BLInstructionArr.count > 0) {
            if (self.sendBLTimer) {
                [self.sendBLTimer invalidate];
                self.sendBLTimer = nil;
            }
            self.sendBLTimer = [NSTimer scheduledTimerWithTimeInterval:8.0 target:self selector:@selector(sendTimeOut) userInfo:nil repeats:NO];
            self.canSend = NO;
            if (self.p && self.Write) {
                NSMutableArray *sendArr = [self.BLInstructionArr firstObject];
                if (sendArr.count > 1) {
                    for (int i = 0; i < sendArr.count - 1; i++) {
                        NSLog(@"sendValue==%@",sendArr[i]);
                        //                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                        //                        NSLog(@"send data  %@",(NSData *)sendArr[i]);
                        [self.p writeValue:(NSData *)sendArr[i] forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
                        //                        });
                    }
                }
               
            }
        }
    }
}

//整理需要发送的蓝牙指令
static int arrIndex;
static NSMutableArray *senArr;
- (void)arrangeBLData:(NSData *)data type:(NSString *)type sendNum:(int)numb{
    
    
    if (!arrIndex) {
        senArr = [NSMutableArray array];
    }
    [senArr addObject:data];
    
   // NSLog(@"senArr==%@",senArr);
    
    arrIndex ++;
    if (arrIndex == numb) {
        [senArr addObject:type];
        [self.BLInstructionArr addObject:senArr];
        [self sendBLInstruction];
        arrIndex = 0;
    }
    //    else{
    //
    //    }
}

- (void)sendDataTimeOut:(NSMutableArray *)instructionArr{
    SMA_INFO_MODE mode = 1000;
    BOOL bol = false;
    if (instructionArr.count > 1) {
        bol = YES;
    }
    
    NSData *senData = [instructionArr firstObject];//仅需要首个传输数据即可判断该指令类型
    if (senData) {
        Byte *bytes = (Byte *)[senData bytes];
        if(bytes[8]==0x01 && bytes[10]==0x00 && bol){
            mode = OTA;
        }
        else if (bytes[8]==0x01 && bytes[10]==0x21 && bol) {//进入XMODEM模式
            mode = XMODEM;
        }
        
        else if (bytes[8]==0x01 && bytes[10]==0x31 && bol) {//面盘
            mode = WATCHFACE;
        }
        else if(bytes[8]==0x03 && bytes[10]==0x01 && bol)//绑定
        {
            mode = BAND;
        }
        else if(bytes[8]==0x03 && bytes[10]==0x03 && bol)//登录
        {
            mode = LOGIN;
        }
        else if(bytes[8]==0x02 && bytes[10]==0x02 && bol)//闹钟列表
        {
            mode = ALARMCLOCK;
        }
        else if(bytes[8]==0x02 && bytes[10]==0x2c && bol)//07闹钟列表
        {
            mode = ALARMCLOCK;
        }
        else if (bytes[8]==0x02 && bytes[10]==0x01 && bol){
            mode = SYSTEMTIME;
        }
        else if (bytes[8]==0x02 && bytes[10]==0x0A && bol) {//版本
            mode = VERSION;
        }
        else if(bytes[8]==0x02 && bytes[10]==0x08 && bol)
        {
            mode = ELECTRIC;
        }
        else if (bytes[8]==0x02 && bytes[10]==0x0C && bol) {
            mode = MAC;
        }
        else if(bytes[8]==0x05 && bytes[10]==0x20 && bol){
            mode = WATHEARTDATA;
        }
        else if(bytes[8]==0x05 && bytes[10]==0x41 && bol){
            mode = CUFFSPORTDATA;
        }
        else if(bytes[8]==0x05 && bytes[10]==0x43 && bol){
            mode = CUFFHEARTRATE;
        }
        else if(bytes[8]==0x05 && bytes[10]==0x45 && bol){
            mode = CUFFSLEEPDATA;
        }
        else if (bytes[8]==0x05 && bytes[10]==0x4a && bol){
            mode = BLUTDRUCK;
        }
        else if (bytes[8]==0x05 && bytes[10]==0x48 && bol){
            mode = GPS;
        }
        else if (bytes[8]==0x05 && bytes[10]==0x4d && bol){
            mode = CYCLINGDATA;
        }
        else if (bytes[8]==0x05 && bytes[10]==0x4e && bol){
            mode = SWIM;
        }
        if (self.delegate && [self.delegate respondsToSelector:@selector(sendBLETimeOutWithMode:)]) {
            [self.delegate sendBLETimeOutWithMode:mode];
        }
        if (_delegate && [_delegate respondsToSelector:@selector(sendIdentifier:)]) {
            //            NSLog(@"jgrighh==%d",(bytes[6]<<8) + (bytes[7]<<0));
            [_delegate sendIdentifier:(bytes[6]<<8) + (bytes[7]<<0)];
        }
    }
}

- (float )countDisWithHeight:(NSString *)height Step:(NSString *)step{
    return height.floatValue*step.floatValue*45/10000000;//[[self notRounding:height.floatValue*step.floatValue*45/10000000 afterPoint:0] floatValue];
}

- (float)countCalWithSex:(NSString *)sex userWeight:(NSString *)weight step:(NSString *)step{
    if ([sex isEqualToString:@"1"]) {
        return [[self notRounding:(55*[weight floatValue]*[step floatValue])/100000 afterPoint:0] floatValue];
    }
    else{
        return [[self notRounding:(46*[weight floatValue]*[step floatValue])/100000 afterPoint:0] floatValue];
    }
}
- (NSInteger)countStepsWithSex:(NSString *)sex userWeight:(NSString *)weight cal:(NSInteger)cal{
    NSInteger steps;
    float stepsResult;
    
    if ([sex isEqualToString:@"1"]) {
        stepsResult = [[self notRounding:100000*cal/(55*[weight floatValue]) afterPoint:0] floatValue];
    }
    else{
        stepsResult = [[self notRounding:100000*cal/(46*[weight floatValue]) afterPoint:0] floatValue];
    }
    
    steps = (NSInteger) ceil(stepsResult);
    
    return steps;
}

//整理07运动，保证四舍不入
-(NSString *)notRounding:(float)price afterPoint:(int)position{
    
    NSDecimalNumberHandler* roundingBehavior = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundDown scale:position raiseOnExactness: NO  raiseOnOverflow: NO  raiseOnUnderflow: NO  raiseOnDivideByZero: NO ];
    
    NSDecimalNumber *ouncesDecimal;
    
    NSDecimalNumber *roundedOunces;
    
    ouncesDecimal = [[NSDecimalNumber alloc] initWithFloat:price];
    
    roundedOunces = [ouncesDecimal decimalNumberByRoundingAccordingToBehavior:roundingBehavior];
    
    
    return  [NSString stringWithFormat: @"%@" ,roundedOunces];
    
}

-(void)timeoutToStopConnectAction
{
    [self writeFirmware:0];
    binNum ++;
}

static NSString *senProgr;
- (void)writeFirmware:(int)NUM{
    if (NUM == 0) {
        senProgr = nil;
    }
    if (NUM < self.BinArr.count) {
        NSData *result = [self.BinArr objectAtIndex:NUM];
        //        NSLog(@"fwgrgh==%@",self.BinArr);
        Byte result_sub[20];
        int datNum = [NSString stringWithFormat:@"%lu",(unsigned long)result.length].intValue/20;
        int modNum = result.length%20;
        for (int i = 0; i< datNum; i ++) {
            [result getBytes:(void *)result_sub range:NSMakeRange(i*20,20)];
            [self.p writeValue:[NSData dataWithBytes:result_sub length:20] forCharacteristic:self.Write type:CBCharacteristicWriteWithoutResponse];
        }
        if (modNum > 0) {
            Byte result_endsub[13];
            [result getBytes:(void *)result_endsub range:NSMakeRange(datNum*20,modNum)];
            [self.p writeValue:[NSData dataWithBytes:result_endsub length:modNum] forCharacteristic:self.Write type:CBCharacteristicWriteWithoutResponse];
        }
    }
    if ([self.delegate respondsToSelector:@selector(updateProgress:)]) {
        NSString *progress = [NSString stringWithFormat:@"%.2f",(NUM+1)/(float)self.BinArr.count];
        [self.delegate updateProgress:progress.floatValue];
    }
}

//  十进制转二进制
- (NSString *)toBinarySystemWithDecimalSystem:(NSString *)decimal
{
    int num = [decimal intValue];
    int remainder = 0;      //余数
    int divisor = 0;        //除数
    NSString * prepare = @"";
    while (true)
    {
        remainder = num%2;
        divisor = num/2;
        num = divisor;
        prepare = [prepare stringByAppendingFormat:@"%d",remainder];
        if (divisor == 0)
        {
            break;
        }
    }
    NSString * result = @"";
    for (int i = (int)prepare.length - 1; i >= 0; i --)
    {
        result = [result stringByAppendingFormat:@"%@%@",
                  [prepare substringWithRange:NSMakeRange(i , 1)],i==0?@"":@","];
    }
    NSMutableArray *resultArr = [[result componentsSeparatedByString:@","] mutableCopy];
    NSInteger count = 7 - resultArr.count;
    if (resultArr.count < 7) {
        for (int j = 0; j < count; j ++) {
            [resultArr insertObject:@"0" atIndex:0];
        }
        result = [resultArr componentsJoinedByString:@","];
    }
    
    return result;
}

//  二进制转十进制
- (NSString *)toDecimalSystemWithBinarySystem:(NSString *)binary
{
    int ll = 0 ;
    int  temp = 0 ;
    for (int i = 0; i < binary.length; i ++)
    {
        temp = [[binary substringWithRange:NSMakeRange(i, 1)] intValue];
        temp = temp * powf(2, binary.length - i - 1);
        ll += temp;
    }
    NSString * result = [NSString stringWithFormat:@"%d",ll];
    return result;
}

- (NSDate *)getNowDateFromatAnDate:(NSDate *)anyDate
{
    //设置源日期时区
    NSTimeZone* sourceTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];//或GMT
    //设置转换后的目标日期时区
    NSTimeZone* destinationTimeZone = [NSTimeZone localTimeZone];
    //得到源日期与世界标准时间的偏移量
    NSInteger sourceGMTOffset = [sourceTimeZone secondsFromGMTForDate:anyDate];
    //目标日期与本地时区的偏移量
    NSInteger destinationGMTOffset = [destinationTimeZone secondsFromGMTForDate:anyDate];
    //得到时间偏移量的差值
    NSTimeInterval interval = destinationGMTOffset - sourceGMTOffset;
    //转为现在时间
    NSDate* destinationDateNow = [[NSDate alloc] initWithTimeInterval:interval sinceDate:anyDate];
    return destinationDateNow;
}

- (void)setTimeZone {
    //获取时区
    NSTimeZone *zone = [NSTimeZone localTimeZone];
    NSInteger zomeTime = [zone secondsFromGMT];
    NSInteger minTime = zomeTime/60;
    NSInteger vlaueTime = minTime/15;     //协议-单位15分钟
 
    Byte buf[1];
    buf[0]=(Byte)(vlaueTime&0xff);
    Byte results[14];
    if(self.p && self.Write){
        [SmaBusinessTool getSpliceCmd:0x02 Key:0x68 bytes1:buf len:1 results:results];
        NSData * data0 = [NSData dataWithBytes:results length:14];
        [self arrangeBLData:data0 type:@"SET" sendNum:1];
        //        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
    }
    
    
    
}

-(void)setLongitude:(float)longitude Latitude:(float)latitude Altitude:(float)altitude {
    Byte valueBuf[12];
    Byte longBuf[4];
    Byte laBuf[4];
    Byte alBuf[4];
    
    float longf = longitude;
    float laf = latitude;
    float alf = altitude;
    
    memcpy(longBuf, &longf, 4);
    memcpy(laBuf, &laf, 4);
    memcpy(alBuf, &alf, 4);
    
    for (int i=0; i<12; i++) {
        if (i >= 0 && i<4) {
            valueBuf[i] = longBuf[3-i];
        }else if (i >= 4 && i < 8) {
            valueBuf[i] = laBuf[7-i];
        }else if (i >= 8 && i < 12) {
            valueBuf[i] = alBuf[11-i];
        }
    }
    
    int recount = 25;
    Byte results[25];
    [SmaBusinessTool getSpliceCmd:0x02 Key:0x69 bytes1:valueBuf len:12 results:results];
    if(self.p&& self.Write)
    {
        int degree = recount/20;
        int surplus = recount%20;
        if(surplus>0)
            degree=degree+1;
        for (int i=0; i<degree; i++) {
            int alen=(((degree-1)==i)?surplus:20);
            Byte arr[alen];
            memcpy(&arr,&results[0+(20*i)],alen);//拷贝到对应的Byte 数组中
            NSData * data0 = [NSData dataWithBytes:arr length:(((degree-1)==i)?surplus:20)];
            [self arrangeBLData:data0 type:@"SET" sendNum:degree];
            //            [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
        }
    }
}

- (void)getDeviceRequestData:(Byte *)bytes len:(int)len {
   
    if (bytes[13] == 0x00 && bytes[14] == 0x01) {
        //mtk2503 epo辅助定位文件获取请求；
        [AFNetRequestManager DownloadFileWithURL:@"http://wepodownload.mediatek.com/EPO_GR_3_1.DAT" Success:^(id responseObject) {
         
            NSLog(@"response==%@",responseObject);
            if (responseObject) {
                [self updataEPOFileWithPath:responseObject];
            }
         } fail:^(NSError *error) {
             NSLog(@"error==%@",error);
         }];
    }else if (bytes[13] == 0x00 && bytes[14] == 0x02) {
        //ublox星历文件获取指令
        
    }
}

static int epoIndex = 0;

- (void)updataEPOFileWithPath:(NSURL *)filePath  {
    NSString *file = filePath.absoluteString;
    NSLog(@"%@",[file substringFromIndex:7]);
    NSData *data = [NSData dataWithContentsOfFile:[file substringFromIndex:7]];
    epoFileData = data;
    
    int file_len = (int)data.length;
     NSLog(@"data==%d--%@",file_len,data);
    Byte *dataByte = (Byte *)[data bytes];
    
    NSArray *nameArr = [file componentsSeparatedByString:@"/"];
    NSString *filename = [NSString stringWithFormat:@"%@,",[nameArr lastObject]];
    NSLog(@"filename==%@",filename);

    const char *s = [filename cStringUsingEncoding:NSASCIIStringEncoding];
    size_t len = strlen(s);
    
    Byte timebuf[4];
    Byte flagbuf[2];
    Byte tempbuf[2];
    Byte sizebuf[4];
    Byte fileCountbuf[2];
    

    int hour = (dataByte[2] & 0xff) << 16;
    hour |= (dataByte[1] & 0xff) << 8;
    hour |= (dataByte[0] & 0xff);
    
    NSLog(@"hour==%d",hour);
    
    NSString *tt = @"1980-01-06 00:00:00";
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSDate *ttdate = [fmt dateFromString:tt];
    NSTimeInterval sinet = [ttdate timeIntervalSince1970];
    
    NSTimeInterval sun = sinet + hour*60*60;
    
    //NSLog(@"sinet==%l---sun==%ld",sinet,sun);
    
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:sun];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSUInteger unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    NSDateComponents *dateComponent = [calendar components:unitFlags fromDate:now];
    
    NSLog(@"dateCompont==%@",dateComponent);
    
    usercdata_union_t user_data;
    user_data.bit_field.second = (int)[dateComponent second];
    user_data.bit_field.minute =  (int)[dateComponent minute];
    user_data.bit_field.hour  = (int)[dateComponent hour];
    user_data.bit_field.day =  (int)[dateComponent day];
    user_data.bit_field.Month = (int)[dateComponent month];
    user_data.bit_field.Year = [dateComponent year]%2000;
    
    timebuf[3] = user_data.data>>24;
    timebuf[2] = user_data.data>>16;
    timebuf[1] = user_data.data>>8;
    timebuf[0] = user_data.data>>0;

    int countepo = file_len % 2033 == 0 ? file_len /2033 : file_len / 2033 + 1;
    
    int flag = 1;
    memcpy(flagbuf, &flag, 2);
    Byte flagBB[2];
    for (int k=0; k<2; k++) {
        flagBB[k] = flagbuf[1-k];
    }
    memcpy(sizebuf, &file_len, 4);    //文件大小
    Byte sizeB[4];
    for (int i=0; i<4; i++) {
        sizeB[i] = sizebuf[3-i];
    }
    memcpy(fileCountbuf, &countepo, 2);  //分包总数
    Byte sumepo[2];
    for (int j=0; j<2; j++) {
        sumepo[j] = fileCountbuf[1-j];
    }
    
    Byte results[16+len+13];
    int resultCount = len+29;
    Byte valueBuf[16 +len];
    
    Byte bytes[2];
    bytes[0] = (Byte)(((0)&0xff)>>8);
    bytes[1] = (Byte)((0)&0xff);
    Byte *index = bytes;
    
    for (int i=0; i<16+len; i++) {
        if (i < 2) {
            valueBuf[i] = index[i];
        }else if (i >= 2 && i < len+2) {
            valueBuf[i] = s[i-2];
        }else if (i>= len+2 && i < len + 6) {
            valueBuf[i] = timebuf[i- (len+2)];
        }else if (i>= len+6 && i < len+8) {
            valueBuf[i] = flagBB[i-(len+6)];
        }else if (i >= len + 8 && i < len + 10) {
            valueBuf[i] = (Byte)(0&0xff);
        }else if (i>= len+10 && i<len+14) {
            valueBuf[i] = sizeB[i-(len+10)];
        }else if (i>= len+14 && i<len + 16) {
            valueBuf[i] = sumepo[i-(len + 14)];
        }
        
      //  NSLog(@"value==%d--%c--%d",i,valueBuf[i],valueBuf[i]);
    }
    
    
    epoIndex = countepo;
    //先发送
    [SmaBusinessTool getSpliceCmd:0x05 Key:0x60 bytes1:valueBuf len:(len+16) results:results];
    if(self.p&& self.Write)
    {
        int degree = resultCount/20;
        int surplus = resultCount%20;
        if(surplus>0)
            degree=degree+1;
        for (int i=0; i<degree; i++) {
            int alen=(((degree-1)==i)?surplus:20);
            Byte arr[alen];
            memcpy(&arr,&results[0+(20*i)],alen);//拷贝到对应的Byte 数组中
            NSData * data0 = [NSData dataWithBytes:arr length:(((degree-1)==i)?surplus:20)];
           [self arrangeBLData:data0 type:@"SET" sendNum:degree];
         //   NSLog(@"index0-%@",data0);
//            [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
        }
    }
    
   
    
}

- (void)epoFileWrite {
    if (epoFileData && epoFileData.length > 0) {
        
        NSLog(@"epoIndex==%d",epoIndex);
        
        Byte *dataByte = (Byte *)[epoFileData bytes];
        int maxcount = [self.p maximumWriteValueLengthForType:CBCharacteristicWriteWithResponse];
        int countepo = epoFileData.length % 2033 == 0 ? epoFileData.length /2033 : epoFileData.length / 2033 + 1;
        
        Byte bytes[2];
        bytes[0] = (Byte)(((countepo - epoIndex + 1)&0xff)>>8);
        bytes[1] = (Byte)((countepo - epoIndex + 1)&0xff);
        Byte *index = bytes;
        
        if (epoIndex == 1) {
            int degreeepo = epoFileData.length / 2033;
            int surplusepo = epoFileData.length % 2033;
            
            if (surplusepo > 0) {
                Byte eporesults[surplusepo+15];
                int eporesultCount = surplusepo + 15;
                Byte epovalueBuf[surplusepo+2];
                
                for (int j=0; j<surplusepo+2; j++) {
                    if (j<2) {
                        epovalueBuf[j] = index[j];
                    }else {
                        epovalueBuf[j] = dataByte[(countepo - epoIndex)*2033 + (j-2)];
                    }
                }
                
                [SmaBusinessTool getSpliceCmd:0x05 Key:0x60 bytes1:epovalueBuf len:surplusepo+2 results:eporesults];
                if(self.p&& self.Write)
                {
                    int degree = eporesultCount / 180;
                    int surplus = eporesultCount % 180;
                    if(surplus>0)
                        degree=degree+1;
                    for (int k=0; k<degree; k++) {
                        int alen=(((degree-1)==k)?surplus:180);
                        Byte arr[alen];
                        memcpy(&arr,&eporesults[0+(180*k)],alen);//拷贝到对应的Byte 数组中
                        NSData * data0 = [NSData dataWithBytes:arr length:(((degree-1)==k)?surplus:180)];
                        [self arrangeBLData:data0 type:@"SET" sendNum:degree];
//                        NSLog(@"结束%@",data0);
//                        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
                    }
                }
            }else {
                Byte eporesults[2048];
                int eporesultCount = 2048;
                Byte epovalueBuf[2035];
                
                for (int j=0; j<2035; j++) {
                    if (j<2) {
                        epovalueBuf[j] = index[j];
                    }else {
                        epovalueBuf[j] = dataByte[(countepo - epoIndex)*2033 + (j-2)];
                    }
                }
                
                [SmaBusinessTool getSpliceCmd:0x05 Key:0x60 bytes1:epovalueBuf len:2035 results:eporesults];
                if(self.p&& self.Write)
                {
                    int degree = eporesultCount/180;
                    int surplus = eporesultCount%180;
                    if(surplus>0)
                        degree=degree+1;
                    for (int k=0; k<degree; k++) {
                        int alen=(((degree-1)==k)?surplus:180);
                        Byte arr[alen];
                        memcpy(&arr,&eporesults[0+(180*k)],alen);//拷贝到对应的Byte 数组中
                        NSData * data0 = [NSData dataWithBytes:arr length:(((degree-1)==k)?surplus:180)];
                        [self arrangeBLData:data0 type:@"SET" sendNum:degree];
//                        NSLog(@"结尾%@",data0);
//                        [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
                    }
                }
            }
            
            
        }else {
            
            Byte eporesults[2048];
            int eporesultCount = 2048;
            Byte epovalueBuf[2035];
            
            for (int j=0; j<2035; j++) {
                if (j<2) {
                    epovalueBuf[j] = index[j];
                }else {
                    epovalueBuf[j] = dataByte[(countepo - epoIndex)*2033 + (j-2)];
                }
            }
            
            [SmaBusinessTool getSpliceCmd:0x05 Key:0x60 bytes1:epovalueBuf len:2035 results:eporesults];
            if(self.p&& self.Write)
            {
                int degree = eporesultCount/180;
                int surplus = eporesultCount%180;
                if(surplus>0)
                    degree=degree+1;
                for (int k=0; k<degree; k++) {
                    int alen=(((degree-1)==k)?surplus:180);
                    Byte arr[alen];
                    memcpy(&arr,&eporesults[0+(180*k)],alen);//拷贝到对应的Byte 数组中
                    NSData * data0 = [NSData dataWithBytes:arr length:(((degree-1)==k)?surplus:180)];
                    [self arrangeBLData:data0 type:@"SET" sendNum:degree];
//                    NSLog(@"开始循环%@",data0);
//                    [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
                }
            }
        }
        
        epoIndex--;
    }
        /*
         for (int q=0; q < countepo; q++) {
         
         Byte bytes[2];
         bytes[0] = (Byte)(((q+1)&0xff)>>8);
         bytes[1] = (Byte)((q+1)&0xff);
         Byte *index = bytes;
         
         NSLog(@"index==%d%d",index[0],index[1]);
         
         if (q == (countepo-1)) {
         NSLog(@"count==%d-i==%d",countepo,q);
         int degreeepo = epoFileData.length/2033;
         int surplusepo = epoFileData.length%2033;
         NSLog(@"supepo==%d",surplusepo);
         
         if (surplusepo > 0) {
         Byte eporesults[surplusepo+15];
         int eporesultCount = surplusepo + 15;
         Byte epovalueBuf[surplusepo+2];
         
         for (int j=0; j<surplusepo+2; j++) {
         if (j<2) {
         epovalueBuf[j] = index[j];
         }else {
         epovalueBuf[j] = dataByte[q*2033 + (j-2)];
         }
         }
         
         [SmaBusinessTool getSpliceCmd:0x05 Key:0x60 bytes1:epovalueBuf len:surplusepo+2 results:eporesults];
         if(self.p&& self.Write)
         {
         int degree = eporesultCount/20;
         int surplus = eporesultCount%20;
         if(surplus>0)
         degree=degree+1;
         for (int k=0; k<degree; k++) {
         int alen=(((degree-1)==k)?surplus:20);
         Byte arr[alen];
         memcpy(&arr,&eporesults[0+(20*k)],alen);//拷贝到对应的Byte 数组中
         NSData * data0 = [NSData dataWithBytes:arr length:(((degree-1)==k)?surplus:20)];
         [self arrangeBLData:data0 type:@"SET" sendNum:degree];
         //                        NSLog(@"结束%@",data0);
         //                         [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
         }
         }
         }else {
         Byte eporesults[2048];
         int eporesultCount = 2048;
         Byte epovalueBuf[2035];
         
         for (int j=0; j<2035; j++) {
         if (j<2) {
         epovalueBuf[j] = index[j];
         }else {
         epovalueBuf[j] = dataByte[q*2033 + (j-2)];
         }
         }
         
         [SmaBusinessTool getSpliceCmd:0x05 Key:0x60 bytes1:epovalueBuf len:2035 results:eporesults];
         if(self.p&& self.Write)
         {
         int degree = eporesultCount/20;
         int surplus = eporesultCount%20;
         if(surplus>0)
         degree=degree+1;
         for (int k=0; k<degree; k++) {
         int alen=(((degree-1)==k)?surplus:20);
         Byte arr[alen];
         memcpy(&arr,&eporesults[0+(20*k)],alen);//拷贝到对应的Byte 数组中
         NSData * data0 = [NSData dataWithBytes:arr length:(((degree-1)==k)?surplus:20)];
         [self arrangeBLData:data0 type:@"SET" sendNum:degree];
         //                        NSLog(@"结尾%@",data0);
         //                         [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
         }
         }
         }
         
         
         }
         else {
         Byte eporesults[2048];
         int eporesultCount = 2048;
         Byte epovalueBuf[2035];
         
         for (int j=0; j<2035; j++) {
         if (j<2) {
         epovalueBuf[j] = index[j];
         }else {
         epovalueBuf[j] = dataByte[q*2033 + (j-2)];
         }
         }
         
         [SmaBusinessTool getSpliceCmd:0x05 Key:0x60 bytes1:epovalueBuf len:2035 results:eporesults];
         if(self.p&& self.Write)
         {
         int degree = eporesultCount/20;
         int surplus = eporesultCount%20;
         if(surplus>0)
         degree=degree+1;
         for (int k=0; k<degree; k++) {
         int alen=(((degree-1)==k)?surplus:20);
         Byte arr[alen];
         memcpy(&arr,&eporesults[0+(20*k)],alen);//拷贝到对应的Byte 数组中
         NSData * data0 = [NSData dataWithBytes:arr length:(((degree-1)==k)?surplus:20)];
         [self arrangeBLData:data0 type:@"SET" sendNum:degree];
         //                    NSLog(@"开始循环%@",data0);
         //                    [self.p writeValue:data0 forCharacteristic:self.Write type:CBCharacteristicWriteWithResponse];
         }
         }
         }
         
         }
        
    }
         */
}
- (NSData *) setId:(int)Id {
    //用4个字节接收
    Byte bytes[4];
    bytes[0] = (Byte)(Id>>24);
    bytes[1] = (Byte)(Id>>16);
    bytes[2] = (Byte)(Id>>8);
    bytes[3] = (Byte)(Id);
    NSData *data = [NSData dataWithBytes:bytes length:4];
    return data;
}

- (NSData *)setTwoByte:(int)value {
    //用2个字节接收
    Byte bytes[2];
    bytes[0] = (Byte)(value>>8);
    bytes[1] = (Byte)(value);
    NSData *data = [NSData dataWithBytes:bytes length:2];
    return data;
}
- (NSString*)coverFromStringToAsciiStr:(NSString*)string
{
    const char *s = [string cStringUsingEncoding:NSASCIIStringEncoding];
    size_t len = strlen(s);
    
    NSMutableString *asciiCodes = [NSMutableString string];
    for (int i = 0; i < len; i++) {
        [asciiCodes appendFormat:@"%02x ", (int)s[i]];
    }
    return asciiCodes;
    
}
@end

