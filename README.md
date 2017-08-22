# SlideShowMaker

[![CI Status](http://img.shields.io/travis/cf-L/SlideShowMaker.svg?style=flat)](https://travis-ci.org/cf-L/SlideShowMaker)
[![Version](https://img.shields.io/cocoapods/v/SlideShowMaker.svg?style=flat)](http://cocoapods.org/pods/SlideShowMaker)
[![License](https://img.shields.io/cocoapods/l/SlideShowMaker.svg?style=flat)](http://cocoapods.org/pods/SlideShowMaker)
[![Platform](https://img.shields.io/cocoapods/p/SlideShowMaker.svg?style=flat)](http://cocoapods.org/pods/SlideShowMaker)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

SlideShowMaker is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "SlideShowMaker"
```



# Usage

```swift
let images = [#imageLiteral(resourceName: "img0"), #imageLiteral(resourceName: "img1"), #imageLiteral(resourceName: "img2"), #imageLiteral(resourceName: "img3")]
        
var audio: AVURLAsset?
var timeRange: CMTimeRange?
if let audioURL = Bundle.main.url(forResource: "Sound", withExtension: "mp3") {
	audio = AVURLAsset(url: audioURL)
	let audioDuration = CMTime(seconds: 30, preferredTimescale: audio!.duration.timescale)
    timeRange = CMTimeRange(start: kCMTimeZero, duration: audioDuration)
}
        
// OR: VideoMaker(images: images, movement: ImageMovement.fade)
let maker = VideoMaker(images: images, transition: ImageTransition.wipeMixed)
    
maker.contentMode = .scaleAspectFit
        
maker.exportVideo(audio: audio, audioTimeRange: timeRange, completed: { success, videoURL in
	if let url = videoURL {
		print(url)  // /Library/Mov/merge.mov
	}
}).progress = { progress in
	print(progress)
}
```





## Author

cf-L, linchangfeng@live.com

## License

SlideShowMaker is available under the MIT license. See the LICENSE file for more info.
