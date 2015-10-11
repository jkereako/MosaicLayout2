//
//  MosaicViewController.swift
//  MosaicLayout
//
//  Created by Jeff Kereakoglow on 10/11/15.
//  Copyright © 2015 Alexis Digital. All rights reserved.
//

import UIKit

class MosaicViewController: UICollectionViewController {
  override func viewDidLoad() {
    super.viewDidLoad()

    let viewModel = MosaicViewDataSource(viewController: self)
    collectionView?.dataSource = viewModel
  }
}
