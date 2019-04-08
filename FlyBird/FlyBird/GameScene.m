//
//  GameScene.m
//  testgame
//
//  Created by xiang on 2019/4/3.
//  Copyright © 2019 xiang. All rights reserved.
//

#import "GameScene.h"

@interface GameScene () <SKPhysicsContactDelegate>

@property(nonatomic,strong)NSArray<SKSpriteNode *>* floorArray;

@property(nonatomic,strong)SKSpriteNode* bird;

@property(nonatomic,assign)ESCGameStatus gameStatus;

@property(nonatomic,assign)uint32_t birdCategory;

@property(nonatomic,assign)uint32_t pipeCategory;

@property(nonatomic,assign)uint32_t floorCategory;

@property(nonatomic,strong)SKLabelNode* gameOverLabelNode;

@property(nonatomic,strong)SKLabelNode* metersLabel;

@property(nonatomic,assign)int meters;

@end

@implementation GameScene

- (instancetype)init {
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)didMoveToView:(SKView *)view {
    
    self.birdCategory = 1 << 1;
    self.pipeCategory = 1 << 2;
    self.floorCategory = 1 << 3;
    
    self.backgroundColor = [SKColor colorWithRed:80.0 / 255.0 green:192.0 / 255.0 blue:203.0 / 255.0 alpha:1.0];
    
    //给场景添加一个物理体，这个物理体就是一条沿着场景四周的边，限制了游戏范围，其他物理体就不会跑出这个场景
    self.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];
    //物理世界的碰撞检测代理为场景自己，这样如果这个物理世界里面有两个可以碰撞接触的物理体碰到一起了就会通知他的代理
    self.physicsWorld.contactDelegate = self;

    NSMutableArray *floorArray = [NSMutableArray array];
    for (int i = 0; i < 3; i++) {
        SKSpriteNode *floor = [[SKSpriteNode alloc] initWithImageNamed:@"floor"];
        [floorArray addObject:floor];
        floor.anchorPoint = CGPointMake(0, 0);
        floor.position = CGPointMake(floor.size.width * i, 0);
        floor.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:CGRectMake(0, 0, floor.size.width, floor.size.height)];
        floor.physicsBody.categoryBitMask = self.floorCategory;
        [self addChild:floor];
    }
    self.floorArray = floorArray;
  
    self.bird = [[SKSpriteNode alloc] initWithImageNamed:@"player1"];
    self.bird.physicsBody = [SKPhysicsBody bodyWithTexture:self.bird.texture size:self.bird.size];
    //禁止旋转
    self.bird.physicsBody.allowsRotation = NO;
    //设置小鸟物理体标示
    self.bird.physicsBody.categoryBitMask = self.birdCategory;
    //设置可以小鸟碰撞检测的物理体
    self.bird.physicsBody.contactTestBitMask = self.floorCategory | self.pipeCategory;

    [self addChild:self.bird];

    [self shuffle];
    
    self.gameOverLabelNode = [SKLabelNode labelNodeWithFontNamed:@"Chalkduster"];
    self.gameOverLabelNode.text = @"Game Over";
    self.gameOverLabelNode.zPosition = 100;
    
    self.metersLabel = [SKLabelNode labelNodeWithText:@"meters:0"];
    self.metersLabel.verticalAlignmentMode = SKLabelVerticalAlignmentModeTop;
    self.metersLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    self.metersLabel.position = CGPointMake(self.size.width * 0.5, self.size.height - 30);
    self.metersLabel.zPosition = 100;
    [self addChild:self.metersLabel];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    switch (self.gameStatus) {
        case ESCGameStatusIdle:
            [self startGame];
            break;
        case ESCGameStatusRunning:
            [self.bird.physicsBody applyImpulse:CGVectorMake(0, 20)];
            break;
        case ESCGameStatusOver:
            [self shuffle];
            break;
        default:
            break;
    }
}

