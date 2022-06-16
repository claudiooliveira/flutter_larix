# Using LarixStream

How to add streaming support in your application

## Overview

It describes basic scenario of streaming library usage


## Adding streming library in your project
Drag and drop LarixStream folder (make sure it contains Package.framework) from Finder to your project.
![Put LarixStream package](ProjectStructure)

Alternatively, you can open prject settings and perform ‘Package Depencencies - Add - Add Local...’ and select LarixStream folder 

Add reference to LarixStream package for your project's targets on "Frameworks, Libraries and Embedded content" section of "General" tab
![Choose frameworks to add](AddPackage)

By default, LarixStream is using mbl framework with SRT and RIST support. If you don't need it, open Package.swift and change mbl_iOS to include needed version of mbl.xcframework, for example: 
```
let package = Package(
    name: "LarixStream",
    ...
    targets: [
        .binaryTarget(name: "mbl_iOS", path: "lib/mbl_tcp.xcframework")
    ...
    ]
```

## Configure permissions

Info.plist should contain NSCameraUsageDescription and NSMicrophoneUsageDescription sections to allow application to request camera and microphone description.
- Note: See Apple documentation for details:
[NSCameraUsageDescription](https://developer.apple.com/documentation/bundleresources/information_property_list/nscamerausagedescription) and
[NSMicrophoneUsageDescription](https://developer.apple.com/documentation/bundleresources/information_property_list/nsmicrophoneusagedescription)


## Request permissions
Use ``PermissionChecker`` to request permissions. Implement ``PermissionCheckerDelegate`` to respond on permissions.
You still can use your own method to request permissions using `AVCaptureDevice.requestAccess()` , PermissionChecker doesn't have any special integration with LarixStream library.
- See also: [Requesting Authorization for Media Capture on iOS](https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture/requesting_authorization_for_media_capture_on_ios)


## Configure audio session
Initialize ``AudioSession`` during application intialization. 
Call ``AudioSession/start()`` when application become active and ``AudioSession/stop()`` when it become inactive (switch to foreground etc.)
Implement ``AudioSessionStateObserver`` to handle activation and deactivation of audio session
- See also: [AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession)


## Configure streamer
Use ``StreamerBuilder`` to set audio/video parameters, then call ``StreamerBuilder/build()`` to create streamer instance
Implement ``StreamerAppDelegate`` to handle streamer events
- Example:
```
func createStreamer() -> Streamer? {
    let builder = StreamerBuilder()
    builder.delegate = self
    let videoSize = CMVideoDimensions(width: 1280, height: 720)
    let fps = 30.0
    guard let camera = CameraManager.getDefaultBackCamera(videoSize: videoSize, fps: fps) else {
        return nil
    }
    let videoConfig = VideoConfig(cameraID: camera.uniqueID,
                                  videoSize: videoSize,
                                  fps: fps,
                                  keyFrameIntervalDuration: 2.0,
                                  bitrate: 2000000,
                                  portrait: false,
                                  type: kCMVideoCodecType_H264,
                                  profileLevel: kVTProfileLevel_H264_Baseline_AutoLevel,
                                  processingMode: .coreImage)
    builder.videoConfig = videoConfig
    let audioConfig = AudioConfig(sampleRate: 48000, channelCount: 2, bitrate: 128000)
    builder.audioConfig = audioConfig

    return builder.build()
}
```

## Start capture 

Call ``Streamer/startCapture(startAudio:startVideo:startEncoding:)``, then wait for ``StreamerAppDelegate/captureStateDidChange(state:status:)``.  If `state` equals to `.started`, create preview:
```
previewLayer = streamer.createPreviewLayer(parentView: cameraPreview)
```

## Start streaming

