//
//	This file is a Swift port of the Structure SDK sample app "Scanner".
//	Copyright © 2016 Occipital, Inc. All rights reserved.
//	http://structure.io
//
//  MeshRenderer.swift
//
//  Ported by Christopher Worley on 8/20/16.
//

let MAX_MESHES: Int = 30

class MeshRenderer: NSObject {

	enum RenderingMode: Int {

        case xRay = 0
        case perVertexColor
        case textured
        case lightedGray
    }

    struct PrivateData {

        var lightedGrayShader: LightedGrayShader?
        var perVertexColorShader: PerVertexColorShader?
        var xRayShader: XrayShader?
        var yCbCrTextureShader: YCbCrTextureShader?

        var numUploadedMeshes: Int = 0
		var numTriangleIndices = [Int](repeating: 0, count: MAX_MESHES)
        var numLinesIndices = [Int](repeating: 0, count: MAX_MESHES)

        var hasPerVertexColor: Bool = false
        var hasPerVertexNormals: Bool = false
        var hasPerVertexUV: Bool = false
        var hasTexture: Bool = false

        // Vertex buffer objects.
        var vertexVbo = [GLuint](repeating: 0, count: MAX_MESHES)
        var normalsVbo = [GLuint](repeating: 0, count: MAX_MESHES)
        var colorsVbo = [GLuint](repeating: 0, count: MAX_MESHES)
        var texcoordsVbo = [GLuint](repeating: 0, count: MAX_MESHES)
        var facesVbo = [GLuint](repeating: 0, count: MAX_MESHES)
        var linesVbo = [GLuint](repeating: 0, count: MAX_MESHES)

        // OpenGL Texture reference for y and chroma images.
        var lumaTexture: CVOpenGLESTexture? = nil
        var chromaTexture: CVOpenGLESTexture? = nil

        // OpenGL Texture cache for the color texture.
        var textureCache: CVOpenGLESTextureCache? = nil

        // Texture unit to use for texture binding/rendering.
        var textureUnit: GLenum = GLenum(GL_TEXTURE3)

        // Current render mode.
        var currentRenderingMode: RenderingMode = .lightedGray

		internal init() {

			lightedGrayShader = LightedGrayShader()
			perVertexColorShader = PerVertexColorShader()
			xRayShader = XrayShader()
			yCbCrTextureShader = YCbCrTextureShader()
		}
    }

	var d: PrivateData?

	override init() {

		self.d = PrivateData.init()

	}

   func initializeGL(_ defaultTextureUnit: GLenum = GLenum(GL_TEXTURE3)) {

        d!.textureUnit = defaultTextureUnit
        glGenBuffers( GLsizei(MAX_MESHES), &d!.vertexVbo)
        glGenBuffers( GLsizei(MAX_MESHES), &d!.normalsVbo)
        glGenBuffers( GLsizei(MAX_MESHES), &d!.colorsVbo)
        glGenBuffers( GLsizei(MAX_MESHES), &d!.texcoordsVbo)
        glGenBuffers( GLsizei(MAX_MESHES), &d!.facesVbo)
        glGenBuffers( GLsizei(MAX_MESHES), &d!.linesVbo)
    }

  func releaseGLTextures() {

        if (d!.lumaTexture != nil) {

            d!.lumaTexture = nil
        }

        if (d!.chromaTexture != nil) {

            d!.chromaTexture = nil
        }

        if (d!.textureCache != nil) {

            d!.textureCache = nil
        }
    }

  func releaseGLBuffers() {

        for meshIndex in 0..<d!.numUploadedMeshes {

            glBindBuffer( GLenum(GL_ARRAY_BUFFER), d!.vertexVbo[meshIndex])
            glBufferData( GLenum(GL_ARRAY_BUFFER), 0, nil, GLenum(GL_STATIC_DRAW))

            glBindBuffer( GLenum(GL_ARRAY_BUFFER), d!.normalsVbo[meshIndex])
            glBufferData( GLenum(GL_ARRAY_BUFFER), 0, nil, GLenum(GL_STATIC_DRAW))

            glBindBuffer( GLenum(GL_ARRAY_BUFFER), d!.colorsVbo[meshIndex])
            glBufferData( GLenum(GL_ARRAY_BUFFER), 0, nil, GLenum(GL_STATIC_DRAW))

            glBindBuffer( GLenum(GL_ARRAY_BUFFER), d!.texcoordsVbo[meshIndex])
            glBufferData( GLenum(GL_ARRAY_BUFFER), 0, nil, GLenum(GL_STATIC_DRAW))

            glBindBuffer( GLenum(GL_ELEMENT_ARRAY_BUFFER), d!.facesVbo[meshIndex])
            glBufferData( GLenum(GL_ELEMENT_ARRAY_BUFFER), 0, nil, GLenum(GL_STATIC_DRAW))

            glBindBuffer( GLenum(GL_ELEMENT_ARRAY_BUFFER), d!.linesVbo[meshIndex])
            glBufferData( GLenum(GL_ELEMENT_ARRAY_BUFFER), 0, nil, GLenum(GL_STATIC_DRAW))
        }
    }

