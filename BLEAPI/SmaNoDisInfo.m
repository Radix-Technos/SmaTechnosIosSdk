//
//  SmaNoDisInfo.m
//  SmaLife
//
//  Created by 有限公司 深圳市 on 16/4/21.
//  Copyright © 2016年 SmaLife. All rights reserved.
//

#import "SmaNoDisInfo.h"

@implementation SmaNoDisInfo
//归档
- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.isOpen forKey:@"isOpen"];
    [encoder encodeObject:self.beginTime1 forKey:@"beginTime1"];
    [encoder encodeObject:self.endTime1 forKey:@"endTime1"];
    [encoder encodeObject:self.isOpen1 forKey:@"isOpen1"];
    [encoder encodeObject:self.beginTime2 forKey:@"beginTime2"];
    [encoder encodeObject:self.endTime2 forKey:@"endTime2"];
    [encoder encodeObject:self.isOpen2 forKey:@"isOpen2"];
    [encoder encodeObject:self.beginTime3 forKey:@"beginTime3"];
    [encoder encodeObject:self.endTime3 forKey:@"endTime3"];
    [encoder encodeObject:self.isOpen3 forKey:@"isOpen3"];
    [encoder encodeObject:self.repeatWeek forKey:@"pepeatWeek"];
}

//解档
- (id)initWithCoder:(NSCoder *)decoder{
    if (self = [super init]) {
        self.isOpen = [decoder decodeObjectForKey:@"isOpen"];
        self.beginTime1 = [decoder decodeObjectForKey:@"beginTime1"];
        self.endTime1 = [decoder decodeObjectForKey:@"endTime1"];
        self.isOpen1 = [decoder decodeObjectForKey:@"isOpen1"];
        self.beginTime2 = [decoder decodeObjectForKey:@"beginTime2"];
        self.endTime2 = [decoder decodeObjectForKey:@"endTime2"];
        self.isOpen2 = [decoder decodeObjectForKey:@"isOpen2"];
        self.beginTime3 = [decoder decodeObjectForKey:@"beginTime3"];
        self.endTime3 = [decoder decodeObjectForKey:@"endTime3"];
        self.isOpen3 = [decoder decodeObjectForKey:@"isOpen3"];
        self.repeatWeek = [decoder decodeObjectForKey:@"pepeatWeek"];
    }
    return self;
}
@end
