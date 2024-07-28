//
//  CameraManager.swift
//  ImageClassifierApp
//
//  Created by Edwin Yovany on 27/07/24.
//

import UIKit
import AVFoundation

/**
 This protocol defines methods that are called when certain events occur in the CameraManager class.
 */
protocol CameraManagerDelegate: AnyObject {
  func didOutput(pixelBuffer: CVPixelBuffer)
  func presentCameraPermissionsDeniedAlert()
  func presentVideoConfigurationErrorAlert()
  func sessionRunTimeErrorOccured()
  func sessionWasInterrupted(canResumeManually resumeManually: Bool)
  func sessionInterruptionEnded()

}

/**
 This enum defines the possible camera configurations.
 */
enum CameraConfiguration {
  case success
  case failed
  case permissionDenied
}

class CameraManager: NSObject {

  // MARK: Properties
  private let session: AVCaptureSession = AVCaptureSession()
  private let previewView: PreviewView
  private let sessionQueue = DispatchQueue(label: "sessionQueue")
  private var cameraConfiguration: CameraConfiguration = .failed
  private lazy var videoDataOutput = AVCaptureVideoDataOutput()
  private var isSessionRunning = false

  // MARK: Delegate
  weak var delegate: CameraManagerDelegate?

  /**
   Initializes a new CameraManager object.
   - Parameter previewView: A PreviewView object that displays the camera feed.
   */
  init(previewView: PreviewView) {
    self.previewView = previewView
    super.init()

    session.sessionPreset = .high
    self.previewView.session = session
    self.previewView.previewLayer.connection?.videoOrientation = .portrait
    self.previewView.previewLayer.videoGravity = .resizeAspectFill
    self.attemptToConfigureSession()
  }

  /**
   Checks the camera configuration and starts the session.
   */
  func checkCameraConfigurationAndStartSession() {
    sessionQueue.async {
      switch self.cameraConfiguration {
      case .success:
        self.addObservers()
        self.startSession()
      case .failed:
        DispatchQueue.main.async {
          self.delegate?.presentVideoConfigurationErrorAlert()
        }
      case .permissionDenied:
        DispatchQueue.main.async {
          self.delegate?.presentCameraPermissionsDeniedAlert()
        }
      }
    }
  }
  
  func stopSession() {
    self.removeObservers()
    sessionQueue.async {
      if self.session.isRunning {
        self.session.stopRunning()
        self.isSessionRunning = self.session.isRunning
      }
    }

  }

  /**
   Resumes the interrupted session.
   - Parameter completion: A closure that is called when the session is resumed.
   */
  func resumeInterruptedSession(withCompletion completion: @escaping (Bool) -> ()) {
    sessionQueue.async {
      self.startSession()

      DispatchQueue.main.async {
        completion(self.isSessionRunning)
      }
    }
  }

  /**
   This method starts the session.
   */
  private func startSession() {
    self.session.startRunning()
    self.isSessionRunning = self.session.isRunning
  }

