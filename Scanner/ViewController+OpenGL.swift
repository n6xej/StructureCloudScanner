//
//	This file is a Swift port of the Structure SDK sample app "Scanner".
//	Copyright © 2016 Occipital, Inc. All rights reserved.
//	http://structure.io
//
//  ViewController+OpenGL.swift
//
//  Ported by Christopher Worley on 8/20/16.
//



extension ViewController {
	
    func setupGL() {
		
        // Create an EAGLContext for our EAGLView.
		_display?.context = EAGLContext.init(api: .openGLES2)
		
		if _display!.context == nil {
			NSLog("Failed to create ES context")
			return
		}

        self.eview.context = _display!.context!

        self.eview.setFramebuffer()
		
        self._display!.yCbCrTextureShader = STGLTextureShaderYCbCr.init()
        self._display!.rgbaTextureShader = STGLTextureShaderRGBA.init()
		
        // Set up texture and textureCache for images output by the color camera.
        let texError: CVReturn = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, _display!.context!, nil, &_display!.videoTextureCache)
        if texError != 0 { 
            NSLog("Error at CVOpenGLESTextureCacheCreate %d", texError)
        }
		
        glGenTextures(1, &_display!.depthAsRgbaTexture)
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), _display!.depthAsRgbaTexture)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
    }
    
    func setupGLViewport() {
		
        let frameBufferSize: CGSize = self.eview.getFramebufferSize()
                // The iPad's diplay conveniently has a 4:3 aspect ratio just like our video feed.
        // Some iOS devices need to render to only a portion of the screen so that we don't distort
        // our RGB image. Alternatively, you could enlarge the viewport (losing visual information),
        // but fill the whole screen.
		
		//
//		var imageAspectRatio: Float = 1.0
//		let vgaAspectRatio: Float = 640 / 480
//		let framebufferAspectRatio: Float = Float(frameBufferSize.width) / Float(frameBufferSize.height)
//		
//
//        if !framebufferAspectRatio.nearlyEqual(vgaAspectRatio) {
//            imageAspectRatio = 480.0 / 640.0
//        }
//		
//        self._display!.viewport[0] = 0
//        self._display!.viewport[1] = 0
//        self._display!.viewport[2] = Float(frameBufferSize.width) * imageAspectRatio
//        self._display!.viewport[3] = Float(frameBufferSize.height)
		
		self._display!.viewport[0] = 0
		self._display!.viewport[1] = 0
		self._display!.viewport[2] = Float(frameBufferSize.width)
		self._display!.viewport[3] = Float(frameBufferSize.height)
    }
    
    func uploadGLColorTexture(colorFrame: STColorFrame) {
        
        var colorFrame = colorFrame
		
        if _display!.videoTextureCache == nil {
            NSLog("Cannot upload color texture: No texture cache is present.")
            return
        }
		
        // Clear the previous color texture.
        if _display!.lumaTexture != nil {
            self._display!.lumaTexture = nil
        }
		
        // Clear the previous color texture
        if _display!.chromaTexture != nil {
            self._display!.chromaTexture = nil
        }
		
        // Displaying image with width over 1280 is an overkill. Downsample it to save bandwidth.
        while colorFrame.width > 2560 {
            colorFrame = colorFrame.halfResolution
        }
		
        var err: CVReturn
		
        // Allow the texture cache to do internal cleanup.
        CVOpenGLESTextureCacheFlush(_display!.videoTextureCache!, 0)
		
        let pixelBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(colorFrame.sampleBuffer)!
        let width: size_t = CVPixelBufferGetWidth(pixelBuffer)
        let height: size_t = CVPixelBufferGetHeight(pixelBuffer)
		
        let pixelFormat: OSType = CVPixelBufferGetPixelFormatType(pixelBuffer)
        assert(pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, "YCbCr is expected!")
		
        // Activate the default texture unit.
		glActiveTexture( GLenum(GL_TEXTURE0))
		
        // Create an new Y texture from the video texture cache.
        err = CVOpenGLESTextureCacheCreateTextureFromImage(
								kCFAllocatorDefault,
								_display!.videoTextureCache!,
								pixelBuffer,
								nil,
								GLenum(GL_TEXTURE_2D),
								GLint(GL_RED_EXT),
								GLsizei(width),
								GLsizei(height),
								GLenum(GL_RED_EXT),
								GLenum(GL_UNSIGNED_BYTE),
								0,
								&_display!.lumaTexture)
		
        if err != kCVReturnSuccess {
            NSLog("Error with CVOpenGLESTextureCacheCreateTextureFromImage: %d", err)
            return
        }
		
        // Set good rendering properties for the new texture.
        glBindTexture(CVOpenGLESTextureGetTarget(_display!.lumaTexture!), CVOpenGLESTextureGetName(_display!.lumaTexture!))
        glTexParameterf( GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf( GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
		
        // Activate the default texture unit.
        glActiveTexture( GLenum(GL_TEXTURE1))
		
        // Create an new CbCr texture from the video texture cache.
        err = CVOpenGLESTextureCacheCreateTextureFromImage(
									kCFAllocatorDefault,
									_display!.videoTextureCache!,
									pixelBuffer,
									nil,
									GLenum(GL_TEXTURE_2D),
									GLint(GL_RG_EXT),
									GLsizei(width / 2),
									GLsizei(height / 2),
									GLenum(GL_RG_EXT),
									GLenum(GL_UNSIGNED_BYTE),
									1,
									&_display!.chromaTexture)
		
        if err != kCVReturnSuccess {
			
            NSLog("Error with CVOpenGLESTextureCacheCreateTextureFromImage: %d", err)
            return
        }
		
        // Set rendering properties for the new texture.
        glBindTexture(CVOpenGLESTextureGetTarget(_display!.chromaTexture!), CVOpenGLESTextureGetName(_display!.chromaTexture!))
        glTexParameterf( GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf( GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
    }
    
    func uploadGLColorTextureFromDepth(_ depthFrame: STDepthFrame) {
		
        _depthAsRgbaVisualizer!.convertDepthFrame(toRgba: depthFrame)
        glActiveTexture( GLenum(GL_TEXTURE0))
        glBindTexture( GLenum(GL_TEXTURE_2D), _display!.depthAsRgbaTexture)
		
        glTexImage2D( GLenum(GL_TEXTURE_2D), 0, GL_RGBA, _depthAsRgbaVisualizer!.width, _depthAsRgbaVisualizer!.height, 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), _depthAsRgbaVisualizer!.rgbaBuffer)
    }
    
    func renderSceneForDepthFrame(_ depthFrame: STDepthFrame, colorFrame: STColorFrame?) {
		
        // Activate our view framebuffer.
        self.eview.setFramebuffer()
		
        // this changes the background color for the scanning window
		glClearColor(0.0, 0.0, 0.0, 1.0)
        //glClearColor(1.0, 1.0, 1.0, 1.0)
		//glClearColor(0.7, 1.0, 1.0, 1.0)
        glClear( GLbitfield(GL_COLOR_BUFFER_BIT))
        glClear( GLbitfield(GL_DEPTH_BUFFER_BIT))
		
        glViewport(GLint(_display!.viewport[0]), GLint(_display!.viewport[1]), GLint(_display!.viewport[2]), GLint(_display!.viewport[3]))
		
        switch _slamState.scannerState {
			
        case .cubePlacement:
			
            // Render the background image from the color camera.
            renderCameraImage()
			
            if _slamState.cameraPoseInitializer!.hasValidPose {

                let depthCameraPose: GLKMatrix4 = _slamState.cameraPoseInitializer!.cameraPose
				
                var cameraViewpoint: GLKMatrix4
                var alpha: Float
                if _useColorCamera {
					
                    // Make sure the viewpoint is always to color camera one, even if not using registered depth.
					
                    var colorCameraPoseInStreamCoordinateSpace = GLKMatrix4.init()
					
					withUnsafeMutablePointer(to: &colorCameraPoseInStreamCoordinateSpace, {
						$0.withMemoryRebound(to: Float.self, capacity: 16, {
							depthFrame.colorCameraPose(inDepthCoordinateFrame: $0)
						})
					})
  
                    cameraViewpoint = GLKMatrix4Multiply(depthCameraPose, colorCameraPoseInStreamCoordinateSpace)
                    alpha = 0.5
                }
                else {
                    cameraViewpoint = depthCameraPose
                    alpha = 1.0
                }
				
                // Highlighted depth values inside the current volume area.
                _display!.cubeRenderer!.renderHighlightedDepth(withCameraPose: cameraViewpoint, alpha: alpha)
				
                // Render the wireframe cube corresponding to the current scanning volume.
                _display!.cubeRenderer!.renderCubeOutline(withCameraPose: cameraViewpoint, depthTestEnabled: false, occlusionTestEnabled: true)
            }
            
        case .scanning:
			
            // Enable GL blending to show the mesh with some transparency.
            glEnable( GLenum(GL_BLEND))
			
            // Render the background image from the color camera.
            renderCameraImage()
			
            // Render the current mesh reconstruction using the last estimated camera pose.
			
            let depthCameraPose = _slamState.tracker!.lastFrameCameraPose()
			
            var cameraGLProjection: GLKMatrix4
            if _useColorCamera {
                cameraGLProjection = colorFrame!.glProjectionMatrix()
            }
            else {
                cameraGLProjection = depthFrame.glProjectionMatrix()
            }
			
            var cameraViewpoint: GLKMatrix4
            if _useColorCamera && !_options.useHardwareRegisteredDepth {
                // If we want to use the color camera viewpoint, and are not using registered depth, then
                // we need to deduce the color camera pose from the depth camera pose.
				
				var colorCameraPoseInDepthCoordinateSpace = GLKMatrix4.init()
				
				withUnsafeMutablePointer(to: &colorCameraPoseInDepthCoordinateSpace, {
					$0.withMemoryRebound(to: Float.self, capacity: 16, {
						depthFrame.colorCameraPose(inDepthCoordinateFrame: $0)
						
					})
				})
				
                // colorCameraPoseInWorld
                cameraViewpoint = GLKMatrix4Multiply(depthCameraPose, colorCameraPoseInDepthCoordinateSpace)
            }
            else {
                cameraViewpoint = depthCameraPose
            }
			
            _slamState.scene!.renderMesh(
										fromViewpoint: cameraViewpoint,
										cameraGLProjection: cameraGLProjection,
										alpha: _display!.meshRenderingAlpha,
										highlightOutOfRangeDepth: true,
										wireframe: false)
			
            glDisable( GLenum(GL_BLEND))
			
            // Render the wireframe cube corresponding to the scanning volume.
            // Here we don't enable occlusions to avoid performance hit.
            _display!.cubeRenderer!.renderCubeOutline (
									withCameraPose: cameraViewpoint,
									depthTestEnabled: true,
									occlusionTestEnabled: false)
            
        // MeshViewerController handles this.
        default:
            break
        }
        
        // Check for OpenGL errors
        let err: GLenum = glGetError()
        if err != GLenum(GL_NO_ERROR) {
            NSLog("glError = %x", err)
        }
		
        // Display the rendered framebuffer.
        let ret = self.eview.presentFramebuffer()
		
		if !ret {
			NSLog("glError")
		}
    }
    
    func renderCameraImage() {
		
        if _useColorCamera {
            if _display!.lumaTexture == nil || _display!.chromaTexture == nil {
                return
            }
            glActiveTexture(GLenum(GL_TEXTURE0))
            glBindTexture(CVOpenGLESTextureGetTarget(_display!.lumaTexture!), CVOpenGLESTextureGetName(_display!.lumaTexture!))
			
            glActiveTexture(GLenum(GL_TEXTURE1))
            glBindTexture(CVOpenGLESTextureGetTarget(_display!.chromaTexture!), CVOpenGLESTextureGetName(_display!.chromaTexture!))
			
            glDisable(GLenum(GL_BLEND))
            _display!.yCbCrTextureShader!.useShaderProgram()
            _display!.yCbCrTextureShader!.render(withLumaTexture: GL_TEXTURE0, chromaTexture: GL_TEXTURE1)
        }
        else {
			
            if _display!.depthAsRgbaTexture == 0 {
                return
            }
			
            glActiveTexture(GLenum(GL_TEXTURE0))
            glBindTexture(GLenum(GL_TEXTURE_2D), _display!.depthAsRgbaTexture)
            _display!.rgbaTextureShader!.useShaderProgram()
            _display!.rgbaTextureShader!.renderTexture(GL_TEXTURE0)
        }
        glUseProgram(0)
    }
}
