//
//	This file is a Swift port of the Structure SDK sample app "Scanner".
//	Copyright © 2016 Occipital, Inc. All rights reserved.
//	http://structure.io
//
//  EAGLView.swift
//
//  Ported by Christopher Worley on 8/20/16.
//


// This class wraps the CAEAGLLayer from CoreAnimation into a convenient UIView subclass.
// The view content is basically an EAGL surface you render your OpenGL scene into.
// Note that setting the view non-opaque will only work if the EAGL surface has an alpha channel.

class EAGLView: UIView {
	
	fileprivate var _context: EAGLContext? = nil
	var context: EAGLContext? {
		get {
			return _context
		}
		set {
            
			if _context != newValue  {
				self.deleteFramebuffer()
				
				_context = newValue
				
				EAGLContext.setCurrent(nil)
			}
		}
	}
    
    // The pixel dimensions of the CAEAGLLayer.
    var framebufferWidth: GLint = 0
    var framebufferHeight: GLint = 0
	
    // The OpenGL ES names for the framebuffer and renderbuffer used to render to this view.
    var defaultFramebuffer: GLuint = 0
    var colorRenderbuffer: GLuint = 0
    var depthRenderbuffer: GLuint = 0
	
	@inline(__always) func eaglLayer() -> CAEAGLLayer { return self.layer as! CAEAGLLayer }
	
	override  class var layerClass : AnyClass {
		return CAEAGLLayer.self
	}

	//The EAGL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:.
	required  init(coder: NSCoder) {
		super.init(coder: coder)!
		
		let eagllayer = eaglLayer()
		
		eagllayer.isOpaque = true
		eagllayer.drawableProperties = [kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8, kEAGLDrawablePropertyRetainedBacking : true]
		
		self.contentScaleFactor = 1.0
	}
	
	deinit {
		self.deleteFramebuffer()
	}
	
	func createFramebuffer() {
		
		if context != nil && defaultFramebuffer == 0 {

			EAGLContext.setCurrent(context)
			
			// Create default framebuffer object.
			glGenFramebuffers(1, &defaultFramebuffer)
			glBindFramebuffer( GLenum(GL_FRAMEBUFFER), defaultFramebuffer)
			
			// Create color render buffer and allocate backing store.
			glGenRenderbuffers(1, &colorRenderbuffer)
			glBindRenderbuffer( GLenum(GL_RENDERBUFFER), colorRenderbuffer)
			
			context!.renderbufferStorage( GLintptr(GL_RENDERBUFFER), from: eaglLayer())
			glGetRenderbufferParameteriv( GLenum(GL_RENDERBUFFER), GLenum(GL_RENDERBUFFER_WIDTH), &framebufferWidth)
			glGetRenderbufferParameteriv( GLenum(GL_RENDERBUFFER), GLenum(GL_RENDERBUFFER_HEIGHT), &framebufferHeight)
			
			glGenRenderbuffers(1, &depthRenderbuffer)
			glBindRenderbuffer( GLenum(GL_RENDERBUFFER), depthRenderbuffer)
			glRenderbufferStorage( GLenum(GL_RENDERBUFFER), GLenum(GL_DEPTH_COMPONENT16), framebufferWidth, framebufferHeight)
			glFramebufferRenderbuffer( GLenum(GL_FRAMEBUFFER), GLenum(GL_DEPTH_ATTACHMENT), GLenum(GL_RENDERBUFFER), depthRenderbuffer)
			
			glBindRenderbuffer( GLenum(GL_RENDERBUFFER), colorRenderbuffer)
			
			glFramebufferRenderbuffer( GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_RENDERBUFFER), colorRenderbuffer)
			
			if glCheckFramebufferStatus( GLenum(GL_FRAMEBUFFER)) != GLenum(GL_FRAMEBUFFER_COMPLETE) {
				NSLog("Failed to make complete framebuffer object \(glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)))")
			}
		}
	}
	
	 func deleteFramebuffer() {
		
		if context != nil {
            
			EAGLContext.setCurrent(context)
			
			if defaultFramebuffer != 0 {
				
				glDeleteFramebuffers(1, &defaultFramebuffer)
				defaultFramebuffer = 0
			}
			
			if depthRenderbuffer != 0 {
				
				glDeleteRenderbuffers(1, &depthRenderbuffer)
				depthRenderbuffer = 0
			}
			
			if colorRenderbuffer != 0 {
				
				glDeleteRenderbuffers(1, &colorRenderbuffer)
				colorRenderbuffer = 0
			}
		}
	}

 func setFramebuffer() {
		
        if context != nil {
			
            EAGLContext.setCurrent(context)
			
            if defaultFramebuffer == 0 {
                self.createFramebuffer()
            }
			
            glBindFramebuffer( GLenum(GL_FRAMEBUFFER), defaultFramebuffer)
			
            glViewport(0, 0, framebufferWidth, framebufferHeight)
        }
    }
    
    func presentFramebuffer() -> Bool {
        
        var success = false
        
        // iOS may crash if presentRenderbuffer is called when the application is in background.
        if context != nil && UIApplication.shared.applicationState != .background {
            
            EAGLContext.setCurrent(context)
            
            glBindRenderbuffer(GLenum(GL_RENDERBUFFER), colorRenderbuffer)
            
            success = context!.presentRenderbuffer(GLintptr(GL_RENDERBUFFER))
        }
        
        return success
    }
	
	override func layoutSubviews() {
		super.layoutSubviews()
		
		// CAREFUL!!!! If you have autolayout enabled, you will re-create your framebuffer all the time if
		// your EAGLView has any subviews that are updated. For example, having a UILabel that is updated
		// to display FPS will result in layoutSubviews being called every frame. Two ways around this:
		// 1) don't use autolayout
		// 2) don't add any subviews to the EAGLView. Have the EAGLView be a subview of another "master" view.
		
		// The framebuffer will be re-created at the beginning of the next setFramebuffer method call.
		self.deleteFramebuffer()
	}

    func getFramebufferSize() -> CGSize {
        return CGSize(width: CGFloat(framebufferWidth), height: CGFloat(framebufferHeight))
    }

}
