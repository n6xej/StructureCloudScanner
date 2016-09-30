//
//	This file is a Swift port of the Structure SDK sample app "Scanner".
//	Copyright © 2016 Occipital, Inc. All rights reserved.
//	http://structure.io
//
//  ViewController.swift
//
//  Ported by Christopher Worley on 8/20/16.
//

import Foundation
import UIKit
import SwiftyDropbox

struct DynamicOptions {
	var newTrackerIsOn = true
	var newTrackerSwitchEnabled = true

	var highResColoring = false
	var highResColoringSwitchEnabled = false

	var newMapperIsOn = true
	var newMapperSwitchEnabled = true

	var highResMapping = true
	var highResMappingSwitchEnabled = true
}

// Volume resolution in meters

struct Options {
	// The initial scanning volume size will be 0.5 x 0.5 x 0.5 meters
	// (X is left-right, Y is up-down, Z is forward-back)
	var initVolumeSizeInMeters: GLKVector3 = GLKVector3Make(0.5, 0.5, 0.5)

	// The maximum number of keyframes saved in keyFrameManager
	var maxNumKeyFrames: Int = 48

	// Colorizer quality
	var colorizerQuality: STColorizerQuality = STColorizerQuality.highQuality

	// Take a new keyframe in the rotation difference is higher than 20 degrees.
	var maxKeyFrameRotation: CGFloat = CGFloat(20 * (M_PI / 180)) // 20 degrees

	// Take a new keyframe if the translation difference is higher than 30 cm.
	var maxKeyFrameTranslation: CGFloat = 0.3 // 30cm

	// Threshold to consider that the rotation motion was small enough for a frame to be accepted
	// as a keyframe. This avoids capturing keyframes with strong motion blur / rolling shutter.
	var maxKeyframeRotationSpeedInDegreesPerSecond: CGFloat = 1

	// Whether we should use depth aligned to the color viewpoint when Structure Sensor was calibrated.
	// This setting may get overwritten to false if no color camera can be used.
	var useHardwareRegisteredDepth: Bool = false

	// Whether to enable an expensive per-frame depth accuracy refinement.
	// Note: this option requires useHardwareRegisteredDepth to be set to false.
	var applyExpensiveCorrectionToDepth: Bool = true

	// Whether the colorizer should try harder to preserve appearance of the first keyframe.
	// Recommended for face scans.
	var prioritizeFirstFrameColor: Bool = true

	// Target number of faces of the final textured mesh.
	var colorizerTargetNumFaces: Int = 30000

	// Focus position for the color camera (between 0 and 1). Must remain fixed one depth streaming
	// has started when using hardware registered depth.
	let lensPosition: CGFloat = 0.75
}

enum ScannerState: Int {

	case cubePlacement = 0	// Defining the volume to scan
	case scanning			// Scanning
	case viewing			// Visualizing the mesh
}

// SLAM-related members.
struct SlamData {

	var initialized = false
	var showingMemoryWarning = false

	var prevFrameTimeStamp: TimeInterval = -1

	var scene: STScene? = nil
	var tracker: STTracker? = nil
	var mapper: STMapper? = nil
	var cameraPoseInitializer: STCameraPoseInitializer? = nil
	var initialDepthCameraPose: GLKMatrix4 = GLKMatrix4Identity
	var keyFrameManager: STKeyFrameManager? = nil
	var scannerState: ScannerState = .cubePlacement

	var volumeSizeInMeters = GLKVector3Make(Float.nan, Float.nan, Float.nan)
}

// Utility struct to manage a gesture-based scale.
struct PinchScaleState {

	var currentScale: CGFloat = 1
	var initialPinchScale: CGFloat = 1
}

func keepInRange(_ value: Float, minValue: Float, maxValue: Float) -> Float {
	if value.isNaN {
		return minValue
	}
	if value > maxValue {
		return maxValue
	}
	if value < minValue {
		return minValue
	}
	return value
}

struct AppStatus {
	let pleaseConnectSensorMessage = "Please connect Structure Sensor."
	let pleaseChargeSensorMessage = "Please charge Structure Sensor."
	let needColorCameraAccessMessage = "This app requires camera access to capture color.\nAllow access by going to Settings → Privacy → Camera."

	enum SensorStatus {
		case ok
		case needsUserToConnect
		case needsUserToCharge
	}

	// Structure Sensor status.
	var sensorStatus: SensorStatus = .ok

	// Whether iOS camera access was granted by the user.
	var colorCameraIsAuthorized = true

