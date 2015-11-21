//
//  MosaicLayout.swift
//  MosaicLayout
//
//  Created by Jeff Kereakoglow on 10/11/15.
//  Copyright © 2015 Alexis Digital. All rights reserved.
//

import UIKit

protocol MosaicLayoutDelegate: UICollectionViewDelegate {
  func blockSize(
    collectionView collectionView: UICollectionView, layout: UICollectionViewLayout, indexPath: NSIndexPath
    ) -> CGSize

  func edgeInsets(
    collectionView collectionView: UICollectionView, layout: UICollectionViewLayout, indexPath: NSIndexPath
    ) -> UIEdgeInsets
}

class MosaicLayout: UICollectionViewLayout {
  weak var delegate: MosaicLayoutDelegate?
  let scrollDirection: UICollectionViewScrollDirection
  var blockPixels: CGSize

  private var furthestBlockPoint: CGPoint

  private var prelayoutEverything: Bool
  // previous layout cache.
  // this is to prevent choppiness when we scroll to the bottom of the screen - uicollectionview
  // will repeatedly call layoutattributesforelementinrect on each scroll event.  pow!
  private var previousLayoutRect: CGRect
  private var previousLayoutAttributes: Array<UICollectionViewLayoutAttributes>

  // remember the last indexpath placed, as to not
  // relayout the same indexpaths while scrolling
  private var lastIndexPathPlaced: NSIndexPath?

  private var firstOpenSpace: CGPoint

  private var indexPathByPosition: Array<Array<NSIndexPath>>
  private var positionByIndexPath: Array<Array<NSValue>>

  override init() {
    scrollDirection = .Vertical
    blockPixels = CGSizeMake(100.0, 100.0)
    furthestBlockPoint = CGPointMake(0, 0)
    previousLayoutRect = CGRectMake(0.0, 0.0, 0.0, 0.0)
    delegate = nil
    previousLayoutRect = CGRectZero
    prelayoutEverything = false
    firstOpenSpace = CGPointZero
    previousLayoutAttributes = Array<UICollectionViewLayoutAttributes>()
    indexPathByPosition = Array<Array<NSIndexPath>>()
    positionByIndexPath = Array<Array<NSValue>>()
    super.init()
  }

  required init?(coder aDecoder: NSCoder) {
    scrollDirection = .Vertical
    blockPixels = CGSizeMake(100.0, 100.0)
    furthestBlockPoint = CGPointMake(0, 0)
    previousLayoutRect = CGRectMake(0.0, 0.0, 0.0, 0.0)
    previousLayoutRect = CGRectZero
    firstOpenSpace = CGPointZero
    previousLayoutAttributes = Array<UICollectionViewLayoutAttributes>()
    delegate = nil
    indexPathByPosition = Array<Array<NSIndexPath>>()
    positionByIndexPath = Array<Array<NSValue>>()
    prelayoutEverything = false

    super.init(coder: aDecoder)
  }

  private func initialize() {

  }

  // MARK:- UICollectionViewLayout
  override func prepareLayout() {
    super.prepareLayout()

    guard delegate != nil, let cv = collectionView else {
      return
    }

    let scrollFrame = CGRectMake(
      cv.contentOffset.x, cv.contentOffset.y, cv.frame.size.width, cv.frame.size.height
    )

    let unrestrictedRow: Int

    switch scrollDirection {
    case .Vertical:
      unrestrictedRow = Int((CGRectGetMaxY(scrollFrame) / blockPixels.height) + 1.0)
    case .Horizontal:
      unrestrictedRow = Int((CGRectGetMaxX(scrollFrame) / blockPixels.width) + 1.0)
    }

    fillInBlocks(endRow: unrestrictedRow)
  }

  override func prepareForCollectionViewUpdates(updateItems: [UICollectionViewUpdateItem]) {
    super.prepareForCollectionViewUpdates(updateItems)

    for item in updateItems {
      switch item.updateAction {
      case .Insert, .Move:
        fillInBlocks(indexPath: item.indexPathAfterUpdate)
      default:
        break
      }
    }
  }

