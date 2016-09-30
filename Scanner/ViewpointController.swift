//
//	This file is a Swift port of the Structure SDK sample app "Scanner".
//	Copyright © 2016 Occipital, Inc. All rights reserved.
//	http://structure.io
//
//  ViewpointController.swift
//
//  Ported by Christopher Worley on 8/20/16.
//


func nowInSeconds() -> Double {

	var timebase = mach_timebase_info_data_t()
	mach_timebase_info(&timebase)

	let newTime: UInt64 = mach_absolute_time()

	return (Double(newTime) * Double(timebase.numer))/(Double(timebase.denom) * 1e9)
}

class ViewpointController : NSObject {

	var d: PrivateData?

	struct PrivateData {

		// Projection matrix before starting user interaction.
		var referenceProjectionMatrix: GLKMatrix4

		// Centroid of the mesh.
		var meshCenter: GLKVector3

		// Scale management
		var scaleWhenPinchGestureBegan: Float
		var currentScale: Float

		// ModelView rotation.
		var lastModelViewRotationUpdateTimestamp: Double
		var oneFingerPanWhenGestureBegan: GLKVector2
		var modelViewRotationWhenPanGestureBegan: GLKMatrix4
		var modelViewRotation: GLKMatrix4
		var modelViewRotationVelocity: GLKVector2 // expressed in terms of touch coordinates.

		// Rotation speed will slow down with time.
		var velocitiesDampingRatio: GLKVector2

		// Translation in screen space.
		var twoFingersPanWhenGestureBegan: GLKVector2
		var meshCenterOnScreenWhenPanGestureBegan: GLKVector2
		var meshCenterOnScreen: GLKVector2

		var screenCenter: GLKVector2
		var screenSize: GLKVector2

		var cameraOrProjectionChangedSinceLastUpdate: Bool

		internal init(screenSizeX: Float, screenSizeY: Float) {

            screenSize = GLKVector2Make(screenSizeX, screenSizeY)
			cameraOrProjectionChangedSinceLastUpdate = false
			scaleWhenPinchGestureBegan = 1.0
			currentScale = 1.0
            screenCenter = GLKVector2MultiplyScalar(screenSize, 0.5)
            meshCenterOnScreen = GLKVector2MultiplyScalar(screenSize, 0.5)
			modelViewRotationWhenPanGestureBegan = GLKMatrix4Identity
			modelViewRotation = GLKMatrix4Identity
			velocitiesDampingRatio = GLKVector2Make(0.95, 0.95)
			modelViewRotationVelocity = GLKVector2Make(0, 0)
			
			referenceProjectionMatrix = GLKMatrix4Identity
			lastModelViewRotationUpdateTimestamp = 0
			oneFingerPanWhenGestureBegan = GLKVector2Make(0, 0)
			meshCenterOnScreenWhenPanGestureBegan = GLKVector2Make(0, 0)
			twoFingersPanWhenGestureBegan = GLKVector2Make(0, 0)
            meshCenter = GLKVector3Make(0, 0, 0)
		}
	}

    override init() {
        super.init()
    }
    
	convenience init(screenSizeX: Float, screenSizeY: Float) {
        self.init()
		self.d = PrivateData.init(screenSizeX: screenSizeX, screenSizeY: screenSizeY)
		self.reset()
	}

	deinit {
		
		self.d = nil
	}

	func reset() {
		
		d!.cameraOrProjectionChangedSinceLastUpdate = false
		d!.scaleWhenPinchGestureBegan = 1
		d!.currentScale = 1
		d!.screenCenter = GLKVector2MultiplyScalar(d!.screenSize, 0.5)
		d!.meshCenterOnScreen = GLKVector2MultiplyScalar(d!.screenSize, 0.5)
		d!.modelViewRotationWhenPanGestureBegan = GLKMatrix4Identity
		d!.modelViewRotation = GLKMatrix4Identity
		d!.velocitiesDampingRatio = GLKVector2Make(0.99, 0.99)
		d!.modelViewRotationVelocity = GLKVector2Make(0, 0)
	}
	
    func setCameraProjection(_ projRt: GLKMatrix4) {

        d!.referenceProjectionMatrix = projRt
        d!.cameraOrProjectionChangedSinceLastUpdate = true
    }

    func setMeshCenter(_ center: GLKVector3) {

        d!.meshCenter = center
        d!.cameraOrProjectionChangedSinceLastUpdate = true
    }

    // Scale Gesture Control
   internal func onPinchGestureBegan(_ scale: Float) {

        d!.scaleWhenPinchGestureBegan = d!.currentScale / scale
    }

   internal func onPinchGestureChanged(_ scale: Float) {

        d!.currentScale = scale * d!.scaleWhenPinchGestureBegan
        d!.cameraOrProjectionChangedSinceLastUpdate = true
    }

    // 3D modelView rotation gesture control.
   internal func onOneFingerPanBegan(_ touch: GLKVector2) {

        d!.modelViewRotationWhenPanGestureBegan = d!.modelViewRotation
        d!.oneFingerPanWhenGestureBegan = touch
    }

