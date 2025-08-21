//
//  Feedback.swift
//  Brickognize
//
//  Created by Assistant on 8/20/25.
//

import Foundation
import AVFoundation
import UIKit

enum Feedback {
    static func playSuccess() {
        AudioServicesPlaySystemSound(1025) // success-like sound
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}


