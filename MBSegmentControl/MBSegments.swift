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
}

public struct IconSegment: MBSegmentContentProtocol {
    let icon: UIImage
    public var type: MBSegmentType {
        return MBSegmentType.icon(icon)
    }
}

public struct AtrributedSegment: MBSegmentContentProtocol {
    let text: NSAttributedString
    let normalColor: UIColor
    let selectedColor: UIColor
    public var type: MBSegmentType {
        return MBSegmentType.attributed(text, normalColor, selectedColor)
    }
}