   internal func onOneFingerPanChanged(_ touch: GLKVector2) {

        let distMoved = GLKVector2Subtract(touch, d!.oneFingerPanWhenGestureBegan)
        let spinDegree = GLKVector2Negate(GLKVector2DivideScalar(distMoved, 300))

        let rotX = GLKMatrix4MakeYRotation(spinDegree.x)
        let rotY = GLKMatrix4MakeXRotation(-spinDegree.y)

        d!.modelViewRotation = GLKMatrix4Multiply(GLKMatrix4Multiply(rotX, rotY), d!.modelViewRotationWhenPanGestureBegan)
        d!.cameraOrProjectionChangedSinceLastUpdate = true
    }

    internal func onOneFingerPanEnded(_ vel: GLKVector2) {

        d!.modelViewRotationVelocity = vel
        d!.lastModelViewRotationUpdateTimestamp = nowInSeconds()
    }

    // Screen-space translation gesture control.
    internal func onTwoFingersPanBegan (_ touch: GLKVector2) {

        d!.twoFingersPanWhenGestureBegan = touch
        d!.meshCenterOnScreenWhenPanGestureBegan = d!.meshCenterOnScreen
    }

    internal func onTwoFingersPanChanged (_ touch: GLKVector2) {
        
        d!.meshCenterOnScreen = GLKVector2Add(GLKVector2Subtract(touch, d!.twoFingersPanWhenGestureBegan), d!.meshCenterOnScreenWhenPanGestureBegan)
        d!.cameraOrProjectionChangedSinceLastUpdate = true
    }
    
    internal func onTwoFingersPanEnded(_ vel: GLKVector2) {
    }
    
    internal func onTouchBegan() {
        
        // Stop the current animations when the user touches the screen.
        d!.modelViewRotationVelocity = GLKVector2Make(0, 0)
    }

    // ModelView matrix in OpenGL space.

    internal func currentGLModelViewMatrix() -> GLKMatrix4 {

        let meshCenterToOrigin = GLKMatrix4MakeTranslation(-d!.meshCenter.x, -d!.meshCenter.y, -d!.meshCenter.z)

        // We'll put the object at some distance.
        let originToVirtualViewpoint = GLKMatrix4MakeTranslation(0, 0, 4 * d!.meshCenter.z)

        var modelView = originToVirtualViewpoint
        modelView = GLKMatrix4Multiply(modelView, d!.modelViewRotation)

        // will apply the rotation around the mesh center.
        modelView = GLKMatrix4Multiply(modelView, meshCenterToOrigin)
        return modelView
    }

    // Projection matrix in OpenGL space.
	
    internal func currentGLProjectionMatrix() -> GLKMatrix4 {
		
        // The scale is directly applied to the reference projection matrix.
        let scale = GLKMatrix4MakeScale(d!.currentScale, d!.currentScale, 1)

        // Since the translation is done in screen space, it's also applied to the projection matrix directly.
        let centerTranslation: GLKMatrix4 = currentProjectionCenterTranslation()

        return GLKMatrix4Multiply(centerTranslation, GLKMatrix4Multiply(scale, d!.referenceProjectionMatrix))
    }

    // Returns true if the current viewpoint changed.
   internal func update() -> Bool {

        var viewpointChanged = d!.cameraOrProjectionChangedSinceLastUpdate

        // Modelview rotation animation.
        if GLKVector2Length(d!.modelViewRotationVelocity) > 1e-5 {

            let nowSec = nowInSeconds()
            let elapsedSec = nowSec - d!.lastModelViewRotationUpdateTimestamp
            d!.lastModelViewRotationUpdateTimestamp = nowSec

            let distMoved = GLKVector2MultiplyScalar(d!.modelViewRotationVelocity, Float(elapsedSec))
            let spinDegree = GLKVector2Negate(GLKVector2DivideScalar(distMoved, 300))

            let rotX = GLKMatrix4MakeYRotation(spinDegree.x)
            let rotY = GLKMatrix4MakeXRotation(-spinDegree.y)
            d!.modelViewRotation = GLKMatrix4Multiply(GLKMatrix4Multiply(rotX, rotY), d!.modelViewRotation)

            // Slow down the velocities.
            let resX = d!.modelViewRotationVelocity.x * d!.velocitiesDampingRatio.x
            let resY = d!.modelViewRotationVelocity.y * d!.velocitiesDampingRatio.y
			
			d!.modelViewRotationVelocity = GLKVector2Make(resX, resY)

            // Make sure we stop animating and taking resources when it became too small.
            if abs(d!.modelViewRotationVelocity.x) < 1 {
				d!.modelViewRotationVelocity = GLKVector2Make(0, d!.modelViewRotationVelocity.y)
            }

            if abs(d!.modelViewRotationVelocity.y) < 1 {
				d!.modelViewRotationVelocity = GLKVector2Make(d!.modelViewRotationVelocity.x, 0)
            }

            viewpointChanged = true
        }

        d!.cameraOrProjectionChangedSinceLastUpdate = false

        return viewpointChanged
    }

    internal func currentProjectionCenterTranslation() -> GLKMatrix4 {
        let deltaFromScreenCenter = GLKVector2Subtract(d!.screenCenter, d!.meshCenterOnScreen)

        return GLKMatrix4MakeTranslation(-deltaFromScreenCenter.x / d!.screenCenter.x, deltaFromScreenCenter.y / d!.screenCenter.y, 0)
    }
}


