//
//	This file is a Swift port of the Structure SDK sample app "Scanner".
//	Copyright © 2016 Occipital, Inc. All rights reserved.
//	http://structure.io
//
//  MeshViewController.swift
//
//  Ported by Christopher Worley on 8/20/16.
//

import MessageUI
import ImageIO
import SwiftyDropbox

protocol MeshViewDelegate: class {
    
    func meshViewWillDismiss()
    func meshViewDidDismiss()
    func meshViewDidRequestColorizing(_ mesh: STMesh,  previewCompletionHandler: @escaping () -> Void, enhancedCompletionHandler: @escaping () -> Void) -> Bool
	func meshViewDidRequestHoleFilling(_ mesh: STMesh,  previewCompletionHandler: @escaping () -> Void, enhancedCompletionHandler: @escaping () -> Void) -> Bool
}

open class MeshViewController: UIViewController, UIGestureRecognizerDelegate, MFMailComposeViewControllerDelegate {
	
    weak var delegate : MeshViewDelegate?

	// force the view to redraw.
    var needsDisplay: Bool = false
    var colorEnabled: Bool = false
	
	fileprivate var _mesh: STMesh? = nil
    var mesh: STMesh? {
        get {
            return _mesh
        }
        set {
            _mesh = newValue
            
            if _mesh != nil {
                
                self.renderer!.uploadMesh(_mesh!)
                self.trySwitchToColorRenderingMode()
                self.needsDisplay = true
            }
        }
    }
	
	fileprivate var _holeFilledMesh: STMesh? = nil
	var holeFilledMesh: STMesh? {
		get {
			return _holeFilledMesh
		}
		set {

			if _holeFilledMesh == nil && _holeFilledMesh != newValue {
				_holeFilledMesh = newValue
				
				mesh = _holeFilledMesh
			}
		}
	}

	var projectionMatrix: GLKMatrix4 = GLKMatrix4Identity
    {
		didSet {
			setCameraProjectionMatrix(projectionMatrix)
		}
	}
    
	var volumeCenter = GLKVector3Make(0,0,0)
    {
		didSet {
			resetMeshCenter(volumeCenter)
		}
	}
    
	@IBOutlet weak var eview: EAGLView!
	@IBOutlet weak var displayControl: UISegmentedControl!
	@IBOutlet weak var navigationTitle: UINavigationItem!
	@IBOutlet weak var navigationBar: UploadNavigationBar!
	@IBOutlet weak var dropboxButton: UIBarButtonItem!
	@IBOutlet weak var meshViewerMessageLabel: UILabel!
	
    var displayLink: CADisplayLink?
    var renderer: MeshRenderer!
    var viewpointController: ViewpointController!
    var viewport = [GLfloat](repeating: 0, count: 4)
    var modelViewMatrixBeforeUserInteractions: GLKMatrix4?
    var projectionMatrixBeforeUserInteractions: GLKMatrix4?
	
    var mailViewController: MFMailComposeViewController?
	
