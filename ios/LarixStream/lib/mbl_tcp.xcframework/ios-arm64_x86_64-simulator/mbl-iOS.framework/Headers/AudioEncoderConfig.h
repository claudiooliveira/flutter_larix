#import <Foundation/Foundation.h>

@interface AudioEncoderConfig : NSObject

/*! @brief audio sample rate in Hz
    @discussion If you do not explicitly set a sample rate then the encoder will use the same value
    which is available in the un-compressed audio, just to avoid unnecessary re-sampling.
*/
@property double sampleRate;

/*! @brief audio bitrate rate in bits per second
    @discussion If you do not explicitly set a bit rate then the encoder will pick the correct value for you depending on sample rate.
*/
@property int bitrate;

/*! @brief number of audio channels (1 or 2)
    @discussion Conversion between mono and stereo will be perfomed if neccesary
*/
@property int channelCount;

/*! @brief manufacturer ID
    @discussion On iPhoneOS, a codec's manufacturer can be used to distinguish between hardware and software codecs
    (kAppleSoftwareAudioCodecManufacturer vs kAppleHardwareAudioCodecManufacturer).
*/
@property UInt32 manufacturer;

@end
