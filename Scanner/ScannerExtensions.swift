//
//	Extensions for Swift port of the Structure SDK sample app "Scanner".
//	Copyright © 2016 Christopher Worley. All rights reserved.
//
//  ScannerExtensions.swift
//
//  Ported by Christopher Worley on 8/20/16.
//


extension Timer {
	class func schedule(_ delay: TimeInterval, handler: @escaping (CFRunLoopTimer?) -> Void) -> Timer {
		let fireDate = delay + CFAbsoluteTimeGetCurrent()
		let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fireDate, 0, 0, 0, handler)
		CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, CFRunLoopMode.commonModes)
		return timer!
	}
}

public extension Float {
	public static let epsilon: Float = 1e-8
	func nearlyEqual(_ b: Float) -> Bool {
		return abs(self - b) < Float.epsilon
	}
}

class Singleton {
	static let sharedInstance: Singleton = {
		let instance = Singleton()
		
		// setup code
		
		return instance
	}()
}

open class FileMgr: NSObject {
	
	 var rootPath: String!
	 var basePath: NSString!
	
	static let sharedInstance: FileMgr = {
		let instance = FileMgr.init()
	
		return instance
	}()

    fileprivate override init() {
        super.init()
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        self.rootPath = paths[0].path
        self.basePath = (self.rootPath as NSString)
    }
    
    fileprivate func mksubdir( _ subpath: String) -> Bool {
        
        let fullPath = self.full(subpath)
        
        if !self.exists(fullPath) {
            
            do {
                try FileManager.default.createDirectory(atPath: fullPath, withIntermediateDirectories: true, attributes: nil)
                return true
            }
            catch {
                return false
            }
        }
        
        return true
    }
    
    func useSubpath( _ subPath: String) {
        
        let ret = mksubdir(subPath)
		if !ret {
			NSLog("mksubdir")
		}
        self.basePath = (rootPath as NSString).appendingPathComponent(subPath) as NSString!
    }
    
    func root() -> NSString {
        
        return self.rootPath as NSString
    }
    
    func full( _ name: String) -> String {
        
        return self.basePath.appendingPathComponent(name)
    }
    
    func del( _ name: String) {
        
        let name = self.basePath.appendingPathComponent(name)
        
        do {
            try FileManager.default.removeItem(atPath: name)
        }
        catch {
            print("Error deleting \(name) \(error)")
        }
    }
    
    func getData( _ name: String) -> Data? {
        
        let fullPathFile = self.basePath.appendingPathComponent(name)
        
        if self.exists(fullPathFile) {
            
            if let data = try? Data(contentsOf: URL(fileURLWithPath: fullPathFile)) {
                return data
            }
            
            print("Error reading data")
            return nil
        }
        
        print("Error no file \(name)")
        return nil
    }
    
    func saveData( _ name: String, data: Data) -> Data? {
        
        let fullPathFile = self.basePath.appendingPathComponent(name)
        
        if self.exists(fullPathFile) {
            self.del(fullPathFile)
        }
        
        do {
            try  data.write( to: URL(fileURLWithPath: fullPathFile), options:NSData.WritingOptions.atomicWrite )
            return data
        }
        catch {
            print("Error writing file \(error)")
            return nil
        }
    }
    
    func saveMesh( _ name: String, data: STMesh) -> Data? {
        
        let options: [AnyHashable: Any] = [ kSTMeshWriteOptionFileFormatKey : STMeshWriteOptionFileFormat.objFileZip.rawValue]
        
        let fullPathFile = self.basePath.appendingPathComponent(name)
        
        if self.exists(fullPathFile) {
            self.del(fullPathFile)
        }
        
        do {
            try data.write(toFile: fullPathFile, options: options)
            
            if let zipData = try? Data(contentsOf: URL(fileURLWithPath: fullPathFile)) {
                return zipData
            }
            print("Error reading mesh")
            return nil
        }
        catch {
            print("Error writing mesh \(error)")
            return nil
        }
    }
    
    func filepath( _ subdir: String, name: String) -> String? {
        
        let fullPathFile = self.full(subdir)
        
        if !self.exists(fullPathFile) {
            
            do {
                try FileManager.default.createDirectory(atPath: fullPathFile, withIntermediateDirectories: true, attributes: nil)
                
                return (fullPathFile as NSString).appendingPathComponent(name)
            }
            catch {
                return nil
            }
        }
        
        return (fullPathFile as NSString).appendingPathComponent(name)
        
    }
    
    func exists( _ name: String) -> Bool {
        
        let fullPath = self.basePath.appendingPathComponent(name)
        
        return FileManager.default.fileExists(atPath: fullPath)
    }
}

