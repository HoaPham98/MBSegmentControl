//
//  MBSegmentControl.swift
//  MBSegmentControl
//
//  Created by HoaPQ on 7/11/20.
//  Copyright © 2020 HoaPQ. All rights reserved.
//

import UIKit

public protocol MBSegmentControlDelegate: class {
    func segmentControl(_ segmentControl: MBSegmentControl, selectIndex newIndex: Int, oldIndex: Int)
}

public protocol MBSegmentContentProtocol {
    var type: MBSegmentType { get }
}

public protocol MBTouchViewDelegate: class {
    func didTouch(_ location: CGPoint)
}

public class MBSegmentControl: UIControl {

    // MARK: Configuration - Content
    public var segments: [MBSegmentContentProtocol] = [] {
        didSet {
            innerSegments = segments.map({ (content) -> MBInnerSegment in
                return MBInnerSegment(content: content)
            })
            self.setNeedsLayout()
            if segments.isEmpty {
                selectedIndex = -1
            }
        }
    }
    var innerSegments: [MBInnerSegment] = []

    // MARK: Configuration - Interaction
    public weak var delegate: MBSegmentControlDelegate?
    public var selectedIndex: Int = -1 {
        didSet {
            if selectedIndex != oldValue && validIndex(selectedIndex) {
                selectedIndexChanged(selectedIndex, oldIndex: oldValue)
                delegate?.segmentControl(self, selectIndex: selectedIndex, oldIndex: oldValue)
            } else if !validIndex(selectedIndex) {
                resetLayer(layer: self.layerStrip)
                resetLayer(layer: self.layerCover)
            }
        }
    }
    public var selectedSegment: MBSegmentContentProtocol? {
        return validIndex(selectedIndex) ? segments[selectedIndex] : nil
    }

    // MARK: Configuration - Appearance
    public var style: MBSegmentIndicatorStyle = .cover(MBSegmentCoverSettings())
    public var nonScrollDistributionStyle: MBSegmentNonScrollDistributionStyle = .average
    public var enableSeparator: Bool = false
    public var separatorColor: UIColor = UIColor.black
    public var separatorWidth: CGFloat = 9
    public var separatorEdgeInsets: UIEdgeInsets = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
    public var enableSlideway: Bool = false
    public var slidewayHeight: CGFloat = 1
    public var slidewayColor: UIColor = UIColor.lightGray
    public var enableAnimation: Bool = true
    public var animationDuration: TimeInterval = 0.15
    public var segmentMinWidth: CGFloat = 50
    public var segmentEdgeInsets: UIEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    public var segmentTextBold: Bool = true
    public var segmentTextFontSize: CGFloat = 12
    public var segmentForegroundColor: UIColor = UIColor.gray
    public var segmentForegroundColorSelected: UIColor = UIColor.black

    // MARK: Inner properties
    fileprivate var scrollView: UIScrollView!
    fileprivate var touchView: MBTouchView = MBTouchView()
    fileprivate var layerContainer: CALayer = CALayer()
    fileprivate var layerCover: CALayer = CALayer()
    fileprivate var layerStrip: CALayer = CALayer()
    fileprivate var segmentControlContentWidth: CGFloat {
        let sum = self.innerSegments.reduce(0, { (maxX, segment) -> CGFloat in
            return max(maxX, segment.segmentFrame.maxX)
        })
        return sum + (self.enableSeparator ? self.separatorWidth / 2 : 0)
    }

    // MARK: Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)

