//
//  MNDVisualInstructionView.swift
//  myndios
//
//  Created by Matthias Hohmann on 20.08.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit
import SwiftyGif
import AVFoundation

/// `MNDVisualInstructionView` is the object that handles display of the optional visuals for each step in `StepView` and  `FittingView`. Videos, gif, images, and nothing are supported. 
class MNDVisualInstructionView: UIView {
    
    let nc = NotificationCenter.default
    var videoView: UIView! = nil
    var imageView: UIImageView! = nil
    var videoPlayer: AVPlayer! = nil
    let gifManager = SwiftyGifManager(memoryLimit: 20)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func set(visualInstructionString instruction: String) {
        if instruction.contains(".m4v") || instruction.contains(".mov") || instruction.contains(".mp4") {
            setVideo(instruction)
        } else if instruction.contains(".gif") {
            setGif(instruction)
        } else {
            setImage(instruction)
        }
    }
    
    func clear() {
        pauseVideo()
        videoView.isHidden = true
        imageView.isHidden = true
    }
    
    private func setImage(_ image: String) {
        pauseVideo()
        // unhide image view
        videoView.isHidden = true
        imageView.isHidden = false
        gifManager.clear()
        imageView.image = UIImage(named: image)
    }
    
    private func setGif(_ gif: String) {
        pauseVideo()
        // unhide image view
        videoView.isHidden = true
        imageView.isHidden = false
        let gif = UIImage(gifName: gif)
        imageView.setGifImage(gif, manager: gifManager, loopCount: -1)
    }
    
    private func setVideo(_ video: String) {
        guard let videoUrl = Bundle.main.url(forResource: video, withExtension: nil) else {return}
        
        // unhide video view
        videoView.isHidden = false
        imageView.isHidden = true
        
        pauseVideo()
        //replaceCurrentItem
        let video = AVURLAsset(url: videoUrl)
        let videoItem = AVPlayerItem(asset: video)
        videoPlayer.replaceCurrentItem(with: videoItem)
        videoPlayer.isMuted = true
        videoPlayer.play()
        // loop the video when it ended
        nc.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.videoPlayer.currentItem, queue: .main)
        { _ in
            self.videoPlayer.seek(to: .zero)
            self.videoPlayer.play()
        }
    }
    
    private func pauseVideo() {
        nc.removeObserver(self)
        videoPlayer.pause()
    }
    
    private func commonInit() {
        autoresizesSubviews = true
        
        // Image View
        imageView = UIImageView(frame: self.bounds)
        imageView.contentMode = .scaleAspectFill
        
        // Video Container
        videoView = UIView(frame: self.bounds)
        
        // Video Player
        videoPlayer = AVPlayer()
        
        // create a video layer for the player
        let layer: AVPlayerLayer = AVPlayerLayer(player: videoPlayer)
        
        // make the layer the same size as the container view
        layer.frame = videoView.bounds
        
        // make the video fill the layer as much as possible while keeping its aspect size
        layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        // add the layer to the container view
        videoView.layer.addSublayer(layer)
        
        addSubview(imageView)
        addSubview(videoView)
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        subviews.forEach {
            $0.scaleToFillSuperView(withConstant: 0.0)
            $0.isUserInteractionEnabled = false
        }
        videoView.layer.sublayers?.first!.frame = videoView.bounds
    }
    
}
