//
//  TranslateTypeMap.h
//  Easydict
//
//  Created by tisfeng on 2022/11/5.
//  Copyright © 2022 izual. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EZQueryService.h"

NS_ASSUME_NONNULL_BEGIN

@interface EZServiceTypes : NSObject

+ (NSArray<EZServiceType> *)allServiceTypes;

+ (NSArray<EZQueryService *> *)allServices;

+ (EZQueryService *)serviceWithType:(EZServiceType)type;

+ (NSArray<EZQueryService *> *)servicesFromTypes:(NSArray<EZServiceType> *)types;

@end

NS_ASSUME_NONNULL_END
