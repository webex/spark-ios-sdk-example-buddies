//
//  BDImageModel.swift
//  Buddies
//
//  Created by qucui on 2018/3/29.
//  Copyright © 2018年 spark-ios-sdk. All rights reserved.
//

import UIKit
import Photos
class BDAssetModel: NSObject {
    var isSelected: Bool = false
    var asset: PHAsset
    var image: UIImage?
    var localFileUrl : String?
    
    init(asset: PHAsset){
        self.asset = asset
        super.init()
    }
}
