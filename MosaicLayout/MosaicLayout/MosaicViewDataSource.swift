//
//  MosaicViewDataSource.swift
//  MosaicLayout
//
//  Created by Jeff Kereakoglow on 10/11/15.
//  Copyright © 2015 Alexis Digital. All rights reserved.
//

import UIKit

class MosaicViewDataSource: NSObject {
  let viewController: MosaicViewController

  init(viewController vc: MosaicViewController) {
    viewController = vc
  }
}

extension MosaicViewDataSource: UICollectionViewDataSource {
  func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return 0
  }

  func collectionView(
    collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath
    ) -> UICollectionViewCell {
    return collectionView.dequeueReusableCellWithReuseIdentifier("cell", forIndexPath: indexPath)
  }
}