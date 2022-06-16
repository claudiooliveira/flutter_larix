#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface AudioUtils : NSObject

+(double)getSquared:(CMSampleBufferRef)buffer offset:(int32_t)offset count:(int32_t)count stride: (int32_t) stride;

@end
