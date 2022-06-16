#import "mbl-iOS/mbl.h"

// Class doesn't actually needed, just serves as a bridged header 

@interface StreamerEngineWrapper: NSObject
    +(StreamerEngineProxy*)getProxy;
@end