        commonInit()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        commonInit()
    }
    
    fileprivate func commonInit() {
        scrollView = UIScrollView()
        self.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1, constant: 0))
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.layer.addSublayer(layerContainer)
        touchView.isUserInteractionEnabled = true
        scrollView.addSubview(touchView)
        touchView.delegate = self
    }

    // MARK: Override methods
    override public func layoutSubviews() {
        super.layoutSubviews()
        layerContainer.sublayers?.removeAll()

        // Compute Segment Size
        for (index, segment) in self.innerSegments.enumerated() {
            segment.contentSize = self.segmentContentSize(segment)
            segment.segmentWidth = max(segment.contentSize.width + self.segmentEdgeInsets.left + self.segmentEdgeInsets.right, self.segmentMinWidth)
            segment.segmentFrame = self.segmentFrame(index)
        }

        // Adjust Control Content Size & Segment Size
        self.scrollView.contentSize = CGSize(width: self.segmentControlContentWidth, height: self.scrollView.frame.height)
        if self.scrollView.contentSize.width < self.scrollView.frame.width {
            switch self.nonScrollDistributionStyle {
            case .center:
                self.scrollView.contentInset = UIEdgeInsets(top: 0, left: (self.scrollView.frame.width - self.scrollView.contentSize.width) / 2, bottom: 0, right: 0)
            case .left:
                self.scrollView.contentInset = UIEdgeInsets.zero
            case .right:
                self.scrollView.contentInset = UIEdgeInsets(top: 0, left: self.scrollView.frame.width - self.scrollView.contentSize.width, bottom: 0, right: 0)
            case .average:
                self.scrollView.contentInset = UIEdgeInsets.zero
                self.scrollView.contentSize = self.scrollView.frame.size
                var averageWidth: CGFloat = (self.scrollView.frame.width - (self.enableSeparator ? CGFloat(self.innerSegments.count) * self.separatorWidth : 0)) / CGFloat(self.innerSegments.count)
                let largeSegments = self.innerSegments.filter({ (segment) -> Bool in
                    return segment.segmentWidth >= averageWidth
                })
                let smallSegments = self.innerSegments.filter({ (segment) -> Bool in
                    return segment.segmentWidth < averageWidth
                })
                let sumLarge = largeSegments.reduce(0, { (total, segment) -> CGFloat in
                    return total + segment.segmentWidth
                })
                averageWidth = (self.scrollView.frame.width - (self.enableSeparator ? CGFloat(self.innerSegments.count) * self.separatorWidth : 0) - sumLarge) / CGFloat(smallSegments.count)
                for segment in smallSegments {
                    segment.segmentWidth = averageWidth
                }
                for (index, segment) in self.innerSegments.enumerated() {
                    segment.segmentFrame = self.segmentFrame(index)
                    segment.segmentFrame.origin.x += self.separatorWidth / 2
                }
            }
        } else {
            self.scrollView.contentInset = UIEdgeInsets.zero
        }

        // Add Touch View
        touchView.frame = CGRect(origin: CGPoint.zero, size: self.scrollView.contentSize)

        // Add Segment SubLayers
        for (index, segment) in self.innerSegments.enumerated() {
            let contentX = segment.segmentFrame.origin.x + (segment.segmentFrame.width - segment.contentSize.width) / 2
            let contentY = (self.scrollView.frame.height - segment.contentSize.height) / 2
            let contentFrame = CGRect(x: contentX, y: contentY, width: segment.contentSize.width, height: segment.contentSize.height)

            // Add Content Layer
            switch segment.content.type {
            case let .text(text):
                let layerText = CATextLayer()
                layerText.string = text
                let font = segmentTextBold ? UIFont.boldSystemFont(ofSize: self.segmentTextFontSize) : UIFont.systemFont(ofSize: self.segmentTextFontSize)
                layerText.font = CGFont(NSString(string:font.fontName))
                layerText.fontSize = font.pointSize
                layerText.frame = contentFrame
                layerText.alignmentMode = .center
                layerText.truncationMode = .end
                layerText.contentsScale = UIScreen.main.scale
                layerText.foregroundColor = index == self.selectedIndex ? self.segmentForegroundColorSelected.cgColor : self.segmentForegroundColor.cgColor
                layerContainer.addSublayer(layerText)
                segment.layerText = layerText
            case let .icon(icon):
                let layerIcon = CALayer()
                let image = icon
                layerIcon.frame = contentFrame
                layerIcon.contents = image.cgImage
                layerContainer.addSublayer(layerIcon)
                segment.layerIcon = layerIcon
            case let .attributed(text, normalColor, selectedColor):
                let layerText = CATextLayer()
                layerText.string = text
                let font = segmentTextBold ? UIFont.boldSystemFont(ofSize: self.segmentTextFontSize) : UIFont.systemFont(ofSize: self.segmentTextFontSize)
                layerText.font = CGFont(NSString(string:font.fontName))
                layerText.fontSize = font.pointSize
                layerText.frame = contentFrame
                layerText.alignmentMode = .center
                layerText.truncationMode = .end
                layerText.contentsScale = UIScreen.main.scale
                layerText.foregroundColor = index == self.selectedIndex ? selectedColor.cgColor : normalColor.cgColor
                layerContainer.addSublayer(layerText)
                segment.layerText = layerText
            }
        }

        // Add Indicator Layer
        let initLayerSeparator = { [unowned self] in
            let layerSeparator = CALayer()
            layerSeparator.frame = CGRect(x: 0, y: 0, width: self.scrollView.contentSize.width, height: self.scrollView.contentSize.height)
            layerSeparator.backgroundColor = self.separatorColor.cgColor

            let layerMask = CAShapeLayer()
            layerMask.fillColor = UIColor.white.cgColor
            let maskPath = UIBezierPath()
            for (index, segment) in self.innerSegments.enumerated() {
                index < self.innerSegments.count - 1 ? maskPath.append(UIBezierPath(rect: CGRect(x: segment.segmentFrame.maxX + self.separatorEdgeInsets.left, y: self.separatorEdgeInsets.top, width: self.separatorWidth - self.separatorEdgeInsets.left - self.separatorEdgeInsets.right, height: self.scrollView.frame.height - self.separatorEdgeInsets.top - self.separatorEdgeInsets.bottom))) : ()
            }
            layerMask.path = maskPath.cgPath
            layerSeparator.mask = layerMask
            self.layerContainer.addSublayer(layerSeparator)
        }
        let initLayerCover = { [unowned self] (settings: MBSegmentCoverSettings)in
            self.layerCover.frame = self.indicatorCoverFrame(settings, self.selectedIndex)
            self.layerCover.backgroundColor = settings.coverColor.cgColor
            self.layerCover.opacity = settings.coverOpacity
            self.layerContainer.addSublayer(self.layerCover)
        }
        
        let addLayerSlideway = { [unowned self] (slidewayPosition: CGFloat, slidewayHeight: CGFloat, slidewayColor: UIColor) in
            let layerSlideway = CALayer()
            layerSlideway.frame = CGRect(x: -1 * self.scrollView.frame.width, y: slidewayPosition - slidewayHeight / 2, width: self.scrollView.contentSize.width + self.scrollView.frame.width * 2, height: slidewayHeight)
            layerSlideway.backgroundColor = slidewayColor.cgColor
            self.layerContainer.addSublayer(layerSlideway)
        }
        
        let initLayerStrip = { [unowned self] (stripFrame: CGRect, stripColor: UIColor) in
            self.layerStrip.frame = stripFrame
            self.layerStrip.backgroundColor = stripColor.cgColor
            self.layerContainer.addSublayer(self.layerStrip)
        }
        
        switch self.style {
        case .cover(let settings):
            initLayerCover(settings)
            self.enableSeparator ? initLayerSeparator() : ()
        case .strip(let settings):
            let stripFrame = self.indicatorStripFrame(self.selectedIndex, stripHeight: settings.stripHeight, stripLocation: settings.stripLocation, stripRange: settings.stripRange)
            self.enableSlideway ? addLayerSlideway(stripFrame.midY, self.slidewayHeight, self.slidewayColor) : ()
            if settings.stripColors.isEmpty {
                initLayerStrip(stripFrame, settings.stripColor)
            } else {
                initLayerStrip(stripFrame, settings.stripColors.first!)
            }
            self.enableSeparator ? initLayerSeparator() : ()
        }
    }
    
    func resetLayer(layer: CALayer) {
        let frame = layer.frame
        
        let newFrame = CGRect(origin: frame.origin, size: CGSize(width: 0, height: frame.height))
        
        layer.frame = newFrame
    }

    // MARK: Custom methods
    func selectedIndexChanged(_ newIndex: Int, oldIndex: Int) {
        if self.enableAnimation && validIndex(oldIndex) {
            CATransaction.begin()
            CATransaction.setAnimationDuration(self.animationDuration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))
            self.scrollView.contentSize.width > self.scrollView.frame.width ? self.scrollToSegment(newIndex) : ()
            self.didSelectedIndexChanged(newIndex, oldIndex: oldIndex)
            CATransaction.commit()
        } else {
            self.didSelectedIndexChanged(newIndex, oldIndex: oldIndex)
        }

        self.sendActions(for: .valueChanged)
    }

    func didSelectedIndexChanged(_ newIndex: Int, oldIndex: Int) {
        switch style {
        case .cover(let settings):
            self.layerCover.actions = nil
            self.layerCover.frame = self.indicatorCoverFrame(settings, newIndex)
        case .strip(let settings):
            self.layerStrip.actions = nil
            self.layerStrip.frame = self.indicatorStripFrame(newIndex, stripHeight: settings.stripHeight, stripLocation: settings.stripLocation, stripRange: settings.stripRange)
            if !settings.stripColors.isEmpty {
                self.layerStrip.backgroundColor = settings.stripColors[newIndex % settings.stripColors.count].cgColor
            }
        }

        if validIndex(oldIndex) {
            switch self.innerSegments[oldIndex].content.type {
            case .text:
                if let oldContentLayer = self.innerSegments[oldIndex].layerText as? CATextLayer {
                    oldContentLayer.foregroundColor = self.segmentForegroundColor.cgColor
                }
            default:
                break
            }
        }
        switch self.innerSegments[newIndex].content.type {
        case .text:
            if let newContentLayer = self.innerSegments[newIndex].layerText as? CATextLayer {
                newContentLayer.foregroundColor = self.segmentForegroundColorSelected.cgColor
            }
        default:
            break
        }
    }

    func scrollToSegment(_ index: Int) {
        let segmentFrame = self.innerSegments[index].segmentFrame
        let targetRect = CGRect(x: segmentFrame.origin.x - (self.scrollView.frame.width - segmentFrame.width) / 2, y: 0, width: self.scrollView.frame.width, height: self.scrollView.frame.height)
        self.scrollView.scrollRectToVisible(targetRect, animated: true)
    }

    func segmentContentSize(_ segment: MBInnerSegment) -> CGSize {
        var size = CGSize.zero
        switch segment.content.type {
        case let .text(text):
            size = (text as NSString).size(withAttributes: [
                NSAttributedString.Key.font: segmentTextBold ? UIFont.boldSystemFont(ofSize: self.segmentTextFontSize) : UIFont.systemFont(ofSize: self.segmentTextFontSize)
                ])
        case let .icon(icon):
            size = icon.size
        case let .attributed(text, _, _):
            size = text.size()
        }
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }

    func segmentFrame(_ index: Int) -> CGRect {
        var segmentOffset: CGFloat = (self.enableSeparator ? self.separatorWidth / 2 : 0)
        for (idx, segment) in self.innerSegments.enumerated() {
            if idx == index {
                break
            } else {
                segmentOffset += segment.segmentWidth + (self.enableSeparator ? self.separatorWidth : 0)
            }
        }
        return CGRect(x: segmentOffset , y: 0, width: self.innerSegments[index].segmentWidth, height: self.scrollView.frame.height)
    }

    func indicatorCoverFrame(_ settings: MBSegmentCoverSettings, _ index: Int) -> CGRect {
        if validIndex(index) {
            var boxX: CGFloat = self.innerSegments[index].segmentFrame.origin.x
            var boxWidth: CGFloat = 0
            switch settings.coveRange {
            case .content:
                boxX += (self.innerSegments[index].segmentWidth - self.innerSegments[index].contentSize.width) / 2
                boxWidth = self.innerSegments[index].contentSize.width
            case .segment:
                boxWidth = self.innerSegments[index].segmentWidth
            }
            return CGRect(x: boxX, y: 0, width: boxWidth, height: self.scrollView.frame.height)
        } else {
            return CGRect.zero
        }
    }

    func indicatorStripFrame(_ index: Int, stripHeight: CGFloat, stripLocation: MBSegmentIndicatorLocation, stripRange: MBSegmentIndicatorRange) -> CGRect {
        if validIndex(index) {
            var stripX: CGFloat = self.innerSegments[index].segmentFrame.origin.x
            var stripY: CGFloat = 0
            var stripWidth: CGFloat = 0
            switch stripLocation {
            case .down:
                stripY = self.innerSegments[index].segmentFrame.height - stripHeight
            case .up:
                stripY = 0
            }
            switch stripRange {
            case .content:
                stripWidth = self.innerSegments[index].contentSize.width
                stripX += (self.innerSegments[index].segmentWidth - stripWidth) / 2
            case .segment:
                stripWidth = self.innerSegments[index].segmentWidth
            }
            return CGRect(x: stripX, y: stripY, width: stripWidth, height: stripHeight)
        } else {
            return CGRect.zero
        }
    }

    func indexForTouch(_ location: CGPoint) -> Int {
        var touchOffsetX = location.x
        var touchIndex = 0
        for (index, segment) in self.innerSegments.enumerated() {
            touchOffsetX -= segment.segmentWidth + (self.enableSeparator ? self.separatorWidth : 0)
            if touchOffsetX < 0 {
                touchIndex = index
                break
            }
        }
        return touchIndex
    }

    func validIndex(_ index: Int) -> Bool {
        return index >= 0 && index < segments.count
    }
}

