//
//  TopScrollView.swift
//  ScrollViewController
//
//  Created by jasnig on 16/4/6.
//  Copyright © 2016年 ZeroJ. All rights reserved.
//

import UIKit


struct SegmentStyle {
    /// 是否显示遮盖
    var showCover = true
    /// 是否显示下划线
    var showLine = true
    /// 是否缩放文字
    var scaleTitle = true
    /// 是否可以滚动标题
    var scrollTitle = true
    /// 是否颜色渐变
    var gradualChangeTitleColor = true
    
    /// 下面的滚动条的高度
    var scrollLineHeight: CGFloat = 2
    /// 下面的滚动条的颜色
    var scrollLineColor = UIColor.brownColor()
    
    /// 遮盖的背景颜色
    var coverBackgroundColor = UIColor.lightTextColor()
    /// 遮盖圆角
    var coverCornerRadius = 14.0
    
    /// cover的高度
    var coverHeight: CGFloat = 28.0
    /// 文字间的间隔
    var titleMargin: CGFloat = 15
    /// 文字 字体
    var titleFont = UIFont.systemFontOfSize(14.0)
    
    /// 放大倍数
    var titleBigScale: CGFloat = 1.3
    /// 默认倍数 不可修改
    let titleOriginalScale: CGFloat = 1.0
    
    /// 文字正常状态颜色 请使用RGB空间的颜色值!!
    var normalTitleColor = UIColor.greenColor()
    /// 文字选中状态颜色 请使用RGB空间的颜色值!!
    var selectedTitleColor = UIColor.blueColor()

}


class TopScrollView: UIView {
    
    
    /**
     之前使用在titles的didSet里面添加label和计算label的文字宽度,
     然后在layoutSubview()里面设置各个label和cover scrollline的frame,
     但是总是导致,默认缩放的label的文字显示不完整,
     修改未在初始化方法里面来设置frame并且设置transform后就可以正常显示了
     
     */
    
    /// 所有的title设置
    var segmentStyle: SegmentStyle
    
    /// 点击响应的blosure
    var titleBtnOnClick:((label: UILabel, index: Int) -> Void)?
    
    /// self.bounds.size.width
    private var currentWidth: CGFloat = 0
    /// 遮盖x和文字x的间隙
    private var xGap = 5
    /// 遮盖宽度比文字宽度多的部分
    private var wGap: Int {
        return 2 * xGap
    }

    /// 缓存标题labels
    private var labelsArray: [UILabel] = []
    /// 记录当前选中的下标
    private var currentIndex = 0
    /// 记录上一个下标
    private var oldIndex = 0
    /// 用来缓存所有标题的宽度, 达到根据文字的字数和font自适应控件的宽度
    private var titlesWidthArray: [CGFloat] = []
    /// 所有的标题
    var titles:[String]
    
    private lazy var scrollView: UIScrollView = {[weak self] in
        let scrollV = UIScrollView()
        scrollV.showsHorizontalScrollIndicator = false
        scrollV.bounces = true
        scrollV.pagingEnabled = false
        return scrollV
        
    }()
    
//    var selectedIndex = 0 {
//        didSet {
//            for (index, label) in labelsArray.enumerate() {
//                if index == selectedIndex {
//                    label.transform = CGAffineTransformMakeScale(1.3, 1.3)
//                }
//            }
//        }
//    }

    private lazy var scrollLine: UIView? = {[unowned self] in
        let line = UIView()
        return self.segmentStyle.showLine ? line : nil
    }()

    private lazy var coverLayer: UIView? = {[unowned self] in
        let cover = UIView()
        cover.layer.cornerRadius = CGFloat(self.segmentStyle.coverCornerRadius)
        // 这里只有一个cover 需要设置圆角, 故不用考虑离屏渲染的消耗, 直接设置 masksToBounds 来设置圆角
        cover.layer.masksToBounds = true
//        cover.backgroundColor = self.segmentStyle.coverBackgroundColor
        
        return self.segmentStyle.showCover ? cover : nil
    
    }()
    