	deinit {

		MeshRendererDestructor(self.d!)

		self.d = nil
	}

    func MeshRendererDestructor(_ d: PrivateData) {

        if d.vertexVbo[0] != 0 {
            glDeleteBuffers( GLsizei(MAX_MESHES), d.vertexVbo)
        }
        if d.normalsVbo[0] != 0 {
            glDeleteBuffers( GLsizei(MAX_MESHES), d.normalsVbo)
        }
        if d.colorsVbo[0] != 0 {
            glDeleteBuffers( GLsizei(MAX_MESHES), d.colorsVbo)
        }
        if d.texcoordsVbo[0] != 0 {
            glDeleteBuffers( GLsizei(MAX_MESHES), d.texcoordsVbo)
        }
        if d.facesVbo[0] != 0 {
            glDeleteBuffers( GLsizei(MAX_MESHES), d.facesVbo)
        }
        if d.linesVbo[0] != 0 {
            glDeleteBuffers( GLsizei(MAX_MESHES), d.linesVbo)
        }

        releaseGLTextures()

		self.d!.lightedGrayShader = nil
		self.d!.perVertexColorShader = nil
		self.d!.xRayShader = nil
		self.d!.yCbCrTextureShader = nil
		self.d!.numUploadedMeshes = 0
    }

   func clear() {

        if d!.currentRenderingMode == RenderingMode.perVertexColor || d!.currentRenderingMode == RenderingMode.textured {
            glClearColor(0.9, 0.9, 0.9, 1)
        } else {
            glClearColor(0.1, 0.1, 0.1, 1)
        }

        glClearDepthf(1)

        glClear( GLenum(GL_COLOR_BUFFER_BIT) | GLenum(GL_DEPTH_BUFFER_BIT))
    }

   func setRenderingMode(_ mode: RenderingMode) {
        d!.currentRenderingMode = mode
    }

   func getRenderingMode() -> RenderingMode {
        return d!.currentRenderingMode
    }


