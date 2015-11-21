//
//  MosaicViewController.swift
//  MosaicLayout
//
//  Created by Jeff Kereakoglow on 10/11/15.
//  Copyright © 2015 Alexis Digital. All rights reserved.
//

import UIKit

class MosaicViewController: UICollectionViewController {
  private var viewModel: MosaicViewDataSource?

  override func viewDidLoad() {
    super.viewDidLoad()

    viewModel = MosaicViewDataSource(viewController: self)
    collectionView?.dataSource = viewModel

    if let cv = collectionView, let layout = cv.collectionViewLayout as? MosaicLayout {
      layout.blockPixels = CGSizeMake(75, 75)
      layout.delegate = self
      cv.reloadData()
    }
/*
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"cell"];

    RFQuiltLayout* layout = (id)[self.collectionView collectionViewLayout];
    layout.direction = UICollectionViewScrollDirectionVertical;
    layout.blockPixels = CGSizeMake(75,75);

    [self.collectionView reloadData];
*/
  }
}

extension MosaicViewController: MosaicLayoutDelegate {
  func blockSize(
    collectionView collectionView: UICollectionView, layout: UICollectionViewLayout, indexPath: NSIndexPath
    ) -> CGSize {

      guard let model = viewModel,
        let numbers = model.dataSource["numbers"] where numbers.count > indexPath.row else {
          fatalError("Asking for index paths of non-existant cells!")
      }

      if let w =  model.dataSource["width"], let h =  model.dataSource["height"] {
        return CGSizeMake(CGFloat(w[indexPath.row]), CGFloat(h[indexPath.row]))
      }

      return CGSizeZero
  }

  func edgeInsets(
    collectionView collectionView: UICollectionView, layout: UICollectionViewLayout, indexPath: NSIndexPath
    ) -> UIEdgeInsets {
      return UIEdgeInsetsZero
  }
}
