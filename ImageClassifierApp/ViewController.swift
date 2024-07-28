//
//  ViewController.swift
//  ImageClassifierApp
//
//  Created by Edwin Yovany on 27/07/24.
//

import UIKit

class ViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var iconImage: UIImageView!
    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var resultLabel: UILabel!
    
    // MARK: - Properties
    private lazy var cameraManager = CameraManager(previewView: previewView)

    // MARK: - Override Methods

    /**
     This method is called after the controller's view is loaded into memory.
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        cameraManager.delegate = self
    }

    /**
     This method is called when the view is about to appear on the screen.
     - Parameter animated: A boolean value that indicates whether the appearance of the view should be animated or not.
     */
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        cameraManager.checkCameraConfigurationAndStartSession()

        previewView.layer.cornerRadius = 24
        previewView.layer.masksToBounds = true
    }

    /**
     This method is called when the view is about to disappear from the screen.
     - Parameter animated: A boolean value that indicates whether the disappearance of the view should be animated or not.
     */
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cameraManager.stopSession()
    }

    // MARK: - Private Methods

    /**
     This method sets up the UI components.
     */
    private func setupUI() {
        previewView.layer.cornerRadius = 24
        previewView.layer.masksToBounds = true
        previewView.layer.shadowOffset = CGSize(width: 0, height: 5)
        previewView.layer.shadowColor = UIColor.black.cgColor
        previewView.layer.shadowOpacity = 0.2

        iconImage.layer.cornerRadius = 36
        iconImage.layer.masksToBounds = true
    }

}

// MARK: - CameraManagerDelegate
extension ViewController: CameraManagerDelegate {
    /**
     This method is called when the camera permissions are denied.
     */
    func presentCameraPermissionsDeniedAlert() {
        print("Camera permissions denied")
    }
    
    /**
     This method is called when the configuration of the camera fails.
     */
    func presentVideoConfigurationErrorAlert() {
        print("Video configuration error")
    }
    
    /**
     This method is called when the session runtime error occurs.
     */
    func sessionRunTimeErrorOccured() {
        print("Session runtime error")
    }
    
    /**
     This method is called when the session was interrupted.
     - Parameter resumeManually: A boolean value that indicates whether the session can be resumed manually or not.
     */
    func sessionWasInterrupted(canResumeManually resumeManually: Bool) {
        print("Session interrupted")
    }
    
    /**
     This method is called when the session interruption ended.
     */
    func sessionInterruptionEnded() {
        print("Session interruption ended")
    }
    
    /**
     This method is called when the camera manager outputs a pixel buffer.
     - Parameter pixelBuffer: A CVPixelBuffer object.
     */
    func didOutput(pixelBuffer: CVPixelBuffer) {
        print("Pixel buffer output")
    }
}

