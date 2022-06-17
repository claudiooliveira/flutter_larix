# SrtConfig

@Metadata {
    @DocumentationExtension(mergeBehavior: append)
}

Paremters for SRT connection

## Declaration
```

typedef NS_ENUM(int, SrtConnectMode) {
    kSrtConnectModeCaller = 0,
    kSrtConnectModeListen = 1,
    kSrtConnectModeRendezvous = 2
};

typedef NS_ENUM(int, ConnectionRetransmitAlgo) {
    kConnectionRetransmitAlgoDefault = 0,
    kConnectionRetransmitAlgoReduced = 1
};

@interface SrtConfig : NSObject
    @property NSString* host;
    @property int port;
    @property ConnectionMode mode;
    @property SrtConnectMode connectMode;
    @property NSString* passphrase;
    @property int pbkeylen;
    @property int latency;
    @property int32_t maxbw;
    @property ConnectionRetransmitAlgo retransmitAlgo;
    @property NSString* streamid;
@end
```


### Instance Properties
    
    host: NSString 

Name host name or IP address.
For IPv6, IP addres should be provided in a form [xx:xx:xx:xx:xx:xx]
If connectMode set to listen, you may set any valid IP; use IPv6 format (you may use simple [::] ) to listen on IPv6 interface.
******
    port: Int
target port in 1-65535 range
******

    mode: ConnectionMode
connection mode: Send both audio and video frames or just audio or video

******
    connectMode: SrtConnectMode
SRT connection mode: caller, listener or rendez-vouz
- Note: In a listener mode multiple client connections may be served. It will remain in connected state even if there are no clients.
Each client will receive own stream, so traffic will be multiplied to number of clients.
***
    passphrase: NSString
**SRTO_PASSPHRASE**
***
    pbkeylen: Int
**SRTO_PBKEYLEN**
- Note: Accepted values are 0 (no encryption), 16 (AES-128), 24 (AES-192), 32 (AES-256)
***
    latency: Int
 **SRTO_LATENCY**
***
    maxbw: Int32
**SRTO_MAXBW** (Mind that it set in *BYTES* per second)
- Tip: Recommended to set to 0 and let SRT library to decide
***
    retransmitAlgo: ConnectionRetransmitAlgo
**SRTO_RETRANSMITALGO**
***
    streamid: NSString
**SRTO_STREAMID**
    
