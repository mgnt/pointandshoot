//
//  PhotoProcessor.swift
//  PointAndShoot
//
//  Created by Jared Sinclair on 12/30/19.
//  Copyright © 2019 Nice Boy, LLC. All rights reserved.
//

import AVFoundation
import Photos
import os.log
import Etcetera

final class PhotoProcessor: NSObject {

    enum Error: Swift.Error {
        case noData
        case avFoundation(Swift.Error)
    }

    var uniqueID: Int64 { settings.uniqueID }

    private let settings: AVCapturePhotoSettings
    private let userOrientation: AVCaptureVideoOrientation
    private let callbackQueue: OperationQueue
    private let uponWillCapture: () -> Void
    private let uponLivePhotoCaptureStateChange: (Bool) -> Void
    private let uponIndeterminateProcessingChange: (Bool) -> Void
    private let completion: (PhotoProcessor, Result<CapturedPhoto, Error>) -> Void
    private var capture: AVCapturePhoto?
    private var livePhotoCompanionMovieURL: URL?
    private var maxPhotoProcessingTime: CMTime?
    private lazy var context = CIContext()

    init(settings: AVCapturePhotoSettings,
         userOrientation: AVCaptureVideoOrientation,
         callbackQueue: OperationQueue,
         uponWillCapture: @escaping () -> Void,
         uponLivePhotoCaptureStateChange: @escaping (_ isRecording: Bool) -> Void,
         uponIndeterminateProcessingChange: @escaping (_ isProcessing: Bool) -> Void,
         completion: @escaping (PhotoProcessor, Result<CapturedPhoto, Error>) -> Void) {
        self.settings = settings
        self.userOrientation = userOrientation
        self.callbackQueue = callbackQueue
        self.uponWillCapture = uponWillCapture
        self.uponLivePhotoCaptureStateChange = uponLivePhotoCaptureStateChange
        self.uponIndeterminateProcessingChange = uponIndeterminateProcessingChange
        self.completion = completion
    }

    private func finish(with result: Result<CapturedPhoto, Error>) {
        callbackQueue.asap {
            self.completion(self, result)
        }
    }

}

extension PhotoProcessor: AVCapturePhotoCaptureDelegate {

    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        if resolvedSettings.livePhotoMovieDimensions.width > 0 && resolvedSettings.livePhotoMovieDimensions.height > 0 {
            callbackQueue.asap {
                self.uponLivePhotoCaptureStateChange(true)
            }
        }
        maxPhotoProcessingTime = resolvedSettings.photoProcessingTimeRange.start + resolvedSettings.photoProcessingTimeRange.duration
    }

    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        callbackQueue.asap {
            self.uponWillCapture()
        }

        guard let maxPhotoProcessingTime = maxPhotoProcessingTime else {
            return
        }

        // Show a spinner if processing time exceeds one second.
        let oneSecond = CMTime(seconds: 1, preferredTimescale: 1)
        if maxPhotoProcessingTime > oneSecond {
            callbackQueue.asap {
                self.uponIndeterminateProcessingChange(true)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Swift.Error?) {
        callbackQueue.asap {
            self.uponIndeterminateProcessingChange(false)
        }

        if let error = error {
            ObligatoryLoggingPun.error("Error capturing photo: \(error)")
        } else {
            capture = photo
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        callbackQueue.asap {
            self.uponLivePhotoCaptureStateChange(false)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Swift.Error?) {
        if error != nil {
            ObligatoryLoggingPun.error("Error processing Live Photo companion movie: \(String(describing: error))")
            return
        }
        livePhotoCompanionMovieURL = outputFileURL
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Swift.Error?) {
        if let error = error {
            ObligatoryLoggingPun.error("Error capturing photo: \(error)")
            finish(with: .failure(.avFoundation(error)))
            return
        }

        guard let capture = capture else {
            ObligatoryLoggingPun.error("No photo data captured.")
            finish(with: .failure(.noData))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let capturedPhoto = CapturedPhoto(
                capture: capture,
                livePhotoFileURL: self.livePhotoCompanionMovieURL,
                settings: self.settings,
                userOrientation: self.userOrientation
            )
            if let capture = capturedPhoto {
                self.finish(with: .success(capture))
            } else {
                ObligatoryLoggingPun.error("Unable to extrapolate image resources.")
                self.finish(with: .failure(.noData))
            }
        }
    }

}