- (void)moveScene {
    for (SKSpriteNode *floor in self.floorArray) {
        floor.position = CGPointMake(floor.position.x - 1, floor.position.y);
        if (floor.position.x < - floor.size.width) {
            floor.position = CGPointMake(floor.position.x + floor.size.width * 2, floor.position.y);
        }
    }
    
    for (SKSpriteNode *node in self.children) {
        if ([node.name isEqualToString:@"pipe"]) {
            node.position = CGPointMake(node.position.x - 1, node.position.y);
            if (node.position.x < - node.size.width * 0.5) {
                [node removeFromParent];
            }
        }
    }
}

- (void)shuffle {
    self.bird.position = CGPointMake(self.size.width  * 0.5, self.size.height * 0.5);
    [self.gameOverLabelNode removeFromParent];
    self.bird.physicsBody.dynamic = NO;
    [self birdStartFly];
    [self removeAllPipesNode];
    self.gameStatus = ESCGameStatusIdle;
    self.meters = 0;
}

- (void)startGame {
    self.bird.physicsBody.dynamic = YES;
    [self startCreateRandomPipesAction];
    self.gameStatus = ESCGameStatusRunning;
}

- (void)gameOver {
    //禁止用户点击屏幕
    self.userInteractionEnabled = NO;
    //添加gameOverLabel到场景里
    [self addChild:self.gameOverLabelNode];
    //设置gameOverLabel其实位置在屏幕顶部
    self.gameOverLabelNode.position = CGPointMake(self.size.width * 0.5, self.size.height);
    //让gameOverLabel通过一个动画action移动到屏幕中间
    [self.gameOverLabelNode runAction:[SKAction moveBy:CGVectorMake(0, -self.size.height * 0.5) duration:0.5] completion:^{
        //动画结束才重新允许用户点击屏幕
        self.userInteractionEnabled = YES;
    }];
    [self birdStopFly];
    [self stopCreateRandomPipesAction];
    self.gameStatus = ESCGameStatusOver;
}

- (void)createRandomPipes {
    //先计算地板顶部到屏幕顶部的总可用高度
    double height = self.size.height - self.floorArray.firstObject.size.height;
    //计算上下管道中间的空档的随机高度，最小为空档高度为2.5倍的小鸟的高度，最大高度为3.5倍的小鸟高度
    double pipeGap = arc4random_uniform(self.bird.size.height) + self.bird.size.height * 4;
    //管道宽度在60
    double pipeWidth = 60.0;
    //随机计算顶部pipe的随机高度，这个高度肯定要小于(总的可用高度减去空档的高度)
    double topPipeHeight = arc4random_uniform(height - pipeGap);
    //总可用高度减去空档gap高度减去顶部水管topPipe高度剩下就为底部的bottomPipe高度
    double bottomPipeHeight = height - pipeGap - topPipeHeight;
    //调用添加水管到场景方法
    [self addPipesWithTopSize:CGSizeMake(pipeWidth, topPipeHeight) bottomSize:CGSizeMake(pipeWidth, bottomPipeHeight)];
}

- (void)addPipesWithTopSize:(CGSize)topSize bottomSize:(CGSize)bottomSize {
    //创建上水管
    SKTexture *topTexture = [SKTexture textureWithImageNamed:@"topPipe"];
    SKSpriteNode *topPipe = [SKSpriteNode spriteNodeWithTexture:topTexture size:topSize];
    topPipe.centerRect = CGRectMake(0.5, 0.5, 0.25, 0.25);
    topPipe.name = @"pipe";
    topPipe.position = CGPointMake(self.size.width + topPipe.size.width * 0.5, self.size.height - topPipe.size.height * 0.5);
    topPipe.physicsBody = [SKPhysicsBody bodyWithTexture:topTexture size:topSize];
    topPipe.physicsBody.dynamic = NO;
    topPipe.physicsBody.categoryBitMask = self.pipeCategory;
    [self addChild:topPipe];
    

    
    SKTexture *bottomTexture = [SKTexture textureWithImageNamed:@"bottomPipe"];
    SKSpriteNode *bottomPipe = [SKSpriteNode spriteNodeWithTexture:bottomTexture size:bottomSize];
    bottomPipe.name = @"pipe";
    bottomPipe.position = CGPointMake(self.size.width + bottomPipe.size.width * 0.5, self.floorArray.firstObject.size.height + bottomPipe.size.height * 0.5);
    bottomPipe.physicsBody = [SKPhysicsBody bodyWithTexture:bottomTexture size:bottomSize];
    bottomPipe.physicsBody.dynamic = NO;
    bottomPipe.physicsBody.categoryBitMask = self.pipeCategory;
    [self addChild:bottomPipe];
}

