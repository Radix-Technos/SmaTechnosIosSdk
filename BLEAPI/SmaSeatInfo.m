//
//  SmaSeatInfo.m
//  SmaLife
//
//  Created by 有限公司 深圳市 on 15/4/14.
//  Copyright (c) 2015年 SmaLife. All rights reserved.
//

#import "SmaSeatInfo.h"
#import <objc/runtime.h>
@class SmaSeatInfo;

@implementation SmaSeatInfo
//归档
- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.isOpen forKey:@"isOpen"];
    [encoder encodeObject:self.stepValue forKey:@"stepValue"];
    [encoder encodeObject:self.seatValue forKey:@"seatValue"];
    [encoder encodeObject:self.beginTime0 forKey:@"beginTime0"];
    [encoder encodeObject:self.endTime0 forKey:@"endTime0"];
    [encoder encodeObject:self.isOpen0 forKey:@"isOpen0"];
    [encoder encodeObject:self.beginTime1 forKey:@"beginTime1"];
    [encoder encodeObject:self.endTime1 forKey:@"endTime1"];
    [encoder encodeObject:self.isOpen1 forKey:@"isOpen1"];
    [encoder encodeObject:self.repeatWeek forKey:@"pepeatWeek"];
//    unsigned int count = 0;
//    Ivar *ivars = class_copyIvarList([SmaSeatInfo class], &count);
//    for (int i = 0; i<count; i++) {
//        // 取出i位置对应的成员变量
//        Ivar ivar = ivars[i];
//        // 查看成员变量
//        const char *name = ivar_getName(ivar);
//        // 归档
//        NSString *key = [NSString stringWithUTF8String:name];
//        id value = [self valueForKey:key];
//        [encoder encodeObject:value forKey:key];
//    }
//    free(ivars); 
}
//解档
-(id)initWithCoder:(NSCoder *)decoder
{
//    if (self = [super init]) {
//        unsigned int count = 0;
//        Ivar *ivars = class_copyIvarList([SmaSeatInfo class], &count);
//        for (int i = 0; i<count; i++) {
//            // 取出i位置对应的成员变量
//            Ivar ivar = ivars[i];
//            // 查看成员变量
//            const char *name = ivar_getName(ivar);
//            // 归档
//            NSString *key = [NSString stringWithUTF8String:name];
//            id value = [decoder decodeObjectForKey:key];
//            // 设置到成员变量身上
//            [self setValue:value forKey:key];
//        }
//        free(ivars);
//    }
//    return self;
    if (self = [super init]) {
        self.isOpen = [decoder decodeObjectForKey:@"isOpen"];
        self.stepValue = [decoder decodeObjectForKey:@"stepValue"];
        self.seatValue = [decoder decodeObjectForKey:@"seatValue"];
        self.beginTime0 = [decoder decodeObjectForKey:@"beginTime0"];
        self.endTime0 = [decoder decodeObjectForKey:@"endTime0"];
        self.isOpen0 = [decoder decodeObjectForKey:@"isOpen0"];
        self.beginTime1 = [decoder decodeObjectForKey:@"beginTime1"];
        self.endTime1 = [decoder decodeObjectForKey:@"endTime1"];
        self.isOpen1 = [decoder decodeObjectForKey:@"isOpen1"];
        self.repeatWeek=[decoder decodeObjectForKey:@"pepeatWeek"];
    }
    return self;

}


@end
