//
//  GameScene.h
//  testgame
//
//  Created by xiang on 2019/4/3.
//  Copyright © 2019 xiang. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

typedef enum : NSUInteger {
    ESCGameStatusIdle,
    ESCGameStatusRunning,
    ESCGameStatusOver,
} ESCGameStatus;


@interface GameScene : SKScene

@end