    func uploadMesh(_ mesh: STMesh) {

        let numUploads: Int = min(Int(mesh.numberOfMeshes()), Int(MAX_MESHES))
        d!.numUploadedMeshes = min(Int(mesh.numberOfMeshes()), Int(MAX_MESHES))

        d!.hasPerVertexColor = mesh.hasPerVertexColors()
        d!.hasPerVertexNormals = mesh.hasPerVertexNormals()
        d!.hasPerVertexUV = mesh.hasPerVertexUVTextureCoords()
        d!.hasTexture = (mesh.meshYCbCrTexture() != nil)

        if d!.hasTexture {
			let pixelBuffer = Unmanaged<CVImageBuffer>.takeUnretainedValue(mesh.meshYCbCrTexture())
            uploadTexture(pixelBuffer())
        }

        for meshIndex in 0..<numUploads {

            let numVertices: Int = Int(mesh.number(ofMeshVertices: Int32(meshIndex)))

            glBindBuffer( GLenum(GL_ARRAY_BUFFER), d!.vertexVbo[meshIndex])
            glBufferData( GLenum(GL_ARRAY_BUFFER), numVertices * MemoryLayout<GLKVector3>.size, mesh.meshVertices(Int32(meshIndex)), GLenum(GL_STATIC_DRAW))

            if d!.hasPerVertexNormals {

                glBindBuffer( GLenum(GL_ARRAY_BUFFER), d!.normalsVbo[meshIndex])
                glBufferData( GLenum(GL_ARRAY_BUFFER), numVertices * MemoryLayout<GLKVector3>.size, mesh.meshPerVertexNormals(Int32(meshIndex)), GLenum(GL_STATIC_DRAW))
            }

            if d!.hasPerVertexColor {

                glBindBuffer( GLenum(GL_ARRAY_BUFFER), d!.colorsVbo[meshIndex])
                glBufferData( GLenum(GL_ARRAY_BUFFER), numVertices * MemoryLayout<GLKVector3>.size, mesh.meshPerVertexColors(Int32(meshIndex)), GLenum(GL_STATIC_DRAW))
            }

            if d!.hasPerVertexUV {

                glBindBuffer( GLenum(GL_ARRAY_BUFFER), d!.texcoordsVbo[meshIndex])
                glBufferData( GLenum(GL_ARRAY_BUFFER), numVertices * MemoryLayout<GLKVector2>.size, mesh.meshPerVertexUVTextureCoords(Int32(meshIndex)), GLenum(GL_STATIC_DRAW))
            }

            glBindBuffer( GLenum(GL_ELEMENT_ARRAY_BUFFER), d!.facesVbo[meshIndex])
            glBufferData( GLenum(GL_ELEMENT_ARRAY_BUFFER), Int(mesh.number(ofMeshFaces: Int32(meshIndex))) * MemoryLayout<UInt16>.size * 3, mesh.meshFaces(Int32(meshIndex)), GLenum(GL_STATIC_DRAW))

            glBindBuffer( GLenum(GL_ELEMENT_ARRAY_BUFFER), d!.linesVbo[meshIndex])
            glBufferData( GLenum(GL_ELEMENT_ARRAY_BUFFER), Int(mesh.number(ofMeshLines: Int32(meshIndex))) * MemoryLayout<UInt16>.size * 2, mesh.meshLines(Int32(meshIndex)), GLenum(GL_STATIC_DRAW))

            glBindBuffer( GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
            glBindBuffer( GLenum(GL_ARRAY_BUFFER), 0)

            d!.numTriangleIndices[meshIndex] = Int(mesh.number(ofMeshFaces: Int32(meshIndex)) * 3)
            d!.numLinesIndices[meshIndex] = Int(mesh.number(ofMeshLines: Int32(meshIndex)) * 2)
        }
    }

    func uploadTexture(_ pixelBuffer: CVImageBuffer) {

        let width = Int(CVPixelBufferGetWidth(pixelBuffer))
        let height = Int(CVPixelBufferGetHeight(pixelBuffer))

        let context: EAGLContext? = EAGLContext.current()
        assert(context != nil)

        releaseGLTextures()

        if d!.textureCache == nil {

            let texError = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, context!, nil, &d!.textureCache)
            if texError != kCVReturnSuccess {
                NSLog("Error at CVOpenGLESTextureCacheCreate \(texError)")
            }
        }

        // Allow the texture cache to do internal cleanup.
        CVOpenGLESTextureCacheFlush(d!.textureCache!, 0)

        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        assert(pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)

        // Activate the default texture unit.
        glActiveTexture(d!.textureUnit)

        // Create a new Y texture from the video texture cache.
        var err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, d!.textureCache!, pixelBuffer, nil, GLenum(GL_TEXTURE_2D), GL_RED_EXT, GLsizei(width), GLsizei(height), GLenum(GL_RED_EXT), GLenum(GL_UNSIGNED_BYTE), 0, &d!.lumaTexture)

        if err != kCVReturnSuccess {
            NSLog("Error with CVOpenGLESTextureCacheCreateTextureFromImage: \(err)")
            return
        }

        // Set rendering properties for the new texture.
        glBindTexture(CVOpenGLESTextureGetTarget(d!.lumaTexture!), CVOpenGLESTextureGetName(d!.lumaTexture!))
        glTexParameterf( GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf( GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))

        // Activate the next texture unit for CbCr.
        glActiveTexture(d!.textureUnit + 1)