    /// 懒加载颜色的rgb变化值, 不要每次滚动时都计算
    private lazy var rgbDelta: (deltaR: Int, deltaG: Int, deltaB: Int) = {[unowned self] in
        let normalColorRgb = self.normalColorRgb
        let selectedTitleColorRgb = self.selectedTitleColorRgb
        let deltaR = normalColorRgb.r - selectedTitleColorRgb.r
        let deltaG = normalColorRgb.g - selectedTitleColorRgb.g
        let deltaB = normalColorRgb.b - selectedTitleColorRgb.b
        
        return (deltaR: deltaR, deltaG: deltaG, deltaB: deltaB)
    }()
    
    /// 懒加载颜色的rgb变化值, 不要每次滚动时都计算
    private lazy var normalColorRgb: (r: Int, g: Int, b: Int) = self.getColorRGB(self.segmentStyle.normalTitleColor)!
    private lazy var selectedTitleColorRgb: (r: Int, g: Int, b: Int) = self.getColorRGB(self.segmentStyle.selectedTitleColor)!
    
    private func getColorRGB(color: UIColor) -> (r: Int, g: Int, b: Int)? {
        let colorString = String(color)
        let colorArr = colorString.componentsSeparatedByString(" ")
        guard let r = Int(colorArr[1]), let g = Int(colorArr[2]), let b = Int(colorArr[3]) else {
            return nil
        }
        return (r: r, g: g, b: b)
        
    }

    
    /// 初始化的过程中做了太多的事了 !!!!!!
    init(frame: CGRect, segmentStyle: SegmentStyle, titles: [String]) {
        self.segmentStyle = segmentStyle
        self.titles = titles
        super.init(frame: frame)
        if !self.segmentStyle.scrollTitle { // 不能滚动的时候就不要把缩放和遮盖或者滚动条同时使用, 否则显示效果不好

            self.segmentStyle.scaleTitle = (!self.segmentStyle.showCover || !self.segmentStyle.showLine)
        }
        // 设置了frame之后可以直接设置其他的控件的frame了, 不需要在layoutsubView()里面设置
        setupTitles()
        setupUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupTitles() {
        for (index, title) in titles.enumerate() {
            
            let label = CustomLabel(frame: CGRectZero)
            label.tag = index
            label.text = title
            label.textColor = segmentStyle.normalTitleColor
            label.font = segmentStyle.titleFont
            label.textAlignment = .Center
            label.userInteractionEnabled = true
            
            let tapGes = UITapGestureRecognizer(target: self, action: #selector(self.titleLabelOnClick(_:)))
            label.addGestureRecognizer(tapGes)
            
            let size = (title as NSString).boundingRectWithSize(CGSizeMake(CGFloat(MAXFLOAT), 0.0), options: .UsesLineFragmentOrigin, attributes: [NSFontAttributeName: label.font], context: nil)
            
            titlesWidthArray.append(size.width)
            labelsArray.append(label)
            scrollView.addSubview(label)
        }
    }
    
    func setupUI() {
        currentWidth = bounds.size.width
        scrollView.frame = bounds
        addSubview(scrollView)
        // 先设置label的位置
        setUpLabelsPosition()
        // 再设置滚动条和cover的位置
        setupScrollLineAndCover()
        
        if segmentStyle.scrollTitle { // 设置滚动区域
            if let lastLabel = labelsArray.last {
                scrollView.contentSize = CGSize(width: CGRectGetMaxX(lastLabel.frame) + segmentStyle.titleMargin, height: 0)
                
            }
        }

    }
    
    // 先设置label的位置
    private func setUpLabelsPosition() {
        var titleX: CGFloat = 0.0
        let titleY: CGFloat = 0.0
        var titleW: CGFloat = 0.0
        let titleH = bounds.size.height - segmentStyle.scrollLineHeight
        
        if !segmentStyle.scrollTitle {// 标题不能滚动, 平分宽度
            titleW = currentWidth / CGFloat(titles.count)
        
            for (index, label) in labelsArray.enumerate() {
                
                titleX = CGFloat(index) * titleW
                
                label.frame = CGRect(x: titleX, y: titleY, width: titleW, height: titleH)
                

            }
            
        } else {
            
            for (index, label) in labelsArray.enumerate() {
                titleW = titlesWidthArray[index]
                
                titleX = segmentStyle.titleMargin
                if index != 0 {
                    let lastLabel = labelsArray[index - 1]
                    titleX = CGRectGetMaxX(lastLabel.frame) + segmentStyle.titleMargin
                }
                label.frame = CGRect(x: titleX, y: titleY, width: titleW, height: titleH)

            }
            
        }
        
        // FIXME: 这里目前只是默认设置第一个label为初始的label, 修改为可指定为任意的...
        if let firstLabel = labelsArray[0] as? CustomLabel {
            
            // 缩放, 设置初始的label的transform
            if segmentStyle.scaleTitle {
                // 如果是在layoutSubview()里面设置使用的transform后label的frame不会改变
                firstLabel.transform = CGAffineTransformMakeScale(segmentStyle.titleBigScale , segmentStyle.titleBigScale)
                firstLabel.currentTransformSx = segmentStyle.titleBigScale
            }
            // 设置初始状态文字的颜色
            firstLabel.textColor = segmentStyle.selectedTitleColor
        }

        
    }
    
    // 再设置滚动条和cover的位置
    private func setupScrollLineAndCover() {
        if let line = scrollLine {
            line.backgroundColor = segmentStyle.scrollLineColor
            scrollView.addSubview(line)
            
        }
        if let cover = coverLayer {
            cover.backgroundColor = segmentStyle.coverBackgroundColor
            scrollView.insertSubview(cover, atIndex: 0)
            
        }
        let coverX = labelsArray[0].frame.origin.x
        let coverW = labelsArray[0].frame.size.width
        let coverH: CGFloat = segmentStyle.coverHeight
        let coverY = (bounds.size.height - coverH) / 2
        if segmentStyle.scrollTitle {
            // 这里x-xGap width+wGap 是为了让遮盖的左右边缘和文字有一定的距离
            coverLayer?.frame = CGRect(x: coverX - CGFloat(xGap), y: coverY, width: coverW + CGFloat(wGap), height: coverH)
        } else {
            coverLayer?.frame = CGRect(x: coverX + CGFloat(xGap), y: coverY, width: coverW - CGFloat(wGap), height: coverH)
        }

        scrollLine?.frame = CGRect(x: coverX, y: bounds.size.height - segmentStyle.scrollLineHeight, width: coverW, height: segmentStyle.scrollLineHeight)

        
    }
    // 点击时直接实现变化
    func titleLabelOnClick(tapGes: UITapGestureRecognizer) {
        guard let currentLabel = tapGes.view as? CustomLabel else { return }
        currentIndex = currentLabel.tag
        if currentIndex == oldIndex { return }
        
        adjustTitleOffSetToCurrentIndex(currentIndex)
        
        UIView.animateWithDuration(0.3) {[unowned self] in
            let oldLabel = self.labelsArray[self.oldIndex] as! CustomLabel
            
            // 设置文字颜色
            oldLabel.textColor = self.segmentStyle.normalTitleColor
            currentLabel.textColor = self.segmentStyle.selectedTitleColor

            // 缩放文字
            if self.segmentStyle.scaleTitle {
                oldLabel.transform = CGAffineTransformIdentity
                oldLabel.currentTransformSx = self.segmentStyle.titleOriginalScale
                
                currentLabel.transform = CGAffineTransformMakeScale(self.segmentStyle.titleBigScale, self.segmentStyle.titleBigScale)
                currentLabel.currentTransformSx = self.segmentStyle.titleBigScale
                
            }
            
            
            // 设置滚动条的位置
            self.scrollLine?.frame.origin.x = currentLabel.frame.origin.x
            // 注意, 通过bounds 获取到的width 是没有进行transform之前的 所以使用frame
            self.scrollLine?.frame.size.width = currentLabel.frame.size.width
            
            // 设置遮盖位置
            if self.segmentStyle.scrollTitle {
                self.coverLayer?.frame.origin.x = currentLabel.frame.origin.x - CGFloat(self.xGap)
                self.coverLayer?.frame.size.width = currentLabel.frame.size.width + CGFloat(self.wGap)
            } else {
                self.coverLayer?.frame.origin.x = currentLabel.frame.origin.x + CGFloat(self.xGap)
                self.coverLayer?.frame.size.width = currentLabel.frame.size.width - CGFloat(self.wGap)
            }
            
        }
        oldIndex = currentIndex
        
        titleBtnOnClick?(label: currentLabel, index: currentIndex)
    }
        
    // 手动滚动时需要提供动画效果
    func adjustUIWithProgress(progress: CGFloat,  oldIndex: Int, currentIndex: Int) {
        // 记录当前的currentIndex以便于在点击的时候处理
        self.oldIndex = currentIndex
        
//        print("\(currentIndex)------------currentIndex")

        let oldLabel = labelsArray[oldIndex] as! CustomLabel
        let currentLabel = labelsArray[currentIndex] as! CustomLabel
        
        // 需要改变的距离 和 宽度
        let xDistance = currentLabel.frame.origin.x - oldLabel.frame.origin.x
        let wDistance = currentLabel.frame.size.width - oldLabel.frame.size.width
        
        // 设置滚动条位置
        scrollLine?.frame.origin.x = oldLabel.frame.origin.x + xDistance * progress
        scrollLine?.frame.size.width = oldLabel.frame.size.width + wDistance * progress
        
        // 设置 cover位置
        if segmentStyle.scrollTitle {
            coverLayer?.frame.origin.x = oldLabel.frame.origin.x + xDistance * progress - CGFloat(xGap)
            coverLayer?.frame.size.width = oldLabel.frame.size.width + wDistance * progress + CGFloat(wGap)
        } else {
            coverLayer?.frame.origin.x = oldLabel.frame.origin.x + xDistance * progress + CGFloat(xGap)
            coverLayer?.frame.size.width = oldLabel.frame.size.width + wDistance * progress - CGFloat(wGap)
        }
        
        // 文字颜色渐变
        if segmentStyle.gradualChangeTitleColor {
            
            oldLabel.textColor = UIColor(red:CGFloat(selectedTitleColorRgb.r) + CGFloat(rgbDelta.deltaR) * progress, green: CGFloat(selectedTitleColorRgb.g) + CGFloat(rgbDelta.deltaG) * progress, blue: CGFloat(selectedTitleColorRgb.b) + CGFloat(rgbDelta.deltaB) * progress, alpha: 1.0)

            currentLabel.textColor = UIColor(red:CGFloat(normalColorRgb.r) - CGFloat(rgbDelta.deltaR) * progress, green: CGFloat(normalColorRgb.g) - CGFloat(rgbDelta.deltaG) * progress, blue: CGFloat(normalColorRgb.b) - CGFloat(rgbDelta.deltaB) * progress, alpha: 1.0)
            
            
        }
        
        // 缩放文字
        if !segmentStyle.scaleTitle {
            return
        }
        
        // 注意左右间的比例是相关连的, 加减相同
        // 设置文字缩放
        let deltaScale = (segmentStyle.titleBigScale - segmentStyle.titleOriginalScale)
        
        oldLabel.currentTransformSx = segmentStyle.titleBigScale - deltaScale * progress
        currentLabel.currentTransformSx = segmentStyle.titleOriginalScale + deltaScale * progress

        oldLabel.transform = CGAffineTransformMakeScale(oldLabel.currentTransformSx, oldLabel.currentTransformSx)
        currentLabel.transform = CGAffineTransformMakeScale(currentLabel.currentTransformSx, currentLabel.currentTransformSx)

        
    }
    // 居中显示title
    func adjustTitleOffSetToCurrentIndex(currentIndex: Int) {

        print(currentIndex)
        let currentLabel = labelsArray[currentIndex]

        var offSetX = currentLabel.center.x - currentWidth / 2
        if offSetX < 0 {
            offSetX = 0
        }
        
        var maxOffSetX = scrollView.contentSize.width - currentWidth
        
        // 可以滚动的区域小余屏幕宽度
        if maxOffSetX < 0 {
            maxOffSetX = 0
        }
        
        if offSetX > maxOffSetX {
            offSetX = maxOffSetX
        }
        
        scrollView.setContentOffset(CGPoint(x:offSetX, y: 0), animated: true)
    }

}


class CustomLabel: UILabel {
    /// 用来记录当前label的缩放比例
    var currentTransformSx:CGFloat = 1.0
}

