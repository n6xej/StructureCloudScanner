//
//	This file is a Swift port of the Structure SDK sample app "Scanner".
//	Copyright © 2016 Occipital, Inc. All rights reserved.
//	http://structure.io
//
//  CustomShaders.swift
//
//  Ported by Christopher Worley on 8/20/16.
//

open class CustomShader : NSObject {
	
    enum Attrib : GLuint {
        case vertex = 0
        case normal
        case color
        case textCoord
    }

	var glProgram: GLuint = 0
	var loaded: Bool = false
    
    override init() {
        loaded = false
    }
	
    func load() {}
	
	func enable() {
		if !loaded {
			load()
		}
		glUseProgram(glProgram)
	}
	
	func vertexShaderSource() -> NSString {
		return "" }
	
	func fragmentShaderSource() -> NSString {
		return "" }
}

class LightedGrayShader: CustomShader {
    
    var projectionLocation: GLint = 0
    var modelviewLocation: GLint = 0
    
    func prepareRendering(_ projection: UnsafePointer<GLfloat>, modelView: UnsafePointer<GLfloat>)
    {
        glUniformMatrix4fv(modelviewLocation, 1, GLboolean(GL_FALSE), modelView)
        glUniformMatrix4fv(projectionLocation, 1, GLboolean(GL_FALSE), projection)
		
        glDisable( GLenum(GL_BLEND))
    }
	
    override func load()
    {
        let NUM_ATTRIBS: Int = 2

        let attributeIds: [GLuint] = [Attrib.vertex.rawValue, Attrib.normal.rawValue]
        let attributeNames: [String] = ["a_position", "a_normal"]
		
        glProgram = loadOpenGLProgramFromString(vertexShaderSource(), fragment_shader_src: fragmentShaderSource(), num_attributes: NUM_ATTRIBS, attribute_ids: attributeIds, attribute_names: attributeNames)
		
        projectionLocation = glGetUniformLocation(glProgram, "u_perspective_projection")
        modelviewLocation = glGetUniformLocation(glProgram, "u_modelview")
		
        glUseProgram(0)
        loaded = true
    }
	
	override func vertexShaderSource() -> NSString {
		
		let source = "" +
		"attribute vec4 a_position; \n" +
		"attribute vec3 a_normal; \n" +
		
		"uniform mat4 u_perspective_projection; \n" +
		"uniform mat4 u_modelview; \n" +
		
		"varying float v_luminance; \n" +
		
		"void main() \n" +
		"{ \n" +
			"gl_Position = u_perspective_projection*u_modelview*a_position; \n" +
		
			//mat3 scaledRotation = mat3(u_modelview);
		
			// Directional lighting that moves with the camera
			"vec3 vec = mat3(u_modelview)*a_normal; \n" +
		
			// Slightly reducing the effect of the lighting
			"v_luminance = 0.5*abs(vec.z) + 0.5; \n" +
		"} \n"
		
		return source as NSString

	}
	
	override func fragmentShaderSource() -> NSString {

		let source = "" +
		"precision mediump float; \n" +
		
		"varying float v_luminance; \n" +
		
		"void main() \n" +
			"{ \n" +
				"gl_FragColor = vec4(v_luminance, v_luminance, v_luminance, 1.0); \n" +
		"} \n"
		
		return source as NSString
		
	}
}

class PerVertexColorShader: CustomShader {
    
    var projectionLocation: GLuint = 0
    var modelviewLocation: GLuint = 0
    
    override func load()
    {
        let NUM_ATTRIBS: Int = 3
		
        let attributeIds: [GLuint] = [Attrib.vertex.rawValue, Attrib.normal.rawValue, Attrib.color.rawValue]
        let attributeNames: [String] = ["a_position", "a_normal", "a_color"]
		
        glProgram = loadOpenGLProgramFromString(vertexShaderSource(), fragment_shader_src: fragmentShaderSource(), num_attributes: NUM_ATTRIBS, attribute_ids: attributeIds, attribute_names: attributeNames)
		
        projectionLocation = GLuint(glGetUniformLocation(glProgram, "u_perspective_projection"))
        modelviewLocation = GLuint(glGetUniformLocation(glProgram, "u_modelview"))
		
        glUseProgram(0)
        loaded = true
    }
	
    func prepareRendering(_ projection: UnsafePointer<GLfloat>, modelView: UnsafePointer<GLfloat>)
    {
        glUniformMatrix4fv( GLint(modelviewLocation), 1, GLboolean(GL_FALSE), modelView)
        glUniformMatrix4fv( GLint(projectionLocation), 1, GLboolean(GL_FALSE), projection)
		
        glDisable( GLenum(GL_BLEND))
    }