  /**
   This method attempts to configure the session.
   */
  private func attemptToConfigureSession() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      self.cameraConfiguration = .success
    case .notDetermined:
      self.sessionQueue.suspend()
      self.requestCameraAccess(completion: { (granted) in
        self.sessionQueue.resume()
      })
    case .denied:
      self.cameraConfiguration = .permissionDenied
    default:
      break
    }

    self.sessionQueue.async {
      self.configureSession()
    }
  }

  /**
   This method requests Camera access permissions 
   - Parameter completion: A closure that is called when the permissions are granted.
   */
  private func requestCameraAccess(completion: @escaping (Bool) -> ()) {
    AVCaptureDevice.requestAccess(for: .video) { (granted) in
      if !granted {
        self.cameraConfiguration = .permissionDenied
      }
      else {
        self.cameraConfiguration = .success
      }
      completion(granted)
    }
  }
 
  /**
   This method configures the session.
   */
  private func configureSession() {

    guard cameraConfiguration == .success else {
      return
    }
    session.beginConfiguration()

    // Tries to add an AVCaptureDeviceInput.
    guard addVideoDeviceInput() == true else {
      self.session.commitConfiguration()
      self.cameraConfiguration = .failed
      return
    }

    // Tries to add an AVCaptureVideoDataOutput.
    guard addVideoDataOutput() else {
      self.session.commitConfiguration()
      self.cameraConfiguration = .failed
      return
    }

    session.commitConfiguration()
    self.cameraConfiguration = .success
  }

  private func addVideoDeviceInput() -> Bool {
    guard let camera  = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
      return false
    }

    do {
      let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
      if session.canAddInput(videoDeviceInput) {
        session.addInput(videoDeviceInput)
        return true
      }
      else {
        return false
      }
    }
    catch {
      fatalError("Cannot create video device input")
    }
  }

  private func addVideoDataOutput() -> Bool {

    let sampleBufferQueue = DispatchQueue(label: "sampleBufferQueue")
    videoDataOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)
    videoDataOutput.alwaysDiscardsLateVideoFrames = true
    videoDataOutput.videoSettings = [ String(kCVPixelBufferPixelFormatTypeKey) : kCMPixelFormat_32BGRA]

    if session.canAddOutput(videoDataOutput) {
      session.addOutput(videoDataOutput)
      videoDataOutput.connection(with: .video)?.videoOrientation = .portrait
      return true
    }
    return false
  }

  // MARK: Notification Observer Handling
  private func addObservers() {
    NotificationCenter.default.addObserver(self, selector: #selector(CameraManager.sessionRuntimeErrorOccured(notification:)), name: NSNotification.Name.AVCaptureSessionRuntimeError, object: session)
    NotificationCenter.default.addObserver(self, selector: #selector(CameraManager.sessionWasInterrupted(notification:)), name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: session)
    NotificationCenter.default.addObserver(self, selector: #selector(CameraManager.sessionInterruptionEnded), name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: session)
  }

  // MARK: Remove Observers
  private func removeObservers() {
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionRuntimeError, object: session)
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: session)
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: session)
  }

  // MARK: Notification Observers
  @objc func sessionWasInterrupted(notification: Notification) {

    if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
      let reasonIntegerValue = userInfoValue.integerValue,
      let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
      print("Capture session was interrupted with reason \(reason)")

      var canResumeManually = false
      if reason == .videoDeviceInUseByAnotherClient {
        canResumeManually = true
      } else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
        canResumeManually = false
      }

      self.delegate?.sessionWasInterrupted(canResumeManually: canResumeManually)

    }
  }

  /**
   This method is called when the session interruption ended.
   */
  @objc func sessionInterruptionEnded(notification: Notification) {

    self.delegate?.sessionInterruptionEnded()
  }

  /**
   This method is called when a runtime error occurs in the capture session.
   - Parameter notification: A Notification object.
   */
  @objc func sessionRuntimeErrorOccured(notification: Notification) {
    guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
      return
    }

    print("Capture session runtime error: \(error)")

    if error.code == .mediaServicesWereReset {
      sessionQueue.async {
        if self.isSessionRunning {
          self.startSession()
        } else {
          DispatchQueue.main.async {
            self.delegate?.sessionRunTimeErrorOccured()
          }
        }
      }
    } else {
      self.delegate?.sessionRunTimeErrorOccured()

    }
  }
}

//MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

    // Converts the CMSampleBuffer to a CVPixelBuffer.
    let pixelBuffer: CVPixelBuffer? = CMSampleBufferGetImageBuffer(sampleBuffer)

    guard let imagePixelBuffer = pixelBuffer else {
      return
    }

    // Delegates the pixel buffer to the ViewController.
    delegate?.didOutput(pixelBuffer: imagePixelBuffer)
  }

}

