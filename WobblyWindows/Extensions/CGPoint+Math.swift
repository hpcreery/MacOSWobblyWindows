//
//  CGPoint+Math.swift
//  Jello
//
//  Created by Dennis Collaris on 05/08/2018.
//  Copyright © 2018 collaris. All rights reserved.
//

import Foundation

extension CGPoint {
  func distanceTo(point: CGPoint) -> CGFloat {
    let distx = abs(self.x - point.x)
    let disty = abs(self.y - point.y)
    if (distx > disty) {
      return distx + 0.337 * disty
    } else {
      return disty + 0.337 * distx
    }
//    return sqrt(pow(distx, 2) + pow(disty, 2))
  }
}

public func + (left: CGPoint, right: CGPoint) -> CGPoint {
  return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

public func += (left: inout CGPoint, right: CGPoint) {
  left = left + right
}

public func + (left: CGPoint, right: CGVector) -> CGPoint {
  return CGPoint(x: left.x + right.dx, y: left.y + right.dy)
}

public func += (left: inout CGPoint, right: CGVector) {
  left = left + right
}

public func - (left: CGPoint, right: CGPoint) -> CGPoint {
  return CGPoint(x: left.x - right.x, y: left.y - right.y)
}

public func -= (left: inout CGPoint, right: CGPoint) {
  left = left - right
}
