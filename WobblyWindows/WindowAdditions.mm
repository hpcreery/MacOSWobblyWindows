//
//  SBSWindowAdditions.m
//  Jello
//
//  Created by Dennis Collaris on 21/07/2017.
//  Copyright © 2017 example. All rights reserved.
//  Copyright © 2022 Hunter Creery. All rights reserved.
//

#import "WindowAdditions.h"
#import "Cocoa/Cocoa.h"
#import <SpriteKit/SpriteKit.h>
#import <objc/runtime.h>
#import "WobblyWindows-Swift.h"

#ifdef __cplusplus
extern "C" {
#endif
  extern CGError CGSSetWindowTransform(
                                       const CGSConnection cid,
                                       const CGSWindow wid,
                                       CGAffineTransform transform);
  
  extern CGError CGSSetWindowWarp(
                                  const CGSConnection cid,
                                  const CGSWindow wid,
                                  int w,
                                  int h,
                                  CGPointWarp* mesh);
  
  extern OSStatus CGSGetWindowBounds(const CGSConnection cid, const CGSWindow wid, CGRect *bounds);
  
  extern CGError CGSSetWindowAlpha(
                                   const CGSConnection cid,
                                   const CGSWindow wid,
                                   float alpha);
#ifdef __cplusplus
}
#endif


@implementation NSWindow (WindowAdditions)
@dynamic warp;

NSString const *key = @"warp";
- (void)setWarp:(Warp *)warp {
//  NSLog(@"setWarp");
  objc_setAssociatedObject(self, &key, warp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (Warp *)warp {
//  NSLog(@"warp");
  return objc_getAssociatedObject(self, &key);
}


+ (void)load {
//  NSLog(@"load");
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willMove:) name:NSWindowWillMoveNotification object:nil];
}

+ (void) willMove:(id) notification {
//  NSLog(@"willMove");
  NSWindow* window = (NSWindow*)[(NSNotification*)notification object];
  
  //Reinit window since it may have moved in different method
  window.warp = [[Warp alloc] initWithWindow:window];
  
  [window.warp startDragAt: NSEvent.mouseLocation];
  [window windowMoves: notification];
}

NSTimer *timer;
id monitor;
- (void) windowMoves:(id) notification {
//  NSLog(@"windowMoves");
  NSWindow* window = (NSWindow*)[(NSNotification*)notification object];
  monitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp handler:^(NSEvent *event) {
    [window moveStopped];
  }];
  timer = [NSTimer scheduledTimerWithTimeInterval:(1.0f / 60.0f) target:self selector:@selector(windowMoved:) userInfo:window repeats:YES];

//  if (monitor != NULL) { // only disable mouseup monitor when we move a window again, because sometimes the first event does not fully trigger.
//    [NSEvent removeMonitor:monitor];
//  }

}

NSTimeInterval previousUpdate = 0.0;
- (void) windowMoved:(NSTimer*) timer {
//  NSLog(@"windowMoved");
  NSWindow* window = [timer userInfo];
  float diff;
  if (previousUpdate == 0.0) {
    diff = 1.0/60.0;
  } else {
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    diff = timestamp - previousUpdate;
    previousUpdate = timestamp;
  }
  [window.warp dragAt:NSEvent.mouseLocation];
  [self.warp stepWithDelta: diff];
}

- (void) moveStopped {
//  NSLog(@"moveStopped");
  [timer invalidate];
  timer = NULL;
  [self.warp endDrag];
}

- (void) drawWarp {
//  NSLog(@"drawWarp");
  CGSConnection cid = _CGSDefaultConnection();

  // normal grid
  int GRID_WIDTH = 10;
  int GRID_HEIGHT = 10;
  CGPointWarp mesh[GRID_HEIGHT][GRID_WIDTH];
  for (int y = 0; y < GRID_HEIGHT; y++) {
    for (int x = 0; x < GRID_WIDTH; x++) {
      mesh[y][x] = [self.warp meshPointWithX:x y:y];
    }
  }

  CGSSetWindowWarp(cid, CGSWindow(self.windowNumber), GRID_WIDTH, GRID_HEIGHT, &(mesh[0][0]));
}

- (void) setFrameDirty:(NSRect) frame {
//  NSLog(@"setFrameDirty");
  // This timeout prevents the setFrame and clearwindow to interfere with the previously set warps, which caused glitches.
  [NSTimer scheduledTimerWithTimeInterval:(1.0f/10.0f) repeats:false block:^(NSTimer * _Nonnull timer) {
    [self setFrame:frame display:NO];
    CGSConnection cid = _CGSDefaultConnection();
    CGSSetWindowWarp(cid, CGSWindow([self windowNumber]), 0, 0, NULL);
  }];
}

//- (void) log:(NSString) string {
//  NSDateFormatter *DateFormatter=[[NSDateFormatter alloc] init];
//
//  [DateFormatter setDateFormat:@"yyyy-MM-dd hh:mm:ss"];
//  NSLog(@"%@",[DateFormatter stringFromDate:[NSDate date]]);
//  NSLog(@"%@",string);
//}

@end