	override func vertexShaderSource() -> NSString {
		let source = "" +
		"attribute vec4 a_position; \n" +
		"attribute vec3 a_normal; \n" +
		"attribute vec3 a_color; \n" +
		"uniform mat4 u_perspective_projection; \n" +
		"uniform mat4 u_modelview; \n" +
		
		"varying vec3 v_color; \n" +
		
		"void main() \n" +
			"{ \n" +
				"gl_Position = u_perspective_projection*u_modelview*a_position; \n" +
				"v_color = a_color; \n" +
		"} \n"
		
		return source as NSString
	}
		
	override func fragmentShaderSource() -> NSString {
		
		let source = "" +
		"precision mediump float; \n" +
		
		"varying vec3 v_color; \n" +
		"void main() \n" +
			"{ \n" +
				"gl_FragColor = vec4(v_color, 1.0); \n" +
		"} \n"
		
		return source as NSString
	}
}

class XrayShader : CustomShader {
	
    var projectionLocation: GLuint = 0
    var modelviewLocation: GLuint = 0
	
    override func load()
    {
        let NUM_ATTRIBS: Int = 2
		
        let attributeIds: [GLuint] = [Attrib.vertex.rawValue, Attrib.normal.rawValue]
        let attributeNames: [String] = ["a_position", "a_normal"]
		
        glProgram = loadOpenGLProgramFromString(vertexShaderSource(), fragment_shader_src: fragmentShaderSource(), num_attributes: NUM_ATTRIBS, attribute_ids: attributeIds, attribute_names: attributeNames)
		
        projectionLocation = GLuint(glGetUniformLocation(glProgram, "u_perspective_projection"))
        modelviewLocation = GLuint(glGetUniformLocation(glProgram, "u_modelview"))
		
        glUseProgram(0)
        loaded = true
    }
	
    func prepareRendering(_ projection: UnsafePointer<GLfloat>, modelView: UnsafePointer<GLfloat>)
    {
        glUniformMatrix4fv( GLint(modelviewLocation), 1, GLboolean(GL_FALSE), modelView)
        glUniformMatrix4fv( GLint(projectionLocation), 1, GLboolean(GL_FALSE), projection)
		
        glDisable( GLenum(GL_BLEND))
    }

    
	override func vertexShaderSource() -> NSString {
		
		let source = "" +
		"attribute vec4 a_position; \n" +
		"attribute vec3 a_normal; \n" +
		"uniform mat4 u_perspective_projection; \n" +
		"uniform mat4 u_modelview; \n" +
		
		"varying float v_luminance; \n" +
		
		"void main() \n" +
			"{ \n" +
				"gl_Position = u_perspective_projection*u_modelview*a_position; \n" +
				
				// Directional lighting that moves with the camera
				"vec3 vec = mat3(u_modelview)*a_normal; \n" +
				"v_luminance = 1.0 - abs(vec.z); \n" +
		"} \n"
		
		return source as NSString
	}
	
	override func fragmentShaderSource() -> NSString {
		
		let source = "" +
		"precision mediump float; \n" +
		
		"varying float v_luminance; \n" +
		
		"void main() \n" +
			"{ \n" +
				"gl_FragColor = vec4(v_luminance, v_luminance, v_luminance, 1.0); \n" +
		"} \n"
		
		return source as NSString
	}
}

class YCbCrTextureShader : CustomShader {
	
    var projectionLocation: GLuint = 0
    var modelviewLocation: GLuint = 0
    var ySamplerLocation: GLuint = 0
    var cbcrSamplerLocation: GLuint = 0
	
    override func load()
    {
		let NUM_ATTRIBS: Int = 2
		
        let attributeIds: [GLuint] = [Attrib.vertex.rawValue, Attrib.textCoord.rawValue]
        let attributeNames: [String] = ["a_position", "a_texCoord"]
		
        glProgram = loadOpenGLProgramFromString(vertexShaderSource(), fragment_shader_src: fragmentShaderSource(), num_attributes: NUM_ATTRIBS, attribute_ids: attributeIds, attribute_names: attributeNames)
		
        projectionLocation = GLuint(glGetUniformLocation(glProgram, "u_perspective_projection"))
        modelviewLocation = GLuint(glGetUniformLocation(glProgram, "u_modelview"))
        ySamplerLocation = GLuint(glGetUniformLocation(glProgram, "s_texture_y"))
        cbcrSamplerLocation = GLuint(glGetUniformLocation(glProgram, "s_texture_cbcr"))
        glUseProgram(0)
        loaded = true
    }
	
    func prepareRendering(_ projection: UnsafePointer<GLfloat>, modelView: UnsafePointer<GLfloat>, textureUnit: GLint)
    {
        glUniformMatrix4fv(GLint(modelviewLocation), 1, GLboolean(GL_FALSE), modelView)
        glUniformMatrix4fv(GLint(projectionLocation), 1, GLboolean(GL_FALSE), projection)
        glUniform1i(GLint(ySamplerLocation), textureUnit - GL_TEXTURE0)
        glUniform1i(GLint(cbcrSamplerLocation), textureUnit + 1 - GL_TEXTURE0)
    }
	