    required public init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

    }

    override open func viewDidLoad() {
		
        super.viewDidLoad()

        renderer = MeshRenderer.init()
        
		viewpointController = ViewpointController.init(screenSizeX: Float(self.view.frame.size.width), screenSizeY: Float(self.view.frame.size.height))
		
        let font = UIFont.boldSystemFont(ofSize: 14)
        let attributes: [AnyHashable: Any] = [NSFontAttributeName : font]
        
        displayControl.setTitleTextAttributes(attributes, for: UIControlState())
		
		renderer.setRenderingMode(.lightedGray)
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
		
        if displayLink != nil {
            displayLink!.invalidate()
            displayLink = nil
        }
        
        displayLink = CADisplayLink(target: self, selector: #selector(MeshViewController.draw))
        displayLink!.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
		
        viewpointController.reset()
		
        if !colorEnabled {
            displayControl.removeSegment(at: 2, animated: false)
        }
		
		if let _ = DropboxClientsManager.authorizedClient  {
			
			dropboxButton.isEnabled = true
		}
		else {
			// disable button if dropbox is not authorized
			dropboxButton.isEnabled = false
		}
    }
	
	// Make sure the status bar is disabled (iOS 7+)
	override open var prefersStatusBarHidden : Bool {
		return true
	}

    override open func didReceiveMemoryWarning () {
        
    }
    
    func setupGL (_ context: EAGLContext) {

        (self.view as! EAGLView).context = context

        EAGLContext.setCurrent(context)

        renderer.initializeGL( GLenum(GL_TEXTURE3))

        self.eview.setFramebuffer()
        
        let framebufferSize: CGSize = self.eview.getFramebufferSize()
		
		// The iPad's diplay conveniently has a 4:3 aspect ratio just like our video feed.
		// Some iOS devices need to render to only a portion of the screen so that we don't distort
		// our RGB image. Alternatively, you could enlarge the viewport (losing visual information),
		// but fill the whole screen.
		
		// if you want to keep aspect ratio
		//		var imageAspectRatio: CGFloat = 1
		//
		//        if abs(framebufferSize.width / framebufferSize.height - 640.0 / 480.0) > 1e-3 {
		//            imageAspectRatio = 480.0 / 640.0
		//        }
		//
		//        viewport[0] = Float(framebufferSize.width - framebufferSize.width * imageAspectRatio) / 2
		//        viewport[1] = 0
		//        viewport[2] = Float(framebufferSize.width * imageAspectRatio)
		//        viewport[3] = Float(framebufferSize.height)
		
		// if you want full screen
		viewport[0] = 0
		viewport[1] = 0
		viewport[2] = Float(framebufferSize.width)
		viewport[3] = Float(framebufferSize.height)
    }
    
	@IBAction func dismissView(_ sender: AnyObject) {

		holeFilledMesh = nil
		_holeFilledMesh = nil
		
		displayControl.selectedSegmentIndex = 1
		renderer.setRenderingMode(.lightedGray)
		
        if delegate?.meshViewWillDismiss != nil {
            delegate?.meshViewWillDismiss()
        }
		
        renderer.releaseGLBuffers()
        renderer.releaseGLTextures()
		
        displayLink!.invalidate()
        displayLink = nil
		
        mesh = nil

        self.eview.context = nil

		dismiss(animated: true, completion: {
			if self.delegate?.meshViewDidDismiss != nil {
				self.delegate?.meshViewDidDismiss()
			}
		})
    }
	
	//MARK: - MeshViewer setup when loading the mesh
    
    func setCameraProjectionMatrix (_ projection: GLKMatrix4) {

        viewpointController.setCameraProjection(projection)
        projectionMatrixBeforeUserInteractions = projection
    }
    
    func resetMeshCenter (_ center: GLKVector3) {

        viewpointController.reset()
        viewpointController.setMeshCenter(center)
        modelViewMatrixBeforeUserInteractions = viewpointController.currentGLModelViewMatrix()
    }
	
	func saveJpegFromRGBABuffer( _ filename: String, src_buffer: UnsafeMutableRawPointer, width: Int, height: Int)
	{
		let file: UnsafeMutablePointer<FILE>? = fopen(filename, "w")
		if file == nil {
			return
		}
        
		var colorSpace: CGColorSpace?
		var alphaInfo: CGImageAlphaInfo!
		var bmcontext: CGContext?
		colorSpace = CGColorSpaceCreateDeviceRGB()
		alphaInfo = .noneSkipLast

		bmcontext = CGContext(data: src_buffer, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace!, bitmapInfo: alphaInfo.rawValue)!
		var rgbImage: CGImage? = bmcontext!.makeImage()

		bmcontext = nil
		colorSpace = nil
		
		var jpgData: CFMutableData? = CFDataCreateMutable(nil, 0)
		var imageDest: CGImageDestination? = CGImageDestinationCreateWithData(jpgData!, "public.jpeg" as CFString, 1, nil)

		var kcb = kCFTypeDictionaryKeyCallBacks
		var vcb = kCFTypeDictionaryValueCallBacks
		
        // Our empty IOSurface properties dictionary
		var options: CFDictionary? = CFDictionaryCreate(kCFAllocatorDefault, nil, nil, 0, &kcb, &vcb)
		
		CGImageDestinationAddImage(imageDest!, rgbImage!, options!)
		CGImageDestinationFinalize(imageDest!)
		
		imageDest = nil
		rgbImage = nil
		options = nil

		fwrite(CFDataGetBytePtr(jpgData!), 1, CFDataGetLength(jpgData!), file!)
		fclose(file!)
		
		jpgData = nil
	}
	
    //MARK: Email Mesh OBJ File
	open func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
		mailViewController?.dismiss(animated: true, completion: nil)
	}

    func prepareScreenShotInitialViewpoint(_ screenshotPath: String) {
		
        let width: Int32 = 320
        let height: Int32 = 240
        var currentFrameBuffer: GLint = 0
		
        glGetIntegerv( GLenum(GL_FRAMEBUFFER_BINDING), &currentFrameBuffer)
		
        // Create temp texture, framebuffer, renderbuffer
        glViewport(0, 0, width, height)
		
        var outputTexture: GLuint = 0
        glActiveTexture( GLenum(GL_TEXTURE0))
        glGenTextures(1, &outputTexture)
        glBindTexture( GLenum(GL_TEXTURE_2D), outputTexture)
        glTexParameteri( GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        glTexParameteri( GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
        glTexParameteri( GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glTexParameteri( GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
        glTexImage2D( GLenum(GL_TEXTURE_2D), 0, GL_RGBA, width, height, 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), nil)
		
        var colorFrameBuffer: GLuint = 0
        var depthRenderBuffer: GLuint = 0

        glGenFramebuffers(1, &colorFrameBuffer)
        glBindFramebuffer( GLenum(GL_FRAMEBUFFER), colorFrameBuffer)
        glGenRenderbuffers(1, &depthRenderBuffer)
		glBindRenderbuffer( GLenum(GL_RENDERBUFFER), depthRenderBuffer)
		
        glRenderbufferStorage( GLenum(GL_RENDERBUFFER), GLenum(GL_DEPTH_COMPONENT16), width, height)
        glFramebufferRenderbuffer( GLenum(GL_FRAMEBUFFER), GLenum(GL_DEPTH_ATTACHMENT), GLenum(GL_RENDERBUFFER), depthRenderBuffer)
        glFramebufferTexture2D( GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_TEXTURE_2D), outputTexture, 0)
        
        // Keep the current render mode
        let previousRenderingMode: MeshRenderer.RenderingMode = renderer!.getRenderingMode()
		
        let meshToRender: STMesh = self.mesh!
        
        // Screenshot rendering mode, always use colors if possible.
        if meshToRender.hasPerVertexUVTextureCoords() && meshToRender.meshYCbCrTexture() != nil {
			
            renderer!.setRenderingMode(.textured)
			
        } else if meshToRender.hasPerVertexColors() {
			
			renderer!.setRenderingMode(.perVertexColor)
        
        } else {
            // meshToRender can be nil if there is no available color mesh.
			renderer!.setRenderingMode(.lightedGray)
        }
        
        // Render from the initial viewpoint for the screenshot.
        renderer!.clear()
		
		withUnsafePointer(to: &projectionMatrixBeforeUserInteractions) { (one) -> () in
			withUnsafePointer(to: &modelViewMatrixBeforeUserInteractions, { (two) -> () in
				
				one.withMemoryRebound(to: GLfloat.self, capacity: 16, { (onePtr) -> () in
					two.withMemoryRebound(to: GLfloat.self, capacity: 16, { (twoPtr) -> () in
						
						renderer!.render(onePtr,modelViewMatrix: twoPtr)
					})
				})
			})
		}

        // Back to current render mode
        renderer!.setRenderingMode(previousRenderingMode)
        
        var screenShotRgbaBuffer = [UInt32](repeating: 0, count: Int(width*height))

        var screenTopRowBuffer = [UInt32](repeating: 0, count: Int(width))
        
        var screenBottomRowBuffer = [UInt32](repeating: 0, count: Int(width))
        
        glReadPixels(0, 0, width, height, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), &screenShotRgbaBuffer)

        // flip the buffer
		for h in 0..<height/2 {
            
            glReadPixels(0, h, width, 1, UInt32(GL_RGBA), UInt32(GL_UNSIGNED_BYTE), &screenTopRowBuffer)
            
            glReadPixels(0, (height - h - 1), width, 1, UInt32(GL_RGBA), UInt32(GL_UNSIGNED_BYTE), &screenBottomRowBuffer)
            
            let topIdx = Int(width * h)
            let bottomIdx = Int(width * (height - h - 1))
			
			withUnsafePointer(to: &screenShotRgbaBuffer[topIdx]) { (one) -> () in
				withUnsafePointer(to: &screenBottomRowBuffer[0], { (two) -> () in
					
					one.withMemoryRebound(to: UInt32.self, capacity: Int(width), { (onePtr) -> () in
						two.withMemoryRebound(to: UInt32.self, capacity: Int(width), { (twoPtr) -> () in
							
							memcpy(onePtr, twoPtr, Int(width) * Int(MemoryLayout<UInt32>.size))
						})
					})
				})
			}
			
			withUnsafePointer(to: &screenShotRgbaBuffer[bottomIdx]) { (one) -> () in
				withUnsafePointer(to: &screenTopRowBuffer[0], { (two) -> () in
					
					one.withMemoryRebound(to: UInt32.self, capacity: Int(width), { (onePtr) -> () in
						two.withMemoryRebound(to: UInt32.self, capacity: Int(width), { (twoPtr) -> () in
							
							memcpy(onePtr, twoPtr, Int(width) * Int(MemoryLayout<UInt32>.size))
						})
					})
				})
			}
		}

		saveJpegFromRGBABuffer(screenshotPath, src_buffer: &screenShotRgbaBuffer, width: Int(width), height: Int(height))

        // Back to the original frame buffer
        glBindFramebuffer( GLenum(GL_FRAMEBUFFER), GLenum(currentFrameBuffer))
        glViewport( GLint(viewport[0]), GLint(viewport[1]), GLint(viewport[2]), GLint(viewport[3]))
		
        // Free the data
        glDeleteTextures(1, &outputTexture)
        glDeleteFramebuffers(1, &colorFrameBuffer)
        glDeleteRenderbuffers(1, &depthRenderBuffer)
    }
	
	// create preview image from current viewpoint
	
	func prepareScreenShotCurrentViewpoint (screenshotPath: String) {

		let framebufferSize: CGSize = self.eview.getFramebufferSize()
		let width: Int32 = Int32.init(framebufferSize.width)
		let height: Int32 = Int32.init(framebufferSize.height)

		var screenShotRgbaBuffer = [UInt32](repeating: 0, count: Int(width*height))
		
		var screenTopRowBuffer = [UInt32](repeating: 0, count: Int(width))
		
		var screenBottomRowBuffer = [UInt32](repeating: 0, count: Int(width))
		
		// tell glReadPixels to read from front buffer
		glReadBuffer(GLuint(GL_FRONT))
		glReadPixels(0, 0, width, height, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), &screenShotRgbaBuffer)
		
		// flip the buffer
		for h in 0..<height/2 {
			
			glReadPixels(0, h, width, 1, UInt32(GL_RGBA), UInt32(GL_UNSIGNED_BYTE), &screenTopRowBuffer)
			
			glReadPixels(0, (height - h - 1), width, 1, UInt32(GL_RGBA), UInt32(GL_UNSIGNED_BYTE), &screenBottomRowBuffer)
			
			let topIdx = Int(width * h)
			let bottomIdx = Int(width * (height - h - 1))
			
			withUnsafePointer(to: &screenShotRgbaBuffer[topIdx]) { (one) -> () in
				withUnsafePointer(to: &screenBottomRowBuffer[0], { (two) -> () in
					
					one.withMemoryRebound(to: UInt32.self, capacity: Int(width), { (onePtr) -> () in
						two.withMemoryRebound(to: UInt32.self, capacity: Int(width), { (twoPtr) -> () in
							
							memcpy(onePtr, twoPtr, Int(width) * Int(MemoryLayout<UInt32>.size))
						})
					})
				})
			}
			
			withUnsafePointer(to: &screenShotRgbaBuffer[bottomIdx]) { (one) -> () in
				withUnsafePointer(to: &screenTopRowBuffer[0], { (two) -> () in
					
					one.withMemoryRebound(to: UInt32.self, capacity: Int(width), { (onePtr) -> () in
						two.withMemoryRebound(to: UInt32.self, capacity: Int(width), { (twoPtr) -> () in
							
							memcpy(onePtr, twoPtr, Int(width) * Int(MemoryLayout<UInt32>.size))
						})
					})
				})
			}
		}

		
		saveJpegFromRGBABuffer(screenshotPath, src_buffer: &screenShotRgbaBuffer, width: Int(width), height: Int(height))

	}
	
	func resetTitle() {
		resetTitleTimer = nil
		navigationBar.titleTextAttributes = [NSForegroundColorAttributeName : UIColor.black]
		
		navigationTitle.title = "Structure Sensor Scanner"
	}
	
	var request0: UploadRequest<Files.FileMetadataSerializer, Files.UploadErrorSerializer>? = nil
	var request1: UploadRequest<Files.FileMetadataSerializer, Files.UploadErrorSerializer>? = nil
	var resetTitleTimer: Timer? = nil
	
	@IBAction func uploadDropBox(sender: AnyObject) {
		
		// Setup paths and filenames.
		
		if request0 != nil || request1 != nil {
			print("upload in progress")
			return
		}
		
		let zipFilename = "Model.zip"
		let screenshotFilename = "Preview.jpg"
		
		let fullPathFilename = FileMgr.sharedInstance.full(screenshotFilename)
  
		FileMgr.sharedInstance.del(screenshotFilename)
		
		// Take a screenshot and save it to disk.
		
		if let dropboxClient = DropboxClientsManager.authorizedClient {
			
			prepareScreenShotCurrentViewpoint(screenshotPath: fullPathFilename)
			
			navigationTitle.title = "Uploading to Dropbox..."

			navigationBar.titleTextAttributes = [NSForegroundColorAttributeName : UIColor.init(red: 0.275, green: 0.64, blue: 1, alpha: 1)]
			
			resetTitleTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(MeshViewController.resetTitle), userInfo: nil, repeats: false)
			
			if let sshot = NSData(contentsOfFile: fullPathFilename) {
				let screenshotFilename = "Preview.jpg"
				let pathname = "/" + screenshotFilename
				
				let data = sshot as Data

				navigationBar.progress0 = 0
				
				request0 = dropboxClient.files.upload(path: pathname, mode: Files.WriteMode.add, autorename: true, clientModified: nil, mute: false, input: data).response { response, error in
					if let response = response {
						print(response)
					} else if let error = error {
						print(error)
					}
				}
				.progress { progressData in
					print(progressData)
					self.navigationBar.progress0 = Float(progressData.fractionCompleted)
					if progressData.fractionCompleted > 0.95 {
						self.request0 = nil
					}
				}
			}
			
			
			if let meshToSend = mesh {
				let zipfile = FileMgr.sharedInstance.saveMesh(zipFilename, data: meshToSend)
				
				if zipfile != nil {
					
					let pathname = "/" + zipFilename

					request1 = dropboxClient.files.upload(path: pathname, mode: Files.WriteMode.add, autorename: true, clientModified: nil, mute: false, input: zipfile!).response { response, error in
						if let response = response {
							print(response)
						} else if let error = error {
							print(error)
						}
						}
						.progress { progressData in
							print(progressData)
							self.navigationBar.progress1 = Float(progressData.fractionCompleted)
							if progressData.fractionCompleted > 0.95 {
								self.request1 = nil
						}
					}
				}
			}
		}
	}

	@IBAction func emailMesh(_ sender: AnyObject) {
        
		mailViewController = MFMailComposeViewController.init()
		
		if mailViewController == nil {
			let alert = UIAlertController.init(title: "The email could not be sent.", message: "Please make sure an email account is properly setup on this device.", preferredStyle: .alert)

			let defaultAction = UIAlertAction.init(title: "OK", style: .default, handler: nil)
			
			alert.addAction(defaultAction)
	
			present(alert, animated: true, completion: nil)
			
			return
		}
		
		mailViewController!.mailComposeDelegate = self
		
		if UIDevice.current.userInterfaceIdiom == .pad {
			mailViewController!.modalPresentationStyle = .formSheet
		}
		
		// Setup paths and filenames.

		let zipFilename = "Model.zip"
		let screenshotFilename = "Preview.jpg"

		let fullPathFilename = FileMgr.sharedInstance.full(screenshotFilename)
  
		FileMgr.sharedInstance.del(screenshotFilename)
		
		// Take a screenshot and save it to disk.
		
		prepareScreenShotInitialViewpoint(fullPathFilename)		

		// since file is save in prepareScreenShot() need to getData() here
		
		if let sshot = try? Data(contentsOf: URL(fileURLWithPath: fullPathFilename)) {
		
			mailViewController?.addAttachmentData(sshot, mimeType: "image/jpeg", fileName: screenshotFilename)
		}
		else {
			let alert = UIAlertController.init(title: "Error", message: "no pic", preferredStyle: .alert)
			
			let defaultAction = UIAlertAction.init(title: "OK", style: .default, handler: nil)
			
			alert.addAction(defaultAction)
			
			present(alert, animated: true, completion: nil)
		}
		
		mailViewController!.setSubject("3D Model")
		
		let messageBody = "This model was captured with the open source Scanner sample app in the Structure SDK.\n\nCheck it out!\n\nMore info about the Structure SDK: http://structure.io/developers";
		
		mailViewController?.setMessageBody(messageBody, isHTML: false)

		if let meshToSend = mesh {
            let zipfile = FileMgr.sharedInstance.saveMesh(zipFilename, data: meshToSend)
            
            if zipfile != nil {
                mailViewController?.addAttachmentData(zipfile!, mimeType: "application/zip", fileName: zipFilename)
            }
        }
		else {

			mailViewController = nil
			
			let alert = UIAlertController.init(title: "The email could not be sent", message: "Exporting the mesh failed", preferredStyle: .alert)
			
			let defaultAction = UIAlertAction.init(title: "OK", style: .default, handler: nil)
			
			alert.addAction(defaultAction)
			
			present(alert, animated: true, completion: nil)
			
			return
		}

		present(mailViewController!, animated: true, completion: nil)
    }
	
    //MARK: Rendering
	
    func draw () {
        
        self.eview.setFramebuffer()
		
        glViewport(GLint(viewport[0]), GLint(viewport[1]), GLint(viewport[2]), GLint(viewport[3]))
		
        let viewpointChanged = viewpointController.update()
		
        // If nothing changed, do not waste time and resources rendering.
        if !needsDisplay && !viewpointChanged {
            return
        }
		
        var currentModelView = viewpointController.currentGLModelViewMatrix()
        var currentProjection = viewpointController.currentGLProjectionMatrix()
        
        renderer!.clear()
		
		withUnsafePointer(to: &currentProjection) { (one) -> () in
			withUnsafePointer(to: &currentModelView, { (two) -> () in
				
				one.withMemoryRebound(to: GLfloat.self, capacity: 16, { (onePtr) -> () in
					two.withMemoryRebound(to: GLfloat.self, capacity: 16, { (twoPtr) -> () in
						
						renderer!.render(onePtr,modelViewMatrix: twoPtr)
					})
				})
			})
		}
		
        needsDisplay = false
		
        let _ = self.eview.presentFramebuffer()

    }
	
    //MARK: Touch & Gesture Control
	
	@IBAction func tapStopGesture(_ sender: UITapGestureRecognizer) {

		if sender.state == .ended {
			// stop upload
			print("cancel upload")
			
			if request0 != nil {
				request0?.cancel()
				request0 = nil
				request1 = nil
			}
			
			if request1 != nil {
				request1?.cancel()
				request1 = nil
				request0 = nil
			}
			
			if resetTitleTimer != nil {
				resetTitleTimer?.invalidate()
			}

			navigationBar.titleTextAttributes = [NSForegroundColorAttributeName : UIColor.red]
			navigationTitle.title = "Upload canceled!!!"
			Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(MeshViewController.resetTitle), userInfo: nil, repeats: false)
			
			navigationBar.progress0 = 1.0
			navigationBar.progress1 = 1.0
		}
	}

    @IBAction func tapGesture(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            viewpointController.onTouchBegan()
        }
    }
	
	@IBAction func pinchScaleGesture(_ sender: UIPinchGestureRecognizer) {

        // Forward to the ViewpointController.
        if sender.state == .began {
            viewpointController.onPinchGestureBegan(Float(sender.scale))
        }
        else if sender.state == .changed {
            viewpointController.onPinchGestureChanged(Float(sender.scale))
        }
    }
    
	@IBAction func oneFingerPanGesture(_ sender: UIPanGestureRecognizer) {

        let touchPos = sender.location(in: view)
        let touchVel = sender.velocity(in: view)
        let touchPosVec = GLKVector2Make(Float(touchPos.x), Float(touchPos.y))
        let touchVelVec = GLKVector2Make(Float(touchVel.x), Float(touchVel.y))
		
        if sender.state == .began {
            viewpointController.onOneFingerPanBegan(touchPosVec)
        }
        else if sender.state == .changed {
            viewpointController.onOneFingerPanChanged(touchPosVec)
        }
        else if sender.state == .ended {
            viewpointController.onOneFingerPanEnded(touchVelVec)
        }
    }
	
	@IBAction func twoFingersPanGesture(_ sender: AnyObject) {

        if sender.numberOfTouches != 2 {
            return
        }
		
		let touchPos = sender.location(in: view)
		let touchVel = sender.velocity(in: view)
		let touchPosVec = GLKVector2Make(Float(touchPos.x), Float(touchPos.y))
		let touchVelVec = GLKVector2Make(Float(touchVel.x), Float(touchVel.y))
		
        if sender.state == .began {
            viewpointController.onTwoFingersPanBegan(touchPosVec)
        }
        else if sender.state == .changed {
            viewpointController.onTwoFingersPanChanged(touchPosVec)
        }
        else if sender.state == .ended {
            viewpointController.onTwoFingersPanEnded(touchVelVec)
        }
    }

    //MARK: UI Control
    
    func trySwitchToColorRenderingMode() {
   
        // Choose the best available color render mode, falling back to LightedGray
        // This method may be called when colorize operations complete, and will
        // switch the render mode to color, as long as the user has not changed
        // the selector.
		
        if displayControl.selectedSegmentIndex == 2 {
			
			if	mesh!.hasPerVertexUVTextureCoords() {
              
				renderer.setRenderingMode(.textured)
			}
			else if mesh!.hasPerVertexColors() {
             
				renderer.setRenderingMode(.perVertexColor)
			}
			else {
            
				renderer.setRenderingMode(.lightedGray)
			}
		}
		else if displayControl.selectedSegmentIndex == 3 {
			
			if	mesh!.hasPerVertexUVTextureCoords() {
				
				renderer.setRenderingMode(.textured)
			}
			else if mesh!.hasPerVertexColors() {
				
				renderer.setRenderingMode(.perVertexColor)
			}
			else {
				
				renderer.setRenderingMode(.lightedGray)
			}
		}
    }
	
    @IBAction func displayControlChanged(_ sender: AnyObject) {

        switch displayControl.selectedSegmentIndex {
		case 0: // x-ray
          
            renderer.setRenderingMode(.xRay)
			
		case 1: // lighted-gray
         
            renderer.setRenderingMode(.lightedGray)
			
        case 2: // color
            
            trySwitchToColorRenderingMode()
			
            let meshIsColorized: Bool = mesh!.hasPerVertexColors() || mesh!.hasPerVertexUVTextureCoords()
			
            if !meshIsColorized {
              
                colorizeMesh()
			}
			
		case 3: // hole fill
			
			trySwitchToColorRenderingMode()
			
			if holeFilledMesh == nil {
				fillMesh()
			}

			default:
				break
		}
		
		needsDisplay = true
	}
    
    func colorizeMesh() {
        
        let _ = delegate?.meshViewDidRequestColorizing(self.mesh!, previewCompletionHandler: {
            }, enhancedCompletionHandler: {
                
                // Hide progress bar.
                self.hideMeshViewerMessage()
        })
    }
	
	func fillMesh() {
		
		let _ = delegate?.meshViewDidRequestHoleFilling(self.mesh!, previewCompletionHandler: {
			}, enhancedCompletionHandler: {
				
				// Hide progress bar.
				self.hideMeshViewerMessage()
		})
	}
	
    func hideMeshViewerMessage() {
		
        UIView.animate(withDuration: 0.5, animations: {
            self.meshViewerMessageLabel.alpha = 0.0
            }, completion: { _ in
                self.meshViewerMessageLabel.isHidden = true
        })
    }
    
    func showMeshViewerMessage(_ msg: String) {
        
        meshViewerMessageLabel.text = msg
        
        if meshViewerMessageLabel.isHidden == true {
            
            meshViewerMessageLabel.alpha = 0.0
            meshViewerMessageLabel.isHidden = false
            
            UIView.animate(withDuration: 0.5, animations: {
                self.meshViewerMessageLabel.alpha = 1.0
            })
        }
    }
}

