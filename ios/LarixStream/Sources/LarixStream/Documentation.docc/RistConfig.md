# RistConfig

@Metadata {
    @DocumentationExtension(mergeBehavior: append)
}

Paremters for RIST connection

## Declaration
```

typedef NS_ENUM(int, RistProfile) {
    kRistProfileSimple = 0,
    kRistProfileMain = 1,
    kRistProfileAdvanced = 2
};

@interface RistConfig : NSObject
    @property NSURL* uri;
    @property ConnectionMode mode;
    @property RistProfile profile;
@end
```


### Instance Properties
    
    uri: NSURL 

Connection URL for rist; may contain parameters supported by [risturl](https://code.videolan.org/rist/librist/-/wikis/risturl-Syntax-as-of-v.-0.2.0)
    port: Int
target port in 1-65535 range

    mode: ConnectionMode
connection mode: Send both audio and video frames or just audio or video

    profile: RistProfile
RIST profile: Simple or Main. Advanced is not fully implemented, so don't use it