	override func vertexShaderSource() -> NSString {
		
		let source = "" +
		"attribute vec4 a_position; \n" +
		"attribute vec2 a_texCoord; \n" +
		"uniform mat4 u_perspective_projection; \n" +
		"uniform mat4 u_modelview; \n" +
		
		"varying vec2 v_texCoord; \n" +
		
		"void main() \n" +
			"{ \n" +
				"gl_Position = u_perspective_projection*u_modelview*a_position; \n" +
				
				"v_texCoord = a_texCoord; \n" +
		
		"} \n"
		
		return source as NSString
	}
	
	override func fragmentShaderSource() -> NSString {
		
		let source = "" +
		"precision mediump float; \n" +
		
		"uniform sampler2D s_texture_y; \n" +
		"uniform sampler2D s_texture_cbcr; \n" +
		
		"varying vec2 v_texCoord; \n" +
		"void main() \n" +
			"{ \n" +
				"mediump vec3 yuv; \n" +
				"lowp vec3 rgb; \n" +
				
				"yuv.x = texture2D(s_texture_y, v_texCoord).r; \n" +
				"yuv.yz = texture2D(s_texture_cbcr, v_texCoord).rg - vec2(0.5, 0.5); \n" +
				
				"rgb = mat3(      1,       1,      1, \n" +
					"0, -.18732, 1.8556, \n" +
					"1.57481, -.46813,      0) * yuv; \n" +
				
				"gl_FragColor = vec4(rgb, 1.0); \n" +
		"} \n"
		
		return source as NSString
	}
}

// Helper functions.

func loadOpenGLShaderFromString(_ type: GLenum, shaderSrc: NSString) -> GLuint {
 
    var shader: GLuint
    var compiled: GLint = GL_FALSE
	
    // Create the shader object
    shader = glCreateShader(type)
	
    if shader == 0 {
        return 0
    }
	
	var castSrc = UnsafePointer<GLchar>(shaderSrc.utf8String)

    // Load the shader source
    glShaderSource(shader, 1, &castSrc, nil)
	
    // Compile the shader
    glCompileShader(shader)
	
    // Check the compile status
    glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &compiled)
	
    if compiled == GL_FALSE {
		
        var infoLen: GLint = 0
		
        glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &infoLen)
		
        if infoLen > 1 {
			
			var infoLog: [GLchar] = [GLchar](repeating: 0, count: Int(infoLen))
			glGetShaderInfoLog(shader, infoLen, nil, &infoLog)
            NSLog("Error compiling shader: \(infoLog)\n")
            NSLog("Code: %@\n", shaderSrc)
        }
		
        glDeleteShader(shader)
        return 0
    }
	
    return shader
}

func loadOpenGLProgramFromString(_ vertex_shader_src : NSString, fragment_shader_src : NSString, num_attributes : Int, attribute_ids: [GLuint], attribute_names : [String]) -> GLuint {

    var vertex_shader: GLuint!
    var fragment_shader: GLuint!
    var program_object: GLuint!
	
    // Load the vertex/fragment shaders
    vertex_shader = loadOpenGLShaderFromString( GLenum(GL_VERTEX_SHADER), shaderSrc: vertex_shader_src)
	
    if vertex_shader == 0 {
        return 0
    }
    
    //NSLog("Shader -> %@\n", vertex_shader_src)
    fragment_shader = loadOpenGLShaderFromString( GLenum(GL_FRAGMENT_SHADER), shaderSrc: fragment_shader_src)
	
    if fragment_shader == 0 {
        glDeleteShader(vertex_shader)
        return 0
    }

    // Create the program object
    program_object = glCreateProgram()
	
    if program_object == 0 {
        return 0
    }
	
    glAttachShader(program_object, vertex_shader)
    glAttachShader(program_object, fragment_shader)
	
    // Bind attributes before linking
    for i in 0..<num_attributes {
        glBindAttribLocation(program_object, attribute_ids[i], attribute_names[i])
    }
	
    var linked: GLint = 0
	
    // Link the program
    glLinkProgram(program_object)
	
    // Check the link status
    glGetProgramiv(program_object, GLenum(GL_LINK_STATUS), &linked)
	
    if linked == GL_FALSE {
		
        var infoLen: GLint = 0
		
        glGetProgramiv(program_object, GLenum(GL_INFO_LOG_LENGTH), &infoLen)
		
        if infoLen > 1 {
			
			var infoLog: [GLchar] = [GLchar](repeating: 0, count: Int(infoLen))
            glGetProgramInfoLog(program_object, infoLen, nil, &infoLog)
            NSLog("Error linking program: \(infoLog)\n")
        }
		
        glDeleteProgram(program_object)
        return 0
    }
	
    // Free up no longer needed shader resources
    glDeleteShader(vertex_shader)
    glDeleteShader(fragment_shader)
	
    return program_object
}
