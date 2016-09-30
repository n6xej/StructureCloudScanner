//
//  UploadNavigationBar.swift
//  Scanner
//
//  Created by Christopher Worley on 9/29/16.
//  Copyright © 2016 stashdump.com. All rights reserved.
//

import UIKit

class UploadNavigationBar: UINavigationBar {
	
	private var progress0Layer = CAShapeLayer()
	private var progress1Layer = CAShapeLayer()
	private let progressColor = UIColor.init(red: 0, green: 0.764, blue: 1, alpha: 1).cgColor
	private let trackHeight: CGFloat = 2.0

    var progress0: Float = 0 {
        didSet {
			progress0 = max(0, min(1, progress0))
			setNeedsDisplay()
		}
    }
	var progress1: Float = 0 {
		didSet {
			progress1 = max(0, min(1, progress1))
			setNeedsDisplay()
		}
	}
	
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
		
		setupView()
    }
	
	private func setupView() {

		progress0Layer.isHidden = true
		progress0Layer.backgroundColor = UIColor.clear.cgColor
		progress0Layer.strokeColor = progressColor
		
		progress1Layer.isHidden = true
		progress1Layer.backgroundColor = UIColor.clear.cgColor
		progress1Layer.strokeColor = progressColor
		
		layer.addSublayer(progress0Layer)
		layer.addSublayer(progress1Layer)
	}
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var rect = bounds
        rect.origin.y = rect.height - trackHeight * 2.5
        rect.size.height = trackHeight
        progress0Layer.frame = rect
        
        let path0 = UIBezierPath()
		
		path0.move(to: CGPoint.init(x: 0, y: 0))
		path0.addLine(to: CGPoint.init(x: rect.width, y: trackHeight))
        progress0Layer.path = path0.cgPath
		progress0Layer.lineWidth = trackHeight
		progress0Layer.strokeEnd = CGFloat(progress0)
		
		rect = bounds
		rect.origin.y = rect.height - trackHeight
		rect.size.height = trackHeight
		progress1Layer.frame = rect
		
		let path1 = UIBezierPath()
		
		path1.move(to: CGPoint.init(x: 0, y: 0))
		path1.addLine(to: CGPoint.init(x: rect.width, y: trackHeight))
		progress1Layer.path = path1.cgPath
		progress1Layer.lineWidth = trackHeight
		progress1Layer.strokeEnd = CGFloat(progress1)
    }
	
    override func setNeedsDisplay() {
		
        if abs(progress0 - 1.0) <= 1e-3 && abs(progress1 - 1.0) <= 1e-3  {
            progress0Layer.isHidden = true
            progress0Layer.strokeEnd = 0
			progress1Layer.isHidden = true
			progress1Layer.strokeEnd = 0
        }
		else {
            progress0Layer.isHidden = false
            progress0Layer.strokeEnd = CGFloat(progress0)
			progress1Layer.isHidden = false
			progress1Layer.strokeEnd = CGFloat(progress1)
        }
		
        super.setNeedsDisplay()
    }
}