- (void)startCreateRandomPipesAction {
    //创建一个等待的action,等待时间的平均值为3.5秒，变化范围为1秒
    SKAction *waitAction = [SKAction waitForDuration:3.5 withRange:1.0];
    //创建一个产生随机水管的action，这个action实际上就是调用一下我们上面新添加的那个createRandomPipes()方法
    SKAction *generatePipeAction = [SKAction runBlock:^{
        [self createRandomPipes];
    }];
    //让场景开始重复循环执行"等待" -> "创建" -> "等待" -> "创建"。。。。。
    //并且给这个循环的动作设置了一个叫做"createPipe"的key来标识它
    [self runAction:[SKAction repeatActionForever:[SKAction sequence:@[waitAction,generatePipeAction]]] withKey:@"createPipe"];
}

- (void)stopCreateRandomPipesAction {
    [self removeActionForKey:@"createPipe"];
}

- (void)removeAllPipesNode {
    for (SKSpriteNode *node in self.children) {
        if ([node.name isEqualToString:@"pipe"]) {
            [node removeFromParent];
        }
    }
}

- (void)birdStartFly {
    SKAction *flyAction = [SKAction animateWithTextures:@[[SKTexture textureWithImageNamed:@"player1"],
                                                          [SKTexture textureWithImageNamed:@"player2"],
                                                          [SKTexture textureWithImageNamed:@"player3"],
                                                          [SKTexture textureWithImageNamed:@"player2"]
                                                          ] timePerFrame:0.15];
    [self.bird runAction:[SKAction repeatActionForever:flyAction] withKey:@"fly"];
}

- (void)birdStopFly {
    [self.bird removeActionForKey:@"fly"];
}

-(void)update:(CFTimeInterval)currentTime {
    if (self.gameStatus != ESCGameStatusOver) {
        [self moveScene];
    }
    if (self.gameStatus == ESCGameStatusRunning) {
        self.meters += 1;
    }
}

- (void)setMeters:(int)meters {
    _meters = meters;
    self.metersLabel.text = [NSString stringWithFormat:@"meters:\(%d)",meters];
    

}

#pragma mark - SKPhysicsContactDelegate
- (void)didBeginContact:(SKPhysicsContact *)contact {
    //先检查游戏状态是否在运行中，如果不在运行中则不做操作，直接return
    if (self.gameStatus != ESCGameStatusRunning) {
        return;
    }
    
    //为了方便我们判断碰撞的bodyA和bodyB的categoryBitMask哪个小，小的则将它保存到新建的变量bodyA里的，大的则保存到新建变量bodyB里
    SKPhysicsBody *bodyA;
    SKPhysicsBody *bodyB;

    if (contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask) {
        bodyA = contact.bodyA;
        bodyB = contact.bodyB;
    }else {
        bodyA = contact.bodyB;
        bodyB = contact.bodyA;
    }
    //接下来判断bodyA是否为小鸟，bodyB是否为水管或者地面，如果是则游戏结束，直接调用gameOver()方法
    if ((bodyA.categoryBitMask == self.birdCategory && bodyB.categoryBitMask == self.pipeCategory) ||
        (bodyA.categoryBitMask == self.birdCategory && bodyB.categoryBitMask == self.floorCategory)) {
        [self gameOver];
    }
}

@end
