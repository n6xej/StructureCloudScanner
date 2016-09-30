 //
//	This file is a Swift port of the Structure SDK sample app "Scanner".
//	Copyright © 2016 Occipital, Inc. All rights reserved.
//	http://structure.io
//
//  ViewController+Camera.swift
//
//  Ported by Christopher Worley on 8/20/16.
//

 
extension ViewController  {
	
	func queryCameraAuthorizationStatusAndNotifyUserIfNotGranted() -> Bool {
		
		let numCameras = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)!

		if 0 == numCameras.count {
			return false
		}
		// This can happen even on devices that include a camera, when camera access is restricted globally.

		let authStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)

		if authStatus != .authorized {
			
			NSLog("Not authorized to use the camera!")

			AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { granted in
				// This block fires on a separate thread, so we need to ensure any actions here
				// are sent to the right place.
				// If the request is granted, let's try again to start an AVFoundation session.
				// Otherwise, alert the user that things won't go well.
				if granted {
					DispatchQueue.main.async {
						self.startColorCamera()
						self._appStatus.colorCameraIsAuthorized = true
						self.updateAppStatusMessage()
					}
				}
			})
			return false
		}

		return true
	}
    
	func selectCaptureFormat(_ demandFormat: NSDictionary) {
		
		var selectedFormat: AVCaptureDeviceFormat? = nil
		
        let base420f: UInt32 = 875704422  // decimal val of '420f'
        let fourCharCodeStr = base420f as FourCharCode
		
		for format in videoDevice!.formats {

			let formatDesc = (format as! AVCaptureDeviceFormat).formatDescription
			let fourCharCode = CMFormatDescriptionGetMediaSubType(formatDesc!)
			
			let videoFormatDesc = formatDesc
			let formatDims = CMVideoFormatDescriptionGetDimensions(videoFormatDesc!)
			

			let widthNeeded = demandFormat["width"] as! NSNumber
			let heightNeeded = demandFormat["height"] as! NSNumber
			
			if widthNeeded.int32Value != formatDims.width {
				continue
			}
			
			if heightNeeded.int32Value != formatDims.height {
				continue
			}
			// we only support full range YCbCr for now
			if fourCharCode != fourCharCodeStr {
				continue
			}
			
			selectedFormat = format as? AVCaptureDeviceFormat
		}
		
		videoDevice!.activeFormat = selectedFormat!
	}

    func setLensPositionWithValue(_ value: Float, lockVideoDevice: Bool) {
		
		// Abort if there's no videoDevice yet.
        if videoDevice == nil {
            return
        }
 
        if lockVideoDevice {
            do {
                try videoDevice!.lockForConfiguration()
            } catch {
                return
                // Abort early if we cannot lock and are asked to.
            }
        }
		
        videoDevice!.setFocusModeLockedWithLensPosition(value, completionHandler: nil)
		
        if lockVideoDevice {
            videoDevice!.unlockForConfiguration()
        }
    }
	
	func doesStructureSensorSupport24FPS() -> Bool {

		var ret = false

		if _sensorController != nil {
			let isConnected = _sensorController.isConnected()
			if isConnected {
				ret = 0 >= _sensorController.getFirmwareRevision().compare("2.0", options: .numeric, range: nil, locale: nil).rawValue
			}
		}
		
		return ret
	}
	
	func videoDeviceSupportsHighResColor() -> Bool {
	
	// High Resolution Color format is width 2592, height 1936.
	// Most recent devices support this format at 30 FPS.
	// However, older devices may only support this format at a lower framerate.
	// In your Structure Sensor is on firmware 2.0+, it supports depth capture at FPS of 24.
	
	let testVideoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
		if testVideoDevice == nil {
            
            assertionFailure()
		}

		let structureSensorSupports24FPS = doesStructureSensorSupport24FPS()
	
		let base420f: UInt32 = 875704422  // decimal val of '420f'
		let fourCharCodeStr = base420f as FourCharCode
		
		for format in (testVideoDevice?.formats)! {
	
			let firstFrameRateRange = (format as! AVCaptureDeviceFormat).videoSupportedFrameRateRanges[0]
			
			let formatMinFps = (firstFrameRateRange as AnyObject).minFrameRate
			let formatMaxFps = (firstFrameRateRange as AnyObject).maxFrameRate

			if ( formatMaxFps! < 15 // Max framerate too low.
				|| formatMinFps! > 30 // Min framerate too high.
				|| (formatMaxFps! == 24 && !structureSensorSupports24FPS && formatMinFps! > 15)) { // We can neither do the 24 FPS max framerate, nor fall back to 15.
				continue
			}

			let formatDesc: CMFormatDescription
		
			formatDesc = (format as! AVCaptureDeviceFormat).formatDescription

			let fourCharCode = CMFormatDescriptionGetMediaSubType(formatDesc)
	
			let videoFormatDesc = formatDesc
			let formatDims = CMVideoFormatDescriptionGetDimensions(videoFormatDesc)
	
			if ( 2592 != formatDims.width ) {
				continue
			}
	
			if ( 1936 != formatDims.height ) {
				continue
			}
	
			// we only support full range YCbCr for now
			if fourCharCode != fourCharCodeStr {
				continue
			}

			// All requirements met.
			return true
		}
	
		// No acceptable high-res format was found.
		return false
	}
	
	func setupColorCamera() {
		
		// If already setup, skip it
		if avCaptureSession != nil {
			return
		}

		let cameraAccessAuthorized = self.queryCameraAuthorizationStatusAndNotifyUserIfNotGranted()

		if !cameraAccessAuthorized {
			_appStatus.colorCameraIsAuthorized = false
			updateAppStatusMessage()
			return
		}

		// Set up Capture Session. AVCaptureSession()
		avCaptureSession = AVCaptureSession()
		if avCaptureSession == nil {

			return
		}

		avCaptureSession!.beginConfiguration()
		
		// InputPriority allows us to select a more precise format (below)
		avCaptureSession!.sessionPreset = AVCaptureSessionPresetInputPriority

		// Create a video device and input from that Device.  Add the input to the capture session.
		videoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
		if videoDevice == nil {
			assertionFailure()
		}
		
		// Configure Focus, Exposure, and White Balance
        
		do {
			
			try self.videoDevice!.lockForConfiguration()
			
			var imageWidth: Int = -1
			var imageHeight: Int = -1

			if _dynamicOptions.highResColoring {

				// High-resolution uses 2592x1936, which is close to a 4:3 aspect ratio.
				// Other aspect ratios such as 720p or 1080p are not yet supported.
				imageWidth = 2592
				imageHeight = 1936
			}
			else {

				// Low resolution uses VGA.
				imageWidth = 640
				imageHeight = 480
			}

			// Select capture format
			self.selectCaptureFormat(["width": imageWidth, "height": imageHeight])
			
			// Allow exposure to initially change
			if videoDevice!.isExposureModeSupported(.continuousAutoExposure) {
				videoDevice!.exposureMode = .continuousAutoExposure
			}

			// Allow white balance to initially change
			if videoDevice!.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
				videoDevice!.whiteBalanceMode = .continuousAutoWhiteBalance
			}
			
			// Apply to specified focus position.
			setLensPositionWithValue(Float(_options.lensPosition), lockVideoDevice: false)
			
			videoDevice!.unlockForConfiguration()

		} catch {
			
		}
		
		do {
			//  Add the device to the session.
			let input = try AVCaptureDeviceInput(device: self.videoDevice)
			
			avCaptureSession!.addInput(input) // After this point, captureSession captureOptions are filled.
		}
		catch {
			NSLog("Cannot initialize AVCaptureDeviceInput")

			assertionFailure()
		}

		//  Create the video data output.
		
		let dataOutput = AVCaptureVideoDataOutput()
		dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32)]
		
		// We don't want to process late frames.
		
		dataOutput.alwaysDiscardsLateVideoFrames = true
		
		// Add the output to the capture session.
		if (avCaptureSession?.canAddOutput(dataOutput) == true) {
			avCaptureSession?.addOutput(dataOutput)
		}
		
		// Dispatch the capture callbacks on the main thread, where OpenGL calls can be made synchronously.
		
		dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
		
		
		// Force the framerate to 30 FPS, to be in sync with Structure Sensor.
		do {
			try videoDevice!.lockForConfiguration()
	
			let _24FPSFrameDuration = CMTimeMake(1, 24)
			let _15FPSFrameDuration = CMTimeMake(1, 15)
			
			let activeFrameDuration = videoDevice!.activeVideoMinFrameDuration
			
			var targetFrameDuration = CMTimeMake(1, 30)
			
			// >0 if min duration > desired duration, in which case we need to increase our duration to the minimum
			// or else the camera will throw an exception.
			if 0 < CMTimeCompare(activeFrameDuration, targetFrameDuration)  {
				
				// In firmware <= 1.1, we can only support frame sync with 30 fps or 15 fps.
				if ((0 == CMTimeCompare(activeFrameDuration, _24FPSFrameDuration)) && doesStructureSensorSupport24FPS()) {
					targetFrameDuration = _24FPSFrameDuration
				}
				else {
					targetFrameDuration = _15FPSFrameDuration
				}
			}
			videoDevice!.activeVideoMaxFrameDuration = targetFrameDuration
			videoDevice!.activeVideoMinFrameDuration = targetFrameDuration
			videoDevice!.unlockForConfiguration()
		} catch {
			
		}
		
		avCaptureSession!.commitConfiguration()
	}

	func startColorCamera() {
//		if TARGET_IPHONE_SIMULATOR == 1 {
//			return
//		}

		if avCaptureSession != nil {
			if avCaptureSession!.isRunning {
				return
			}
		}

		if avCaptureSession == nil {
 
			self.setupColorCamera()
		}

		// Start streaming color images.
		avCaptureSession!.startRunning()
	}
	
	func stopColorCamera() {
		
		if avCaptureSession != nil {
			if avCaptureSession!.isRunning {
				
				// Stop the session
				avCaptureSession!.stopRunning()
			}
		}
		
		avCaptureSession = nil
		videoDevice = nil
	}
	
	func setColorCameraParametersForInit() {

		do {
			try videoDevice?.lockForConfiguration()
			
			// Auto-exposure
			if videoDevice != nil && (videoDevice?.isExposureModeSupported(.continuousAutoExposure))! {
				videoDevice?.exposureMode = .continuousAutoExposure
			}
			
			// Auto-white balance.
			if ((videoDevice?.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance)) != nil) {
				videoDevice?.whiteBalanceMode = .continuousAutoWhiteBalance
			}
			
			videoDevice?.unlockForConfiguration()
			
		} catch {
			
		}
	}
	
	func setColorCameraParametersForScanning() {
 
		do {
			try videoDevice?.lockForConfiguration()
			
			// Exposure locked to its current value.
			if ((videoDevice?.isExposureModeSupported(.locked)) != nil) {
				videoDevice?.exposureMode = .locked
			}
			
			// White balance locked to its current value.
			if ((videoDevice?.isWhiteBalanceModeSupported(.locked)) != nil) {
				videoDevice?.whiteBalanceMode = .locked
			}
			
			videoDevice?.unlockForConfiguration()
			
		} catch {
			
		}
	}
	
	@objc(captureOutput:didOutputSampleBuffer:fromConnection:) func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
		


		// Pass color buffers directly to the driver, which will then produce synchronized depth/color pairs.

        _sensorController.frameSyncNewColorBuffer(sampleBuffer)
	}

}

