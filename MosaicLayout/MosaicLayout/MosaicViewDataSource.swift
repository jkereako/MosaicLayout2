//
//  MosaicViewDataSource.swift
//  MosaicLayout
//
//  Created by Jeff Kereakoglow on 10/11/15.
//  Copyright © 2015 Alexis Digital. All rights reserved.
//

import UIKit

class MosaicViewDataSource: NSObject {
  var dataSource: Dictionary<String, Array<Int>>
  let viewController: MosaicViewController

  init(viewController vc: MosaicViewController) {
    viewController = vc
    dataSource = ["numbers":Array<Int>(), "height":Array<Int>(), "width":Array<Int>()]

    super.init()

    for index in 0..<15 {
      dataSource["numbers"]!.append(index)
      dataSource["height"]!.append(self.generateInteger())
      dataSource["width"]!.append(self.generateInteger())
    }

  }

  func colorForInt(int: Int) -> UIColor {
    let float = CGFloat(int)

    return UIColor(hue:((19.0 * float) % 255.0)/255.0, saturation: 1.0, brightness: 1.0, alpha: 1.0)
  }

  private func generateInteger() -> Int {
    switch arc4random() % 6 {
      // 1/2 chance of it being 1.
    case 0...2:
      return 1
      // 1/6 chance of it being 3.
    case 5:
      return 3
      // 1/3 chance of it being 2.
    default:
      return 2
    }
  }
}

extension MosaicViewDataSource: UICollectionViewDataSource {
  func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    if let numbers = dataSource["numbers"] {
      return numbers.count
    }

    return 0
  }

  func collectionView(
    collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath
    ) -> UICollectionViewCell {

      let cell = collectionView.dequeueReusableCellWithReuseIdentifier(
        "cell", forIndexPath: indexPath
      )

      cell.backgroundColor =  colorForInt(indexPath.row)

      return cell
  }
}
