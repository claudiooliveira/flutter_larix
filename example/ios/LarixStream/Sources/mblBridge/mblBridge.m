#import <Foundation/Foundation.h>
#include "include/mblBridge.h"

@implementation StreamerEngineWrapper

+(StreamerEngineProxy*)getProxy {
    StreamerEngineProxy* res = [[StreamerEngineProxy alloc] init];
    return res;
}

@end
