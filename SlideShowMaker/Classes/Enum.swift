//
//  Enum.swift
//  SlideShowMaker
//
//  Created by lcf on 28/07/2017.
//  Copyright © 2017 flow. All rights reserved.
//

import UIKit

public enum ImageTransition: Int {
    case none = 0
    case crossFade
    case crossFadeLong
    case crossFadeUp
    case crossFadeDown
    case wipeRight
    case wipeLeft
    case wipeUp
    case wipeDown
    case wipeMixed
    case slideLeft
    case slideRight
    case slideUp
    case slideDown
    case slideMixed
    case pushRight
    case pushLeft
    case pushUp
    case pushDown
    case pushMixed
    
    static var count: Int {
        return ImageTransition.pushMixed.hashValue + 1
    }
    
    var wipeNext: ImageTransition {
        get {
            var next = self
            switch next {
            case .wipeMixed:
                next = ImageTransition.wipeRight
            case .wipeRight:
                next = ImageTransition.wipeLeft
            case .wipeLeft:
                next = ImageTransition.wipeUp
            case .wipeUp:
                next = ImageTransition.wipeDown
            case .wipeDown:
                next = ImageTransition.wipeRight
            default:
                break
            }
            return next
        }
    }
    
    var slideNext: ImageTransition {
        get {
            var next = self
            switch next {
            case .slideMixed:
                next = ImageTransition.slideRight
            case .slideRight:
                next = ImageTransition.slideLeft
            case .slideLeft:
                next = ImageTransition.slideUp
            case .slideUp:
                next = ImageTransition.slideDown
            case .slideDown:
                next = ImageTransition.slideRight
            default:
                break
            }
            return next
        }
    }
    
    var pushNext: ImageTransition {
        get {
            var next = self
            switch next {
            case .pushMixed:
                next = ImageTransition.pushRight
            case .pushRight:
                next = ImageTransition.pushLeft
            case .pushLeft:
                next = ImageTransition.pushUp
            case .pushUp:
                next = ImageTransition.pushDown
            case .pushDown:
                next = ImageTransition.pushRight
            default:
                break
            }
            return next
        }
    }
    
    var next: ImageTransition {
        get {
            var next = self
            switch next {
            case .wipeMixed, .wipeLeft, .wipeRight, .wipeUp, .wipeDown:
                next = next.wipeNext
            case .slideMixed, .slideLeft, .slideRight, .slideUp, .slideDown:
                next = next.slideNext
            case .pushMixed, .pushLeft, .pushRight, .pushUp, .pushDown:
                next = next.pushNext
            default:
                break
            }
            return next
        }
    }
}

public enum ImageMovement: Int {
    case none = 0
    case fade
    case scale
}

public enum MovementFade: Int {
    case upLeft
    case upRight
    case bottomLeft
    case bottomRight
    
    var next: MovementFade {
        get {
            var next = self
            switch next {
            case .upLeft:
                next = MovementFade.upRight
            case .upRight:
                next = MovementFade.bottomLeft
            case .bottomLeft:
                next = MovementFade.bottomRight
            case .bottomRight:
                next = MovementFade.upLeft
            }
            return next
        }
    }
}
