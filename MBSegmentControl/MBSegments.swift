//
//  MBSegments.swift
//  MBSegmentControl
//
//  Created by HoaPQ on 7/11/20.
//  Copyright © 2020 HoaPQ. All rights reserved.
//

import UIKit

public struct TextSegment: MBSegmentContentProtocol {
    let text: String
    public var type: MBSegmentType {
        return MBSegmentType.text(text)
    }
    
    public init(text: String) {
        self.text = text
    }
}

public struct IconSegment: MBSegmentContentProtocol {
    let icon: UIImage
    public var type: MBSegmentType {
        return MBSegmentType.icon(icon)
    }
    
    public init(icon: UIImage) {
        self.icon = icon
    }
}

public struct AtrributedSegment: MBSegmentContentProtocol {
    let text: NSAttributedString
    let normalColor: UIColor
    let selectedColor: UIColor
    public var type: MBSegmentType {
        return MBSegmentType.attributed(text, normalColor, selectedColor)
    }
    
    public init(text: NSAttributedString, normalColor: UIColor, selectedColor: UIColor) {
        self.text = text
        self.normalColor = normalColor
        self.selectedColor = selectedColor
    }
}