extension MBSegmentControl: MBTouchViewDelegate {
    public func didTouch(_ location: CGPoint) {
        selectedIndex = indexForTouch(location)
    }
}

class MBInnerSegment {

    let content: MBSegmentContentProtocol

    var segmentFrame: CGRect = CGRect.zero
    var segmentWidth: CGFloat = 0
    var contentSize: CGSize = CGSize.zero

    var layerText: CALayer!
    var layerIcon: CALayer!
    var layerStrip: CALayer!

    init(content: MBSegmentContentProtocol) {
        self.content = content
    }
}

public enum MBSegmentType {
    case text(String)
    case icon(UIImage)
    case attributed(NSAttributedString, UIColor, UIColor)
}

public struct MBSegmentCoverSettings {
    public typealias CoverRange = MBSegmentIndicatorRange

    public var coveRange: CoverRange = .segment
    public var coverOpacity: Float = 0.2
    public var coverColor: UIColor = UIColor.black
    
    public init() {
        
    }
}

public struct MBSegmentStripSettings {
    public typealias StripRange = MBSegmentIndicatorRange
    public typealias StripLocation = MBSegmentIndicatorLocation

    public var stripRange: StripRange = .content
    public var stripLocation: StripLocation = .down
    public var stripColor: UIColor = UIColor.orange
    public var stripColors: [UIColor] = []
    public var stripHeight: CGFloat = 3
    
    public init() {
        
    }
}

public enum MBSegmentIndicatorStyle {
    case cover(MBSegmentCoverSettings), strip(MBSegmentStripSettings)
}

public enum MBSegmentIndicatorLocation {
    case up, down
}

public enum MBSegmentIndicatorRange {
    case content, segment
}

public enum MBSegmentNonScrollDistributionStyle {
    case center, left, right, average
}

class MBTouchView: UIView {

    weak var delegate: MBTouchViewDelegate?

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if let touch = touches.first {
            delegate?.didTouch(touch.location(in: self))
        }
    }
}
