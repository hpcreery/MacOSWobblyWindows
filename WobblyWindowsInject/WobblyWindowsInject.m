//
//  JelloInject.m
//  JelloInject
//
//  Created by Dennis Collaris on 21/07/2017.
//  Copyright © 2017 collaris. All rights reserved.
//

#import "WobblyWindowsInject.h"
#import "WobblyWindows-Swift.h"
#import "WindowAdditions.h"

static WobblyWindowsInject* plugin = nil;

@implementation WobblyWindowsInject

#pragma mark SIMBL methods and loading

+ (WobblyWindowsInject*)sharedInstance {
	if (plugin == nil)
		plugin = [[WobblyWindowsInject alloc] init];
	
	return plugin;
}

+ (void)load {
	[[WobblyWindowsInject sharedInstance] loadPlugin];
	
	NSLog(@"WobblyWindowsInject loaded.");
}

- (void)loadPlugin {
  for (NSWindow *window in [[NSApplication sharedApplication] windows]) {
    Warp *warp = [[Warp alloc] initWithWindow:window];
    window.warp = warp;
  }
}

@end
