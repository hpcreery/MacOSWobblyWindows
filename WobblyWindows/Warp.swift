//
//  Warp.swift
//  Jello
//
//  Created by Dennis Collaris on 22/07/2017.
//  Copyright © 2017 collaris. All rights reserved.
//  Copyright © 2022 Hunter Creery. All rights reserved.
//

import AppKit


internal var GRID_WIDTH = 10
internal var GRID_HEIGHT = 10
internal var springK: CGFloat = 2
internal var friction: CGFloat = 2

internal func convert(toPosition i: Int) -> (Int, Int) {
  return (i % GRID_WIDTH, i / GRID_WIDTH)
}

internal func convert(toIndex x: Int, y: Int) -> Int {
  return (y * GRID_WIDTH) + x
}

extension NSScreen {
  class var current: NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    let screens = NSScreen.screens
    return (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) })
  }
}


@objc class Warp: NSObject {
  var window: NSWindow
  var particles: [Particle]
  var springs = [Spring]()
  var steps: Double = 0
  var timer: Timer? = nil
  var firstScreen: NSScreen
  var solver: Solver!
  
  @objc init(window: NSWindow) {
    self.window = window
    
    particles = (0 ..< (GRID_WIDTH * GRID_HEIGHT)).map { i in
      let (x, y) = convert(toPosition: i)
      let position: CGPoint = window.frame.origin + (CGVector(dx: x, dy: y).normalized * window.frame.size)
      return Particle(position: position)
    }

    for y in 0..<GRID_HEIGHT {
      for x in 0..<GRID_WIDTH {
        if x > 0 {
          springs.append(Spring(
            a: convert(toIndex: x - 1, y: y),
            b: convert(toIndex: x, y: y),
            offset: CGVector(dx: 1, dy: 0).normalized * window.frame.size,
            springK: springK
          ))
        }

        if y > 0 {
          springs.append(Spring(
            a: convert(toIndex: x, y: y - 1),
            b: convert(toIndex: x, y: y),
            offset: CGVector(dx: 0, dy: 1).normalized * window.frame.size,
            springK: springK
          ))
        }
      }
    }

    firstScreen = NSScreen.screens.first!
    
    super.init()
    
    self.solver = VelocityVerlet(warp: self)

    NotificationCenter.default.addObserver(self, selector: #selector(Warp.didResize), name: NSWindow.didResizeNotification, object: nil)
  }

  @objc func step(delta: TimeInterval) {
//    NSLog("delta %.3f", delta)
    if delta > 0.5 { return }
//    self.steps += delta.milliseconds / 3
//    let steps = floor(self.steps)
//    self.steps -= steps
//
//    if steps.isZero {
//      return
//    }

    for _ in 0 ..< 15 {
      solver.step(particles: &particles, stepSize: CGFloat(20*delta))
    }

    // Bounce off top edge
    if let screen = NSScreen.current {
      let macosMenuBarHeight: CGFloat = 23.0
      let offset = (firstScreen.frame.origin.y - screen.frame.origin.y) + macosMenuBarHeight
      for i in 0..<particles.count {
        if particles[i].position.y > screen.frame.height - offset {
          particles[i].position.y = screen.frame.height - offset
          particles[i].force.dy *= -0.5
          particles[i].velocity.dy *= -0.5
        }
      }
    }

    self.window.drawWarp()
  }

  @objc func didResize(notification: NSNotification) {
    guard let window = notification.object as? NSWindow,
          window == self.window else { return }

    for i in (0 ..< (GRID_WIDTH * GRID_HEIGHT)) {
      let (x, y) = convert(toPosition: i)
      let position: CGPoint = window.frame.origin + (CGVector(dx: x, dy: y).normalized * window.frame.size)
      particles[i].position = position
    }

    // TODO: update offsets rather than recompute them.
    springs = []

    for y in 0..<GRID_HEIGHT {
      for x in 0..<GRID_WIDTH {
        if x > 0 {
          springs.append(Spring(
            a: convert(toIndex: x - 1, y: y),
            b: convert(toIndex: x, y: y),
            offset: CGVector(dx: 1, dy: 0).normalized * window.frame.size,
            springK: springK
          ))
        }

        if y > 0 {
          springs.append(Spring(
            a: convert(toIndex: x, y: y - 1),
            b: convert(toIndex: x, y: y),
            offset: CGVector(dx: 0, dy: 1).normalized * window.frame.size,
            springK: springK
          ))
        }
      }
    }
  }

  @objc public func startDrag(at point: CGPoint) {
    self.alreadySetFrame = false
    let distances = particles
      .map { $0.position.distanceTo(point: point) }
    
    let closest = distances
      .map { ($0 - distances.min()!) / (distances.max()! - distances.min()!) }
      .enumerated()
      //.sorted( by: { $0.1 < $1.1 } )
      //.prefix(4)

    let idx = GRID_WIDTH * GRID_HEIGHT
    particles.append(Particle(position: point))
    particles[idx].immobile = true

    for (offset, distance) in closest {
      let particle = offset
      springs.append(Spring(
          a: particle,
          b: idx,
          offset: CGVector(dx: point.x - particles[particle].position.x, dy: point.y - particles[particle].position.y),
          springK: springK * (1 - pow(distance, 1/2.5))
      ))
    }    
    self.window.styleMask.remove(NSWindow.StyleMask.resizable)
  }

  @objc public func drag(at point: CGPoint) {
    if particles.indices.contains(GRID_WIDTH * GRID_HEIGHT) {
      particles[GRID_WIDTH * GRID_HEIGHT].position = point
    } else {
      // Very dirty workaround
      startDrag(at: NSEvent.mouseLocation)
      drag(at: point)
    }
  }

  var alreadySetFrame = false
  @objc public func endDrag() {
    if alreadySetFrame { return }
    let idx = GRID_WIDTH * (GRID_HEIGHT - 1) + GRID_HEIGHT * (GRID_WIDTH - 1)
    springs.removeLast(springs.count - idx)
    if particles.indices.contains(GRID_WIDTH * GRID_HEIGHT) { particles.remove(at: GRID_WIDTH * GRID_HEIGHT) }

    if timer != nil { // Dont start a after-drag loop when there is already one running
      return
    }
    
    timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { (timer) in
      // when dragging during the after-drag loop, disable the loop
      if self.particles.indices.contains(GRID_WIDTH * GRID_HEIGHT) { return }

      if self.force < 20 { // TODO: make configurable maybe
        timer.invalidate()
        self.timer = nil

        let frame = NSRect(
          x: self.particles[0].position.x,
          y: self.particles[0].position.y,
          width: self.window.frame.width,
          height: self.window.frame.height
        )

        self.window.setFrameDirty(frame)
        self.alreadySetFrame = true

        self.window.styleMask.insert(NSWindow.StyleMask.resizable)
      } else {
        self.step(delta: 1/60)
      }
    }
  }

  @objc public func meshPoint(x: Int, y: Int) -> CGPointWarp {
    let position: CGPoint = CGVector(dx: x, dy: y).normalized * window.frame.size
    let particle = particles[convert(toIndex: x, y: (GRID_HEIGHT - 1) - y)]
    
    return CGPointWarp(
      local: MeshPoint(x: Float(position.x), y: Float(position.y)),
      global: MeshPoint(x: Float(round(particle.position.x)), y: Float(firstScreen.frame.height - round(particle.position.y))) // TODO: use UIScreen.convert
    )
  }

  @objc var velocity: CGFloat {
    return solver.velocity
  }

  @objc var force: CGFloat {
    return solver.force
  }
}