  override func collectionViewContentSize() -> CGSize {
    guard let cv = collectionView else {
      fatalError("Collection view is not accessible.")
    }

    let contentRect = UIEdgeInsetsInsetRect(cv.frame, cv.contentInset)

    switch scrollDirection {
    case .Vertical:
      return CGSizeMake(
        CGRectGetWidth(contentRect), (furthestBlockPoint.y + 1) * blockPixels.height
      )
    case .Horizontal:
      return CGSizeMake(
        (furthestBlockPoint.x + 1) * blockPixels.width, CGRectGetHeight(contentRect)
      )
    }
  }

  override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
    var insets = UIEdgeInsetsZero

    if let cv = collectionView, d = delegate {
      insets = d.edgeInsets(collectionView: cv, layout: self, indexPath: indexPath)
    }

    let frame = frameForIndexPath(indexPath)
    let attributes = UICollectionViewLayoutAttributes(forCellWithIndexPath: indexPath)
    attributes.frame = UIEdgeInsetsInsetRect(frame, insets)
    return attributes
  }

  override func layoutAttributesForElementsInRect(rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    guard delegate != nil  else {
      return []
    }

    if CGRectEqualToRect(rect, previousLayoutRect) {
      return previousLayoutAttributes
    }

    previousLayoutRect = rect

    let unrestrictedDimensionStart: CGFloat
    let unrestrictedDimensionLength: CGFloat

    switch scrollDirection {
    case .Vertical:
      unrestrictedDimensionStart = rect.origin.y / blockPixels.height
      unrestrictedDimensionLength = rect.size.height / self.blockPixels.height
    case .Horizontal:
      unrestrictedDimensionStart = rect.origin.x / self.blockPixels.width
      unrestrictedDimensionLength = (rect.size.width / self.blockPixels.width) + 1.0
    }

    let unrestrictedDimensionEnd = Int(unrestrictedDimensionStart + unrestrictedDimensionLength)

    fillInBlocks(endRow: unrestrictedDimensionEnd)

    var attributes = Set<UICollectionViewLayoutAttributes>()

    traverseTilesBetweenUnrestrictedDimension(
      start: Int(unrestrictedDimensionStart),
      end: Int(unrestrictedDimensionEnd),
      callback: { [unowned self] (let point: CGPoint) in
        if let ip = self.indexPathForPosition(point: point),
          let attr = self.layoutAttributesForItemAtIndexPath(ip){
            attributes.insert(attr)
        }

        return true
      }
    )

    previousLayoutAttributes = Array(attributes)

    return previousLayoutAttributes
  }

  override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {

    return !(CGSizeEqualToSize(newBounds.size, collectionView?.frame.size ?? CGSizeZero))
  }

  override func invalidateLayout() {
    super.invalidateLayout()

    furthestBlockPoint = CGPointZero
    firstOpenSpace = CGPointZero
    previousLayoutRect = CGRectZero
    previousLayoutAttributes = Array<UICollectionViewLayoutAttributes>()
    lastIndexPathPlaced = nil
    // REVIEW
    indexPathByPosition = Array<Array<NSIndexPath>>()
    positionByIndexPath = Array<Array<NSValue>>()
  }

  // MARK:- Helpers
  func indexPathForPosition(point point: CGPoint) -> NSIndexPath? {
    let unrestrictedPoint: Int
    let restrictedPoint: Int

    switch scrollDirection {
    case .Vertical:
      unrestrictedPoint = Int(point.y)
      restrictedPoint = Int(point.x)

    case .Horizontal:
      unrestrictedPoint = Int(point.x)
      restrictedPoint = Int(point.y)
    }

    // REVIEW: Infinite loop
    guard indexPathByPosition.indices ~= restrictedPoint &&
      indexPathByPosition[restrictedPoint].indices ~= unrestrictedPoint else {
        return nil
    }

    return indexPathByPosition[restrictedPoint][unrestrictedPoint]
  }

  func fillInBlocks(indexPath indexPath: NSIndexPath) {
    // we'll have our data structure as if we're planning
    // a vertical layout, then when we assign positions to
    // the items we'll invert the axis
    let sections = collectionView?.numberOfSections() ?? 0

    for var section = lastIndexPathPlaced?.section ?? 0; section < sections; ++section {
      let rows = collectionView?.numberOfItemsInSection(section)
      let row = lastIndexPathPlaced?.row ?? 0

      for var aRow = row + 1; row < rows; ++aRow {
        guard section < indexPath.section && aRow < indexPath.row else {
          return
        }

        let newIndexPath = NSIndexPath(forRow: aRow, inSection: section)

        if placeBlock(indexPath: newIndexPath) {
          lastIndexPathPlaced = newIndexPath
        }
      }
    }
  }

  private func frameForIndexPath(indexPath: NSIndexPath) -> CGRect {
    let position = positionForIndexPath(indexPath)
    let elementSize = blockSize(indexPath: indexPath)
    let contentRect = UIEdgeInsetsInsetRect(
      collectionView?.frame ?? CGRectZero, collectionView?.contentInset ?? UIEdgeInsetsZero
    )
    let dimensions = CGFloat(restrictedDimensionBlockSize())

    switch scrollDirection {
    case .Vertical:
      let initialPaddingForContraintedDimension = (CGRectGetWidth(contentRect) - dimensions * blockPixels.width) / 2
      return CGRectMake(position.x * blockPixels.width + initialPaddingForContraintedDimension,
        position.y * blockPixels.height,
        elementSize.width * blockPixels.width,
        elementSize.height *  blockPixels.height);
    case .Horizontal:
      let initialPaddingForContraintedDimension = (CGRectGetHeight(contentRect) - dimensions * blockPixels.height) /  2
      return CGRectMake(position.x * blockPixels.width,
        position.y * blockPixels.height + initialPaddingForContraintedDimension,
        elementSize.width * blockPixels.width,
        elementSize.height * blockPixels.height);
    }
  }

  private func fillInBlocks(endRow endRow: Int) {
    let sectionCount = collectionView?.numberOfSections() ?? 0

    for var section = lastIndexPathPlaced?.section ?? 0; section < sectionCount; ++section {
      let rowCount = collectionView?.numberOfItemsInSection(section)
      let initialValue: Int

      if let ip = lastIndexPathPlaced {
        initialValue = ip.row + 1
      }
      else {
        initialValue = 0
      }

      for var row = initialValue; row < rowCount; ++row {
        let indexPath = NSIndexPath(forRow: row, inSection: section)

        if placeBlock(indexPath: indexPath) == true {
          lastIndexPathPlaced = indexPath
        }

        let coordinate: Int

        switch scrollDirection {
        case .Vertical:
          coordinate = Int(firstOpenSpace.y)
        case .Horizontal:
          coordinate = Int(firstOpenSpace.x)
        }

        guard coordinate < endRow else {
          return
        }
      }
    }

  }

  func placeBlock(indexPath indexPath: NSIndexPath) -> Bool {
    let ablockSize = blockSize(indexPath: indexPath)

    return !traverseOpenTiles(callback: { [unowned self] (let blockOrigin: CGPoint) in

      // we need to make sure each square in the desired
      // area is available before we can place the square

      let traversedAllBlocks = self.traverseTiles(
        point: blockOrigin, size: ablockSize, iterator: {[unowned self] (let point: CGPoint) in
          let coordinate: CGFloat
          let maximumRestrictedBoundSize: Bool

          switch self.scrollDirection {
          case .Vertical:
            coordinate = point.x
            maximumRestrictedBoundSize = blockOrigin.x == 0
          case .Horizontal:
            coordinate = point.y
            maximumRestrictedBoundSize = blockOrigin.y == 0
          }

          let spaceAvailable: Bool = self.indexPathForPosition(point: point) != nil ? true : false
          let inBounds = Int(coordinate) < self.restrictedDimensionBlockSize()

          if spaceAvailable && maximumRestrictedBoundSize && !inBounds {
            print("layout not enough")
            return true
          }

          return spaceAvailable && inBounds
        }
      )

      if !traversedAllBlocks { return true }
      self.setIndexPath(indexPath, forPoint: blockOrigin)

      self.traverseTiles(point: blockOrigin, size: ablockSize, iterator: {[unowned self] (let aPoint: CGPoint) in
        self.setPosition(aPoint, forIndexPath: indexPath)
        self.furthestBlockPoint = aPoint
        return true
        }
      )

      return false
      }
    )
  }

  func blockSize(indexPath indexPath: NSIndexPath) -> CGSize {
    let blockSize = CGSizeMake(1.0, 1.0)

    if let result = delegate?.blockSize(collectionView: collectionView!, layout: self, indexPath: indexPath) {
      return result
    }

    return blockSize
  }

  func traverseTilesBetweenUnrestrictedDimension(
    start start: Int, end: Int, callback: (point: CGPoint) -> Bool
    ) -> Bool {

      for var unrestrictedDimension = start; unrestrictedDimension < end; ++unrestrictedDimension {
        for var restrictedDimension = 0; restrictedDimension < restrictedDimensionBlockSize(); ++restrictedDimension {
          let point: CGPoint

          switch scrollDirection {
          case .Vertical:
            point = CGPointMake(CGFloat(restrictedDimension), CGFloat(unrestrictedDimension))
          case .Horizontal:
            point = CGPointMake(CGFloat(unrestrictedDimension), CGFloat(restrictedDimension))
          }

          guard callback(point: point) else {
            return false
          }
        }
      }

      return true
  }

  func traverseOpenTiles(callback callback: (point: CGPoint) -> Bool) -> Bool {
    var allTakenBefore = true

    let initialValue: CGFloat

    switch scrollDirection {
    case .Vertical:
      initialValue = firstOpenSpace.y
    case .Horizontal:
      initialValue = firstOpenSpace.x
    }

    for var unrestrictedDimension = initialValue;; ++unrestrictedDimension {
      let limit = restrictedDimensionBlockSize()

      for var restrictedDimension = 0; restrictedDimension < limit; ++restrictedDimension {
        let point: CGPoint

        switch scrollDirection {
        case .Vertical:
          point = CGPointMake(CGFloat(restrictedDimension), unrestrictedDimension)
        case .Horizontal:
          point = CGPointMake(unrestrictedDimension, CGFloat(restrictedDimension))
        }

        guard indexPathForPosition(point: point) == nil else {
          continue
        }

        if allTakenBefore {
          firstOpenSpace = point
          allTakenBefore = false
        }

        if callback(point: point) == false {
          return false
        }

      }
    }
  }

  func positionForIndexPath(indexPath: NSIndexPath) -> CGPoint {

    if indexPath.section >= positionByIndexPath.count ||
      indexPath.row >= positionByIndexPath[indexPath.section].count {
        fillInBlocks(indexPath: indexPath)
    }

    let value = positionByIndexPath[indexPath.section][indexPath.row]

    return value.CGPointValue()
  }

  func traverseTiles(
    point point: CGPoint, size: CGSize, iterator:(point: CGPoint) -> Bool
    ) -> Bool {

      for var column = point.x; column < point.x + size.width; ++column {
        for var row = point.y; row < point.y + size.height; ++row {
          if iterator(point: CGPointMake(column, row)) == false {
            return false
          }
        }
      }

      return true
  }

  func setPosition(point: CGPoint, forIndexPath indexPath: NSIndexPath) {
    let unrestrictedPoint: Int
    let restrictedPoint: Int

    switch scrollDirection {
    case .Vertical:
      unrestrictedPoint = Int(point.y)
      restrictedPoint = Int(point.x)
    case .Horizontal:
      unrestrictedPoint = Int(point.x)
      restrictedPoint = Int(point.y)
    }

    indexPathByPosition[restrictedPoint][unrestrictedPoint] = indexPath
  }

  func setIndexPath(indexPath: NSIndexPath, forPoint point: CGPoint) {
    positionByIndexPath[indexPath.section][indexPath.row] = NSValue(CGPoint: point)
  }

  func restrictedDimensionBlockSize() -> Int {
    let size: CGFloat
    let contentRect = UIEdgeInsetsInsetRect(collectionView!.frame, collectionView!.contentInset)
    
    switch scrollDirection {
    case .Vertical:
      size = CGRectGetWidth(contentRect) / blockPixels.width
    case .Horizontal:
      size = CGRectGetHeight(contentRect) / blockPixels.height
    }
    
    guard size > 0 else {
      return 1
    }
    
    return Int(round(size))
  }
}
