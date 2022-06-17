#import <CoreMedia/CoreMedia.h>
#import "include/AudioUtils.h"

static const double conversion16Base = 32768.0;
@implementation AudioUtils {
}

// Get sum of squared values for samples converted to (-1...1) range
+(double)getSquared:(CMSampleBufferRef)buffer offset:(int32_t)offset count:(int32_t)count stride:(int32_t)stride {
    if (count <= 0 || offset < 0 || stride <= 0) {
        return 0.0;
    }
    OSStatus status;
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(buffer);
    size_t length;
    char* byteBuffer;
    status = CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &length, &byteBuffer);
    if (status != noErr) {
        return 0;
    }
    int16_t* shortBuffer = ((int16_t*)byteBuffer)+offset;
    int16_t* end = shortBuffer+count;
    double sum = 0.0;
    for (int16_t* buf=shortBuffer; buf < end; buf += stride) {
        double f = ((double)*buf)/conversion16Base;
        sum += f*f;
    }
    return sum;
    
}

@end
