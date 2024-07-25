//
//  SmaHRHisInfo.m
//  SmaLife
//
//  Created by 有限公司 深圳市 on 16/3/31.
//  Copyright © 2016年 SmaLife. All rights reserved.
//

#import "SmaHRHisInfo.h"

@implementation SmaHRHisInfo

//归档
- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.dayFlags forKey:@"dayFlags"];
    [encoder encodeObject:self.beginhour0 forKey:@"beginhour"];
    [encoder encodeObject:self.endhour0 forKey:@"endhour"];
    [encoder encodeObject:self.beginhour1 forKey:@"beginhour1"];
    [encoder encodeObject:self.endhour1 forKey:@"endhour1"];
    [encoder encodeObject:self.beginhour2 forKey:@"beginhour2"];
    [encoder encodeObject:self.endhour2 forKey:@"endhour2"];
    [encoder encodeObject:self.tagname forKey:@"tagname"];
    [encoder encodeObject:self.isopen forKey:@"isopen"];
    [encoder encodeObject:self.isopen0 forKey:@"isopen0"];
    [encoder encodeObject:self.isopen1 forKey:@"isopen1"];
    [encoder encodeObject:self.isopen2 forKey:@"isopen2"];
//    [encoder encodeObject:self.nextDay forKey:@"nextDay"];
}
//解当
-(id)initWithCoder:(NSCoder *)decoder
{
    
    if (self = [super init]) {
        self.dayFlags = [decoder decodeObjectForKey:@"dayFlags"];
        self.beginhour0 = [decoder decodeObjectForKey:@"beginhour"];
        self.endhour0 = [decoder decodeObjectForKey:@"endhour"];
        self.beginhour1 = [decoder decodeObjectForKey:@"beginhour1"];
        self.endhour1 = [decoder decodeObjectForKey:@"endhour1"];
        self.beginhour2=[decoder decodeObjectForKey:@"beginhour2"];
        self.endhour2 = [decoder decodeObjectForKey:@"endhour2"];
        self.tagname = [decoder decodeObjectForKey:@"tagname"];
        self.isopen = [decoder decodeObjectForKey:@"isopen"];
        self.isopen0 = [decoder decodeObjectForKey:@"isopen0"];
        self.isopen1 = [decoder decodeObjectForKey:@"isopen1"];
        self.isopen2=[decoder decodeObjectForKey:@"isopen2"];
//        self.nextDay=[decoder decodeObjectForKey:@"nextDay"];
    }
    return self;
    
}
@end
