//
//  ViewController.swift
//  SlideShowMaker
//
//  Created by cf-L on 08/22/2017.
//  Copyright (c) 2017 cf-L. All rights reserved.
//

import UIKit
import AVFoundation
import SlideShowMaker

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.makeVideo()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    
    func makeVideo() {
        
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
    }
}