	// Whether there is currently a message to show.
	var needsDisplayOfStatusMessage = false

	// Flag to disable entirely status message display.
	var statusMessageDisabled = false
}

// Display related members.
struct DisplayData {

	// OpenGL context.
	var context: EAGLContext? = nil

	// OpenGL Texture reference for y images.
	var lumaTexture: CVOpenGLESTexture? = nil

	// OpenGL Texture reference for color images.
	var chromaTexture: CVOpenGLESTexture? = nil

	// OpenGL Texture cache for the color camera.
	var videoTextureCache: CVOpenGLESTextureCache? = nil

	// Shader to render a GL texture as a simple quad.
	var yCbCrTextureShader: STGLTextureShaderYCbCr? = nil
	var rgbaTextureShader: STGLTextureShaderRGBA? = nil

	var depthAsRgbaTexture: GLuint = 0

	// Renders the volume boundaries as a cube.
	var cubeRenderer: STCubeRenderer? = nil

	// OpenGL viewport.
	var viewport: [GLfloat] = [0, 0, 0, 0]

	// OpenGL projection matrix for the color camera.
	var colorCameraGLProjectionMatrix: GLKMatrix4 = GLKMatrix4Identity

	// OpenGL projection matrix for the depth camera.
	var depthCameraGLProjectionMatrix: GLKMatrix4 = GLKMatrix4Identity

	// Mesh rendering alpha
	var meshRenderingAlpha: Float = 0.8
}

class ViewController: UIViewController, STBackgroundTaskDelegate, MeshViewDelegate, UIGestureRecognizerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
	

    @IBOutlet weak var eview: EAGLView!

	@IBOutlet weak var enableNewTrackerSwitch: UISwitch!
	@IBOutlet weak var enableHighResolutionColorSwitch: UISwitch!
	@IBOutlet weak var enableNewMapperSwitch: UISwitch!
	@IBOutlet weak var enableHighResMappingSwitch: UISwitch!
	@IBOutlet weak var dropboxButtonLabel: UIButton!
	@IBOutlet weak var appStatusMessageLabel: UILabel!
	@IBOutlet weak var scanButton: UIButton!
	@IBOutlet weak var resetButton: UIButton!
	@IBOutlet weak var doneButton: UIButton!
	@IBOutlet weak var trackingLostLabel: UILabel!
	@IBOutlet weak var enableNewTrackerView: UIView!
    @IBOutlet weak var instructionOverlay: UIView!
    @IBOutlet weak var calibrationOverlay: UIView!

	// Structure Sensor controller.
	var _sensorController: STSensorController!
	var _structureStreamConfig: STStreamConfig!

	var _slamState = SlamData.init()

	var _options = Options.init()

	var _dynamicOptions: DynamicOptions!

	// Manages the app status messages.
	var _appStatus = AppStatus.init()

	var _display: DisplayData? = DisplayData()

	// Most recent gravity vector from IMU.
	var _lastGravity: GLKVector3!

	// Scale of the scanning volume.
	var _volumeScale = PinchScaleState()

	// Mesh viewer controllers.
	var meshViewController: MeshViewController!

	// IMU handling.
	var _motionManager: CMMotionManager? = nil
	var _imuQueue: OperationQueue? = nil