        // Create a new CbCr texture from the video texture cache.
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, d!.textureCache!, pixelBuffer, nil, GLenum(GL_TEXTURE_2D), GL_RG_EXT, Int32(width) / 2, Int32(height) / 2, GLenum(GL_RG_EXT), GLenum(GL_UNSIGNED_BYTE), 1, &d!.chromaTexture)

        if err != kCVReturnSuccess {
            NSLog("Error with CVOpenGLESTextureCacheCreateTextureFromImage: \(err)")
            return
        }

        glBindTexture(CVOpenGLESTextureGetTarget(d!.chromaTexture!), CVOpenGLESTextureGetName(d!.chromaTexture!))
        glTexParameterf( GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf( GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
        glBindTexture( GLenum(GL_TEXTURE_2D), 0)
    }

    func enableVertexBuffer(_ meshIndex: Int) {

        glBindBuffer( GLenum(GL_ARRAY_BUFFER), d!.vertexVbo[meshIndex])
        glEnableVertexAttribArray(CustomShader.Attrib.vertex.rawValue)
        glVertexAttribPointer(CustomShader.Attrib.vertex.rawValue, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, nil)
    }

    func disableVertexBuffer(_ meshIndex: Int) {

        glBindBuffer( GLenum(GL_ARRAY_BUFFER), d!.vertexVbo[meshIndex])
        glDisableVertexAttribArray(CustomShader.Attrib.vertex.rawValue)
    }

    func enableNormalBuffer (_ meshIndex: Int) {

        glBindBuffer( GLenum(GL_ARRAY_BUFFER), d!.normalsVbo[meshIndex])
        glEnableVertexAttribArray(CustomShader.Attrib.normal.rawValue)
        glVertexAttribPointer(CustomShader.Attrib.normal.rawValue, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, nil)
    }

    func disableNormalBuffer(_ meshIndex: Int) {

        glBindBuffer( GLenum(GL_ARRAY_BUFFER), d!.normalsVbo[meshIndex])
        glDisableVertexAttribArray(CustomShader.Attrib.normal.rawValue)
    }

    func enableVertexColorBuffer (_ meshIndex: Int) {

        glBindBuffer( GLenum(GL_ARRAY_BUFFER), d!.colorsVbo[meshIndex])
        glEnableVertexAttribArray(CustomShader.Attrib.color.rawValue)
        glVertexAttribPointer(CustomShader.Attrib.color.rawValue, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, nil)
    }

    func disableVertexColorBuffer(_ meshIndex: Int) {

        glBindBuffer( GLenum(GL_ARRAY_BUFFER), d!.colorsVbo[meshIndex])
        glDisableVertexAttribArray(CustomShader.Attrib.color.rawValue)
    }

    func enableVertexTexcoordsBuffer (_ meshIndex: Int) {

        glBindBuffer( GLenum(GL_ARRAY_BUFFER), d!.texcoordsVbo[meshIndex])
        glEnableVertexAttribArray(CustomShader.Attrib.textCoord.rawValue)
        glVertexAttribPointer(CustomShader.Attrib.textCoord.rawValue, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, nil)
    }

    func disableVertexTexcoordBuffer(_ meshIndex: Int) {

        glBindBuffer( GLenum(GL_ARRAY_BUFFER), d!.texcoordsVbo[meshIndex])
        glDisableVertexAttribArray(CustomShader.Attrib.textCoord.rawValue)
    }

    func enableLinesElementBuffer (_ meshIndex: Int) {

        glBindBuffer( GLenum(GL_ELEMENT_ARRAY_BUFFER), d!.linesVbo[meshIndex])
        glLineWidth(1.0)
    }

    func enableTrianglesElementBuffer (_ meshIndex: Int) {
        glBindBuffer( GLenum(GL_ELEMENT_ARRAY_BUFFER), d!.facesVbo[meshIndex])
    }

    func renderPartialMesh (_ meshIndex: Int) {
		//nothing uploaded. return test
        if d!.numTriangleIndices[meshIndex] <= 0 {
            return
        }

        switch d!.currentRenderingMode {

        case RenderingMode.xRay:

            enableLinesElementBuffer(meshIndex)
            enableVertexBuffer(meshIndex)
            enableNormalBuffer(meshIndex)
            glDrawElements( GLenum(GL_LINES), GLsizei(d!.numLinesIndices[meshIndex]), GLenum(GL_UNSIGNED_SHORT), nil)
            disableNormalBuffer(meshIndex)
            disableVertexBuffer(meshIndex)

        case RenderingMode.lightedGray:

            enableTrianglesElementBuffer(meshIndex)
            enableVertexBuffer(meshIndex)
            enableNormalBuffer(meshIndex)
            glDrawElements( GLenum(GL_TRIANGLES), GLsizei(d!.numTriangleIndices[meshIndex]), GLenum(GL_UNSIGNED_SHORT), nil)
            disableNormalBuffer(meshIndex)
            disableVertexBuffer(meshIndex)

        case RenderingMode.perVertexColor:

            enableTrianglesElementBuffer(meshIndex)
            enableVertexBuffer(meshIndex)
            enableNormalBuffer(meshIndex)
            enableVertexColorBuffer(meshIndex)
            glDrawElements( GLenum(GL_TRIANGLES), GLsizei(d!.numTriangleIndices[meshIndex]), GLenum(GL_UNSIGNED_SHORT), nil)
            disableVertexColorBuffer(meshIndex)
            disableNormalBuffer(meshIndex)
            disableVertexBuffer(meshIndex)

        case RenderingMode.textured:

            enableTrianglesElementBuffer(meshIndex)
            enableVertexBuffer(meshIndex)
            enableVertexTexcoordsBuffer(meshIndex)
            glDrawElements( GLenum(GL_TRIANGLES), GLsizei(d!.numTriangleIndices[meshIndex]), GLenum(GL_UNSIGNED_SHORT), nil)
            disableVertexTexcoordBuffer(meshIndex)
            disableVertexBuffer(meshIndex)
        }

        glBindBuffer( GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
        glBindBuffer( GLenum(GL_ARRAY_BUFFER), 0)
    }

 func render(_ projectionMatrix: UnsafePointer<GLfloat>, modelViewMatrix: UnsafePointer<GLfloat>) {

        if d!.currentRenderingMode == RenderingMode.perVertexColor && !d!.hasPerVertexColor && d!.hasTexture && d!.hasPerVertexUV {

            NSLog("Warning: The mesh has no per-vertex colors, but a texture, switching the rendering mode to Textured")
            d!.currentRenderingMode = RenderingMode.textured
        } else if d!.currentRenderingMode == RenderingMode.textured && (!d!.hasTexture || !d!.hasPerVertexUV) && d!.hasPerVertexColor {
            NSLog("Warning: The mesh has no texture, but per-vertex colors, switching the rendering mode to PerVertexColor")
            d!.currentRenderingMode = RenderingMode.perVertexColor
        }

        switch d!.currentRenderingMode {

        case RenderingMode.xRay:
            d!.xRayShader!.enable()
            d!.xRayShader!.prepareRendering(projectionMatrix, modelView: modelViewMatrix)

        case RenderingMode.lightedGray:
            d!.lightedGrayShader!.enable()
            d!.lightedGrayShader!.prepareRendering(projectionMatrix, modelView: modelViewMatrix)

        case RenderingMode.perVertexColor:
            if !d!.hasPerVertexColor {
                NSLog("Warning: the mesh has no colors, skipping rendering.")
                return
            }

            d!.perVertexColorShader!.enable()
            d!.perVertexColorShader!.prepareRendering(projectionMatrix, modelView: modelViewMatrix)

        case RenderingMode.textured:
            if !d!.hasTexture || d!.lumaTexture == nil || d!.chromaTexture == nil {
                NSLog("Warning: null textures, skipping rendering.")
                return
            }

            glActiveTexture(d!.textureUnit)
            glBindTexture(CVOpenGLESTextureGetTarget(d!.lumaTexture!), CVOpenGLESTextureGetName(d!.lumaTexture!))

            glActiveTexture(d!.textureUnit + 1)
            glBindTexture(CVOpenGLESTextureGetTarget(d!.chromaTexture!), CVOpenGLESTextureGetName(d!.chromaTexture!))

            d!.yCbCrTextureShader!.enable()
            d!.yCbCrTextureShader!.prepareRendering(projectionMatrix, modelView: modelViewMatrix, textureUnit: GLint(d!.textureUnit))
        }

        // Keep previous GL_DEPTH_TEST state
        let wasDepthTestEnabled: GLboolean = glIsEnabled( GLenum(GL_DEPTH_TEST))
        glEnable( GLenum(GL_DEPTH_TEST))

        for i in 0..<d!.numUploadedMeshes {
            renderPartialMesh(i)
        }

        if wasDepthTestEnabled == GLboolean(GL_FALSE) {
            glDisable( GLenum(GL_DEPTH_TEST))
        }
    }
}
