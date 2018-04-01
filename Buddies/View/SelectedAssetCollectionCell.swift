//
//  SelectedImgCollectionCell.swift
//  Buddies
//
//  Created by qucui on 2018/3/29.
//  Copyright © 2018年 spark-ios-sdk. All rights reserved.
//

import UIKit
import Photos
class SelectedAssetCollectionCell: UICollectionViewCell {
    private let color1 = UIColor(displayP3Red: 0, green: 0, blue: 0, alpha: 0.3)
    private let color2 = UIColor(displayP3Red: 0, green: 0, blue: 0, alpha: 0.6)
    private let X : CGFloat = 2.5
    private let Y : CGFloat = 2.5
    private var width : CGFloat = 0
    private var height : CGFloat = 0
    private var choosed: Bool = false
    
    var imageView : UIImageView?
    var maskLayer : CAGradientLayer?
    var cancelImageView : UIImageView?
    var assetModel : BDAssetModel?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.width = self.frame.size.width
        self.height = self.frame.size.height
    }
    
    public func updateImageCell(_ asset: BDAssetModel){
        self.assetModel = asset
        if let imageView = self.imageView{
            imageView.removeFromSuperview()
            self.maskLayer?.removeFromSuperlayer()
        }
        
//        let manager = PHImageManager.default()
//        manager.requestImage(for: (self.assetModel?.asset)!, targetSize: CGSize(width: inputViewHeight, height: inputViewHeight), contentMode: .aspectFill, options: nil) { (result, _) in
            self.imageView = UIImageView(image: self.assetModel?.image)
            self.imageView?.layer.masksToBounds = true
            self.imageView?.layer.cornerRadius = 12
            self.imageView?.frame = CGRect(self.X, self.Y, self.width-5, self.height-5)
            self.addSubview(self.imageView!)
            self.layer.masksToBounds = true
            
            self.maskLayer = CAGradientLayer()
            self.maskLayer?.frame = CGRect(0, 0, self.width, self.height)
            self.maskLayer?.colors = [self.color1.cgColor,self.color2.cgColor]
            self.maskLayer?.locations = [0,1.0]
            self.maskLayer?.startPoint = CGPoint(0.5, 0);
            self.maskLayer?.endPoint = CGPoint(0.5, 1.0);
            self.imageView?.layer.addSublayer(self.maskLayer!)
            self.choosed = self.isSelected
//        }
        
        self.cancelImageView = UIImageView(frame: CGRect(width-25,5,20.0,20.0))
        self.cancelImageView?.image = UIImage(named:"icon_cancel")
        self.cancelImageView?.layer.cornerRadius = 10
        self.cancelImageView?.layer.borderWidth = 2.0
        self.cancelImageView?.layer.borderColor = UIColor.white.cgColor
        self.cancelImageView?.backgroundColor = UIColor.white
        self.addSubview(self.cancelImageView!)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