//	var _holeFilledMesh: STMesh? = nil
	var _naiveColorizeTask: STBackgroundTask? = nil
	var _enhancedColorizeTask: STBackgroundTask? = nil
	var _holeFillingTask: STBackgroundTask? = nil
	var _depthAsRgbaVisualizer: STDepthToRgba? = nil

	var _useColorCamera = true
    var trackerShowingScanStart = false

	var avCaptureSession: AVCaptureSession? = nil
	var videoDevice: AVCaptureDevice? = nil

	var UNLINKDROPBOX = "Unlink from Dropbox"
	var LINKTODROPBOX = "Link to Dropbox"
	
	deinit {
		avCaptureSession!.stopRunning()
		if EAGLContext.current() == _display!.context {
			EAGLContext.setCurrent(nil)
		}
		unregisterNotificationHandlers()
	}
	
	public func updateDropboxLinkStatus() {
		if let _ = DropboxClientsManager.authorizedClient {
			dropboxButtonLabel.setTitle(UNLINKDROPBOX, for: UIControlState.normal)
		}
		else {
			dropboxButtonLabel.setTitle(LINKTODROPBOX, for: UIControlState.normal)
		}
	}
	
	func unregisterNotificationHandlers() {
		
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)

		NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "DropboxLinkStatusNotification"), object: nil)
	}

	func registerNotificationHandlers() {
	
		// Make sure we get notified when the app becomes active to start/restore the sensor state if necessary.
		NotificationCenter.default.addObserver(self, selector: #selector(ViewController.appDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(updateDropboxLinkStatus), name: NSNotification.Name(rawValue: "DropboxLinkStatusNotification"), object: nil)
	}
	
	@available(iOS 10.0, *)
	func isAuthorizeDropbox() {
		let client = DropboxClientsManager.authorizedClient
 
		if client == nil {
			
			DropboxClientsManager.authorizeFromController(UIApplication.shared, controller: self, openURL: { (url: URL) -> Void in
				UIApplication.shared.open(url)
			})
		}
	}
	
	func isAuthorizeDropbox9() {
		let client = DropboxClientsManager.authorizedClient
		
		if client == nil {
			
			DropboxClientsManager.authorizeFromController(UIApplication.shared, controller: self, openURL: { (url: URL) -> Void in
				UIApplication.shared.openURL(url)
			})
		}
	}

    override func viewDidLoad() {
        super.viewDidLoad()

        // initially hide tracker view
		enableNewTrackerView.isHidden = true
		enableNewTrackerView.alpha = 0.0

        calibrationOverlay.alpha = 0
        calibrationOverlay.isHidden = true

        instructionOverlay.alpha = 0
        instructionOverlay.isHidden = true

        // Do any additional setup after loading the view.
        _slamState.initialized = false
        _enhancedColorizeTask = nil
        _naiveColorizeTask = nil

		setupGL()

		setupUserInterface()

        setupMeshViewController()

		setupStructureSensor()

		setupIMU()

		// Later, we’ll set this true if we have a device-specific calibration
		_useColorCamera = STSensorController.approximateCalibrationGuaranteedForDevice()

		registerNotificationHandlers()
		

		initializeDynamicOptions()
		syncUIfromDynamicOptions()
    }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		// The framebuffer will only be really ready with its final size after the view appears.
		self.eview.setFramebuffer()

		setupGLViewport()

		updateAppStatusMessage()

        let defaults = UserDefaults.standard

         if !defaults.bool(forKey: "instructionOverlay") {

            let _ = Timer.schedule(10.0, handler: {_ in
                self.instructionOverlay.isHidden = false
                self.instructionOverlay.alpha = 1
                let _ = Timer.schedule(15.0, handler: { _ in
                    UIView.animate(withDuration: 0.3, animations: {

                        self.instructionOverlay!.alpha = 0
                        self.instructionOverlay!.isHidden = true
                    })
                })
            })
        }

		// We will connect to the sensor when we receive appDidBecomeActive.
	}

    var hasLaunched = false

	func appDidBecomeActive() {

		if currentStateNeedsSensor() {
			let _ = connectToStructureSensorAndStartStreaming()
		}

		// Abort the current scan if we were still scanning before going into background since we
		// are not likely to recover well.
		if _slamState.scannerState == .scanning {
			resetButtonPressed(resetButton)
		}
		
		updateDropboxLinkStatus()
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		respondToMemoryWarning()
	}

	func initializeDynamicOptions() {

		_dynamicOptions = DynamicOptions()
		_dynamicOptions.highResColoring = videoDeviceSupportsHighResColor()
		_dynamicOptions.highResColoringSwitchEnabled = _dynamicOptions.highResColoring
	}

	func syncUIfromDynamicOptions() {

		// This method ensures the UI reflects the dynamic settings.
		enableNewTrackerSwitch.isOn = _dynamicOptions.newTrackerIsOn
		enableNewTrackerSwitch.isEnabled = _dynamicOptions.newTrackerSwitchEnabled

		enableHighResMappingSwitch.isOn = _dynamicOptions.highResMapping
		enableHighResMappingSwitch.isEnabled = _dynamicOptions.highResMappingSwitchEnabled

		enableNewMapperSwitch.isOn = _dynamicOptions.newMapperIsOn
		enableNewMapperSwitch.isEnabled = _dynamicOptions.newMapperSwitchEnabled

		enableHighResolutionColorSwitch.isOn = _dynamicOptions.highResColoring
		enableHighResolutionColorSwitch.isEnabled = _dynamicOptions.highResColoringSwitchEnabled

	}

	func setupUserInterface() {

		// File management extentions
        FileMgr.sharedInstance.useSubpath("scannerCache")

		// Fully transparent message label, initially.
		appStatusMessageLabel.alpha = 0

		// Make sure the label is on top of everything else.
		appStatusMessageLabel.layer.zPosition = 100
	}

	// Make sure the status bar is disabled (iOS 7+)
	override var prefersStatusBarHidden : Bool {
		return true
	}

	func setupMeshViewController() {
		// The mesh viewer will be used after scanning.
		if UIDevice.current.userInterfaceIdiom == .phone {
			meshViewController = UIStoryboard(name: "Main_iPhone", bundle: nil).instantiateViewController(withIdentifier: "MeshViewController") as! MeshViewController
		} else {
			meshViewController = UIStoryboard(name: "Main_iPad", bundle: nil).instantiateViewController(withIdentifier: "MeshViewController") as! MeshViewController
		}
	}

	func presentMeshViewer(_ mesh: STMesh) {

		meshViewController.setupGL(_display!.context!)
		meshViewController.colorEnabled = _useColorCamera
		meshViewController.mesh = mesh
		meshViewController.setCameraProjectionMatrix(_display!.depthCameraGLProjectionMatrix)

		// Sample a few points to estimate the volume center
		var totalNumVertices: Int32 = 0

		for  i in 0..<mesh.numberOfMeshes() {
			totalNumVertices += mesh.number(ofMeshVertices: Int32(i))
		}

		let sampleStep = Int(max(1, totalNumVertices / 1000))
		var sampleCount: Int32 = 0
		var volumeCenter = GLKVector3Make(0, 0,0)

		for i in 0..<mesh.numberOfMeshes() {
			let numVertices = Int(mesh.number(ofMeshVertices: i))
			let vertex = mesh.meshVertices(Int32(i))

			for j in stride(from: 0, to: numVertices, by: sampleStep) {
				volumeCenter = GLKVector3Add(volumeCenter, (vertex?[Int(j)])!)
				sampleCount += 1
			}
		}

		if sampleCount > 0 {
			volumeCenter = GLKVector3DivideScalar(volumeCenter, Float(sampleCount))
		} else {
			volumeCenter = GLKVector3MultiplyScalar(_slamState.volumeSizeInMeters, 0.5)
		}

		meshViewController.resetMeshCenter(volumeCenter)
        meshViewController.delegate = self
		present(meshViewController!, animated: true, completion: nil)
	}

	func enterCubePlacementState() {

		// Switch to the Scan button.
		scanButton.isHidden = false
		doneButton.isHidden = true
		resetButton.isHidden = true

		// We'll enable the button only after we get some initial pose.
		scanButton.isHidden = false

		// Cannot be lost in cube placement mode.
		trackingLostLabel.isHidden = true

		setColorCameraParametersForInit()

		_slamState.scannerState = .cubePlacement

		// Restore dynamic options UI state, as we may be coming back from scanning state, where they were all disabled.
		syncUIfromDynamicOptions()

		updateIdleTimer()
	}

	func enterScanningState() {

		// This can happen if the UI did not get updated quickly enough.
		if !_slamState.cameraPoseInitializer!.hasValidPose {
			print("Warning: not accepting to enter into scanning state since the initial pose is not valid.")
			return
		}

		// Switch to the Done button.
		scanButton.isHidden = true
		doneButton.isHidden = false
		resetButton.isHidden = false

		// Prepare the mapper for the new scan.
		setupMapper()

        _slamState.tracker!.initialCameraPose = _slamState.cameraPoseInitializer!.cameraPose

		// We will lock exposure during scanning to ensure better coloring.
		setColorCameraParametersForScanning()

		_slamState.scannerState = .scanning

		// Temporarily disable options while we're scanning.
		enableNewTrackerSwitch.isEnabled = false
		enableHighResolutionColorSwitch.isEnabled = false
		enableNewMapperSwitch.isEnabled = false
		enableHighResMappingSwitch.isEnabled = false

	}

	func enterViewingState() {

		// Cannot be lost in view mode.
		hideTrackingErrorMessage()

		_appStatus.statusMessageDisabled = true
		updateAppStatusMessage()

		// Hide the Scan/Done/Reset button.
		scanButton.isHidden = true
		doneButton.isHidden = true
		resetButton.isHidden = true

		_sensorController.stopStreaming()

		if _useColorCamera {
			stopColorCamera()
		}

		_slamState.mapper!.finalizeTriangleMesh()

		let mesh = _slamState.scene!.lockAndGetMesh()

		presentMeshViewer(mesh!)

		_slamState.scene!.unlockMesh()

		_slamState.scannerState = .viewing

		updateIdleTimer()
	}

	//MARK: -  Structure Sensor Management

	func currentStateNeedsSensor() -> Bool {

		switch _slamState.scannerState {

		// Initialization and scanning need the sensor.
		case .cubePlacement, .scanning:
			return true

		// Other states don't need the sensor.
		default:
			return false
		}
	}

	//MARK: - IMU

	func setupIMU() {

		_lastGravity = GLKVector3.init(v: (0, 0, 0))

		// 60 FPS is responsive enough for motion events.
		let fps: Double = 60
		_motionManager = CMMotionManager.init()
		_motionManager!.accelerometerUpdateInterval = 1.0 / fps
		_motionManager!.gyroUpdateInterval = 1.0 / fps

		// Limiting the concurrent ops to 1 is a simple way to force serial execution
		_imuQueue = OperationQueue.init()
		_imuQueue!.maxConcurrentOperationCount = 1

		let dmHandler: CMDeviceMotionHandler = { motion, _ in
			// Could be nil if the self is released before the callback happens.
			if self.view != nil {
				self.processDeviceMotion(motion!, error: nil)
			}
		}
		_motionManager!.startDeviceMotionUpdates(to: _imuQueue!, withHandler: dmHandler)
	}

	func processDeviceMotion(_ motion: CMDeviceMotion, error: NSError?) {

		if _slamState.scannerState == .cubePlacement {

			// Update our gravity vector, it will be used by the cube placement initializer.
			_lastGravity = GLKVector3Make(Float(motion.gravity.x), Float(motion.gravity.y), Float(motion.gravity.z))
		}

		if _slamState.scannerState == .cubePlacement || _slamState.scannerState == .scanning {

			if _slamState.tracker != nil {
				// The tracker is more robust to fast moves if we feed it with motion data.
				_slamState.tracker!.updateCameraPose(with: motion)
			}
		}
	}

	@IBAction func unlinkFromDropbox(_ sender: AnyObject) {

		if let _ = DropboxClientsManager.authorizedClient {
			DropboxClientsManager.unlinkClients()
			updateDropboxLinkStatus()
		}
		else {
			if #available(iOS 10.0, *) {
				isAuthorizeDropbox()
			} else {
				// Fallback on earlier versions
				isAuthorizeDropbox9()
			}
		}
	}
	
	//MARK: - UI Callbacks

    @IBAction func calibrationButtonClicked(_ button: UIButton) {

        STSensorController.launchCalibratorAppOrGoToAppStore()
    }

    @IBAction func instructionButtonClicked(_ button: UIButton) {

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "instructionOverlay")

        instructionOverlay.isHidden = true
    }

	@IBAction func newTrackerSwitchChanged(_ sender: UISwitch) {


		_dynamicOptions.newTrackerIsOn = enableNewTrackerSwitch.isOn

		onSLAMOptionsChanged()
	}

	@IBAction func highResolutionColorSwitchChanged(_ sender: UISwitch) {

		_dynamicOptions.highResColoring = self.enableHighResolutionColorSwitch.isOn

		if (avCaptureSession != nil) {

			stopColorCamera()

			// The dynamic option must be updated before the camera is restarted.
			_dynamicOptions.highResColoring = self.enableHighResolutionColorSwitch.isOn

			if _useColorCamera {
				startColorCamera()
			}
		}

		// Force a scan reset since we cannot changing the image resolution during the scan is not
		// supported by STColorizer.
		onSLAMOptionsChanged() // will call UI sync
	}


	@IBAction func newMapperSwitchChanged(_ sender: UISwitch) {

		_dynamicOptions.newMapperIsOn = self.enableNewMapperSwitch.isOn
		onSLAMOptionsChanged() // will call UI sync
	}

	@IBAction func highResMappingSwitchChanged(_ sender: UISwitch) {

		_dynamicOptions.highResMapping = self.enableHighResMappingSwitch.isOn
		onSLAMOptionsChanged() // will call UI sync
	}

	func onSLAMOptionsChanged() {

		syncUIfromDynamicOptions()

		// A full reset to force a creation of a new tracker.

		resetSLAM()
		clearSLAM()
		setupSLAM()

		// Restore the volume size cleared by the full reset.
		adjustVolumeSize( volumeSize: _slamState.volumeSizeInMeters)
	}

	func adjustVolumeSize(volumeSize: GLKVector3) {

		// Make sure the volume size remains between 10 centimeters and 3 meters.
		let x = keepInRange(volumeSize.x, minValue: 0.1, maxValue: 3)
		let y = keepInRange(volumeSize.y, minValue: 0.1, maxValue: 3)
		let z = keepInRange(volumeSize.z, minValue: 0.1, maxValue: 3)

		_slamState.volumeSizeInMeters = GLKVector3.init(v: (x, y, z))

		_slamState.cameraPoseInitializer!.volumeSizeInMeters = _slamState.volumeSizeInMeters
		_display!.cubeRenderer!.adjustCubeSize(_slamState.volumeSizeInMeters)
	}

	@IBAction func scanButtonPressed(_ sender: UIButton) {
        // hide windows while scanning
        trackerShowingScanStart =  !enableNewTrackerView.isHidden

        toggleTracker(false)
        enterScanningState()
	}

	@IBAction func resetButtonPressed(_ sender: UIButton) {
        // restore window after scanning
        if trackerShowingScanStart {
            toggleTracker(true)
        }

		resetSLAM()
	}

	@IBAction func doneButtonPressed(_ sender: UIButton) {
        // restore window after scanning
        if trackerShowingScanStart {
            toggleTracker(true)
        }

		enterViewingState()
	}

	// Manages whether we can let the application sleep.
	func updateIdleTimer() {
		if isStructureConnectedAndCharged() && currentStateNeedsSensor() {

			// Do not let the application sleep if we are currently using the sensor data.
			UIApplication.shared.isIdleTimerDisabled = true
		} else {
			// Let the application sleep if we are only viewing the mesh or if no sensors are connected.
			UIApplication.shared.isIdleTimerDisabled = false
		}
	}

	func showTrackingMessage(_ message: String) {

		trackingLostLabel.text = message
		trackingLostLabel.isHidden = false
	}

	func hideTrackingErrorMessage() {

		trackingLostLabel.isHidden = true
	}

	func showAppStatusMessage(_ msg: String) {

		_appStatus.needsDisplayOfStatusMessage = true
		view.layer.removeAllAnimations()

		appStatusMessageLabel.text = msg
		appStatusMessageLabel.isHidden = false

		// Progressively show the message label.
		view!.isUserInteractionEnabled = false
		UIView.animate(withDuration: 0.5, animations: {
			self.appStatusMessageLabel.alpha = 1.0
		})
	}

	func hideAppStatusMessage() {

		if !_appStatus.needsDisplayOfStatusMessage {
			return
		}

		_appStatus.needsDisplayOfStatusMessage = false
		view.layer.removeAllAnimations()

		UIView.animate(withDuration: 0.5, animations: {
			self.appStatusMessageLabel.alpha = 0
			}, completion: { _ in
				// If nobody called showAppStatusMessage before the end of the animation, do not hide it.
				if !self._appStatus.needsDisplayOfStatusMessage {

					// Could be nil if the self is released before the callback happens.
					if self.view != nil {
						self.appStatusMessageLabel.isHidden = true
						self.view.isUserInteractionEnabled = true
					}
				}
		})
	}

	func updateAppStatusMessage() {

		// Skip everything if we should not show app status messages (e.g. in viewing state).
		if _appStatus.statusMessageDisabled {
			hideAppStatusMessage()
			return
		}
		// First show sensor issues, if any.
		switch _appStatus.sensorStatus {

		case .needsUserToConnect:
			showAppStatusMessage(_appStatus.pleaseConnectSensorMessage)
			return

		case .needsUserToCharge:
			showAppStatusMessage(_appStatus.pleaseChargeSensorMessage)
			return

		case .ok:
			break
		}

		// Then show color camera permission issues, if any.
		if !_appStatus.colorCameraIsAuthorized {
			showAppStatusMessage(_appStatus.needColorCameraAccessMessage)
			return
		}

		// If we reach this point, no status to show.
		hideAppStatusMessage()
	}

	@IBAction func pinchGesture(_ sender: UIPinchGestureRecognizer) {

		if sender.state == .began {
			if _slamState.scannerState == .cubePlacement {
				_volumeScale.initialPinchScale = _volumeScale.currentScale / sender.scale
			}
		} else if sender.state == .changed {

			if _slamState.scannerState == .cubePlacement {

				// In some special conditions the gesture recognizer can send a zero initial scale.
				if !_volumeScale.initialPinchScale.isNaN {

					_volumeScale.currentScale = sender.scale * _volumeScale.initialPinchScale

					// Don't let our scale multiplier become absurd
					_volumeScale.currentScale = CGFloat(keepInRange(Float(_volumeScale.currentScale), minValue: 0.01, maxValue: 1000))

					let newVolumeSize: GLKVector3 = GLKVector3MultiplyScalar(_options.initVolumeSizeInMeters, Float(_volumeScale.currentScale))

					adjustVolumeSize( volumeSize: newVolumeSize)
				}
			}
		}
	}

    @IBAction func toggleNewTrackerVisible(_ sender: UILongPressGestureRecognizer) {

        if (sender.state == .began) {

            toggleTracker(enableNewTrackerView.isHidden)
        }
    }

    func toggleTracker(_ show: Bool) {

        if show {
            // set alpha to 0.9
            enableNewTrackerView.alpha = 0
            enableNewTrackerView.isHidden = false
            UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseOut, animations: { () -> Void in
                self.enableNewTrackerView.alpha = 0.9
                }, completion: { (finished: Bool) -> Void in
                    self.enableNewTrackerView.isHidden = false
            })
        } else {
            // set alpha to 0.0
            UIView.animate(withDuration: 1.0, delay: 0.0, options: .curveEaseOut, animations: { () -> Void in
                self.enableNewTrackerView.alpha = 0.0

                }, completion: { (finished: Bool) -> Void in
                    self.enableNewTrackerView.isHidden = true
            })
        }
    }

	//MARK: - MeshViewController delegates

	func meshViewWillDismiss() {

		// If we are running colorize work, we should cancel it.
		if _naiveColorizeTask != nil {
			_naiveColorizeTask!.cancel()
			_naiveColorizeTask = nil
		}

		if _enhancedColorizeTask != nil {
			_enhancedColorizeTask!.cancel()
			_enhancedColorizeTask = nil
		}
		
		if _holeFillingTask != nil {
			_holeFillingTask!.cancel()
			_holeFillingTask = nil
		}

		self.meshViewController.hideMeshViewerMessage()
	}

	func meshViewDidDismiss() {

		_appStatus.statusMessageDisabled = false
		updateAppStatusMessage()

		let _ = connectToStructureSensorAndStartStreaming()
		
		resetSLAM()
	}

    func backgroundTask(_ sender: STBackgroundTask!, didUpdateProgress progress: Double) {

		if sender == _naiveColorizeTask {
            DispatchQueue.main.async(execute: {
				self.meshViewController.showMeshViewerMessage(String.init(format: "Processing: % 3d%%", Int(progress*20)))
            })
		} else if sender == _enhancedColorizeTask {

            DispatchQueue.main.async(execute: {
            self.meshViewController.showMeshViewerMessage(String.init(format: "Processing: % 3d%%", Int(progress*80)+20))
            })
		} else if sender == _holeFillingTask {
			
			DispatchQueue.main.async(execute: {
				self.meshViewController.showMeshViewerMessage(String.init(format: "Hole filling: % 3d%%", Int(progress*80)+20))
			})
		}
	}
	
	func meshViewDidRequestColorizing(_ mesh: STMesh, previewCompletionHandler: @escaping () -> Void, enhancedCompletionHandler: @escaping () -> Void) -> Bool {

		if _holeFillingTask != nil || _naiveColorizeTask != nil || _enhancedColorizeTask != nil { // already one running?
			
			NSLog("Already running background task!")
			return false
		}

		_naiveColorizeTask = try! STColorizer.newColorizeTask(with: mesh,
		                   scene: _slamState.scene,
		                   keyframes: _slamState.keyFrameManager!.getKeyFrames(),
		                   completionHandler: { error in
							if error != nil {
                                print("Error during colorizing: \(error?.localizedDescription)")
                            } else {
                                DispatchQueue.main.async(execute: {
                                    previewCompletionHandler()
                                    self.meshViewController.mesh = mesh

									self.performEnhancedColorize(mesh, enhancedCompletionHandler:enhancedCompletionHandler)
                                    })
                                    self._naiveColorizeTask = nil
                                }
			},
		                   options: [kSTColorizerTypeKey : STColorizerType.perVertex.rawValue,
            kSTColorizerPrioritizeFirstFrameColorKey: _options.prioritizeFirstFrameColor]
		)

		if _naiveColorizeTask != nil {
			// Release the tracking and mapping resources. It will not be possible to resume a scan after this point
//			_slamState.mapper!.reset()
//			_slamState.tracker!.reset()

			_naiveColorizeTask!.delegate = self
			_naiveColorizeTask!.start()

			return true
		}

		return false
	}

	func performEnhancedColorize(_ mesh: STMesh, enhancedCompletionHandler: @escaping () -> Void) {

        _enhancedColorizeTask = try! STColorizer.newColorizeTask(with: mesh, scene: _slamState.scene, keyframes: _slamState.keyFrameManager!.getKeyFrames(), completionHandler: {error in
            if error != nil {
                NSLog("Error during colorizing: %@", error!.localizedDescription)
            } else {
                DispatchQueue.main.async(execute: {
                    enhancedCompletionHandler()

					self.meshViewController.mesh = mesh
                })

                self._enhancedColorizeTask = nil
            }
            }, options: [kSTColorizerTypeKey : STColorizerType.textureMapForObject.rawValue, kSTColorizerPrioritizeFirstFrameColorKey: _options.prioritizeFirstFrameColor, kSTColorizerQualityKey: _options.colorizerQuality.rawValue, kSTColorizerTargetNumberOfFacesKey: _options.colorizerTargetNumFaces])

		if _enhancedColorizeTask != nil {

			// We don't need the keyframes anymore now that the final colorizing task was started.
			// Clearing it now gives a chance to early release the keyframe memory when the colorizer
			// stops needing them.
//            _slamState.keyFrameManager!.clear()

			_enhancedColorizeTask!.delegate = self
			_enhancedColorizeTask!.start()
		}
	}

	func meshViewDidRequestHoleFilling(_ mesh: STMesh, previewCompletionHandler: @escaping () -> Void, enhancedCompletionHandler: @escaping () -> Void) -> Bool {
		
		if _holeFillingTask != nil || _naiveColorizeTask != nil || _enhancedColorizeTask != nil { // already one running?
			
			NSLog("Already running background task!")
			return false
		}

		_holeFillingTask = STMesh.newFillHolesTask(with: mesh, completionHandler: { result, error in
						if error != nil {
						NSLog("Error during hole filling: \(error?.localizedDescription)")
						} else {
								DispatchQueue.main.async(execute: {
									previewCompletionHandler()
								
									let meshIsColorized: Bool = result!.hasPerVertexColors() || result!.hasPerVertexUVTextureCoords()
									if !meshIsColorized {
										// colorize the mesh
										let _ = self.meshViewDidRequestColorizing(result!, previewCompletionHandler: previewCompletionHandler, enhancedCompletionHandler:enhancedCompletionHandler)
									}
									else {
										self.meshViewController.holeFilledMesh = result!
										// close progress window
										enhancedCompletionHandler()
									}

								})
						}
				self._holeFillingTask = nil
			})
		
		if _holeFillingTask != nil {
			
			_holeFillingTask!.delegate = self
			_holeFillingTask!.start()
			
			return true
		}
		
		return false
	}
	
	func respondToMemoryWarning() {
		NSLog("respondToMemoryWarning")
		switch _slamState.scannerState {
		case .viewing:
			// If we are running a colorizing task, abort it
			if _enhancedColorizeTask != nil && !_slamState.showingMemoryWarning {

				_slamState.showingMemoryWarning = true

				// stop the task
				_enhancedColorizeTask!.cancel()
				_enhancedColorizeTask = nil

				// hide progress bar
				self.meshViewController.hideMeshViewerMessage()

				let alertCtrl = UIAlertController(
					title: "Memory Low",
					message: "Colorizing was canceled.",
					preferredStyle: .alert)

				let okAction = UIAlertAction(
					title: "OK",
					style: .default,
					handler: { _ in
						self._slamState.showingMemoryWarning = false
				})

				alertCtrl.addAction(okAction)

				// show the alert in the meshViewController
				self.meshViewController.present(alertCtrl, animated: true, completion: nil)
			}

		case .scanning:

			if !_slamState.showingMemoryWarning {

				_slamState.showingMemoryWarning = true

				let alertCtrl = UIAlertController(
					title: "Memory Low",
					message: "Scanning will be stopped to avoid loss.",
					preferredStyle: .alert)

				let okAction = UIAlertAction(
					title: "OK", style: .default,
					handler: { _ in
						self._slamState.showingMemoryWarning = false
						self.enterViewingState()
				})

				alertCtrl.addAction(okAction)

				// show the alert
				present(alertCtrl, animated: true, completion: nil)
			}

		default:
			// not much we can do here
			break
		}
	}

}
