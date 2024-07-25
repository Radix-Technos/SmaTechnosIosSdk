//
//  SMAWeatherInfo.h
//  SMA
//
//  Created by 有限公司 深圳市 on 2017/11/29.
//  Copyright © 2017年 SMA. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMAWeatherInfo : NSObject

/**
   时间
   @discussion (实况)
 */
@property (nonatomic, copy) NSDate *date;

/**
 当前温度
 @discussion (实况)
 */
@property (nonatomic, assign) int nowTmp;

/**
 最大温度
  @discussion (预报)
 */
@property (nonatomic, assign) int maxTmp;

/**
 最小温度
  @discussion (预报)
 */
@property (nonatomic, assign) int minTmp;

/**
 天气类型 1：晴天；2：多云；3：阴天；4：雨天；5：打雷；6：雷阵雨；7：大风；8：大雪；9：大雾；10：沙尘暴
 @discussion (实况)
 */
@property (nonatomic, assign) int weatherIcon;

/**
 降水量
 @discussion (实况)
 */
@property (nonatomic, assign) int precipitation;

/**
 能见度
 @discussion (实况)
 */
@property (nonatomic, assign) int visibility;

/**
 风速
 @discussion (实况)
 */
@property (nonatomic, assign) int windSpeed;

/**
 相对湿度
 @discussion (实况)
 */
@property (nonatomic, assign) int humidity;

/**
 紫外线指数 1：低；2：中等；3高；4：很高；5：极高
 @discussion (预报)
 */
@property (nonatomic, assign) int ultraviolet;
@end
