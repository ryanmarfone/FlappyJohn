//
//  GameScene.swift
//  Flappy Felipe
//
//  Created by Main Account on 2/20/15.
//  Copyright (c) 2015 Razeware LLC. All rights reserved.
//

// http://bit.ly/1Lic6vd

import SpriteKit
import MediaPlayer

enum Layer: CGFloat {
  case Background
  case Obstacle
  case Foreground
  case Player
  case UI
  case Flash
}

enum GameState {
  case MainMenu
  case Tutorial
  case Play
  case Falling
  case ShowingScore
  case GameOver
}

struct PhysicsCategory {
  static let None: UInt32 = 0
  static let Player: UInt32 =     0b1 // 1
  static let Obstacle: UInt32 =  0b10 // 2
  static let Ground: UInt32 =   0b100 // 4
}

protocol GameSceneDelegate {

  func screenshot() -> UIImage
  func shareString(string: String, url: NSURL, image: UIImage)

}

class GameScene: SKScene, SKPhysicsContactDelegate {

  let kGravity: CGFloat = -1500.0
  let kImpulse: CGFloat = 400.0
  let kNumForegrounds = 2
  let kGroundSpeed: CGFloat = 150.0
  let kBottomObstacleMinFraction: CGFloat = 0.1
  let kBottomObstacleMaxFraction: CGFloat = 0.6
  let kGapMultiplier: CGFloat = 3.5
  let kFirstSpawnDelay: NSTimeInterval = 1.75
  let kEverySpawnDelay: NSTimeInterval = 1.5
  let kFontName = "AmericanTypewriter-Bold"
  let kMargin: CGFloat = 20.0
  let kAnimDelay = 0.3
  let kAppStoreID = 820464950
  let kNumBirdFrames = 4
  let kMinDegrees: CGFloat = -90
  let kMaxDegrees: CGFloat = 25
  let kAngularVelocity: CGFloat = 1000.0
    var moviePlayer: MPMoviePlayerController?
  
  let worldNode = SKNode()
  var playableStart: CGFloat = 0
  var playableHeight: CGFloat = 0
  let player = SKSpriteNode(imageNamed: "Bird0")
  var lastUpdateTime: NSTimeInterval = 0
  var dt: NSTimeInterval = 0
  var playerVelocity = CGPoint.zeroPoint
  
  var hitGround = false
  var hitObstacle = false
  var gameState: GameState = .Play
  var scoreLabel: SKLabelNode!
  var score = 0
  var gameSceneDelegate: GameSceneDelegate
  var playerAngularVelocity: CGFloat = 0.0
  var lastTouchTime: NSTimeInterval = 0
  var lastTouchY: CGFloat = 0.0
  
  let dingAction = SKAction.playSoundFileNamed("ding.wav", waitForCompletion: false)
  let flapAction = SKAction.playSoundFileNamed("flapping.wav", waitForCompletion: false)
  let whackAction = SKAction.playSoundFileNamed("whack.wav", waitForCompletion: false)
  let fallingAction = SKAction.playSoundFileNamed("falling.wav", waitForCompletion: false)
  let hitGroundAction = SKAction.playSoundFileNamed("hitGround.wav", waitForCompletion: false)
  let popAction = SKAction.playSoundFileNamed("pop.wav", waitForCompletion: false)
  let coinAction = SKAction.playSoundFileNamed("coin.wav", waitForCompletion: false)

  init(size: CGSize, delegate:GameSceneDelegate, gameState: GameState) {
    self.gameSceneDelegate = delegate
    self.gameState = gameState
    super.init(size: size)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func didMoveToView(view: SKView) {

    physicsWorld.gravity = CGVector(dx: 0, dy: 0)
    physicsWorld.contactDelegate = self

    addChild(worldNode)
    
    if gameState == .MainMenu {
      switchToMainMenu()
    } else {
      switchToTutorial()
    }
    
  }
  
  // MARK: Setup methods
  
  func setupBackground() {
    
    let background = SKSpriteNode(imageNamed: "Background")
    background.anchorPoint = CGPoint(x: 0.5, y: 1.0)
    background.position = CGPoint(x: size.width/2, y: size.height)
    background.zPosition = Layer.Background.rawValue
    worldNode.addChild(background)
    
    playableStart = size.height - background.size.height
    playableHeight = background.size.height
    
    let lowerLeft = CGPoint(x: 0, y: playableStart)
    let lowerRight = CGPoint(x: size.width, y: playableStart)
    
    self.physicsBody = SKPhysicsBody(edgeFromPoint: lowerLeft, toPoint: lowerRight)
    self.physicsBody?.categoryBitMask = PhysicsCategory.Ground
    self.physicsBody?.collisionBitMask = 0
    self.physicsBody?.contactTestBitMask = PhysicsCategory.Player
  
  }
  
  func setupForeground() {
  
    for i in 0..<kNumForegrounds {
      let foreground = SKSpriteNode(imageNamed: "Ground")
      foreground.anchorPoint = CGPoint(x: 0, y: 1)
      foreground.position = CGPoint(x: CGFloat(i) * size.width, y: playableStart)
      foreground.zPosition = Layer.Foreground.rawValue
      foreground.name = "foreground"
      worldNode.addChild(foreground)
    }
  
  }
    
    func playVideo() {
        let path = NSBundle.mainBundle().pathForResource("johnny", ofType:"mov")
        let url = NSURL.fileURLWithPath(path!)
        moviePlayer = MPMoviePlayerController(contentURL: url)
        if let player = moviePlayer {
            player.view.frame = self.view!.bounds
            player.prepareToPlay()
            player.scalingMode = .AspectFill
            player.controlStyle = MPMovieControlStyle.Fullscreen
            self.view!.addSubview(player.view)
        }
    }
  
  func setupPlayer() {
  
    player.position = CGPoint(x: size.width * 0.2, y: playableHeight * 0.4 + playableStart)
    player.zPosition = Layer.Player.rawValue
    
    let offsetX = player.size.width * player.anchorPoint.x
    let offsetY = player.size.height * player.anchorPoint.y

    let path = CGPathCreateMutable()

    CGPathMoveToPoint(path, nil, 17 - offsetX, 23 - offsetY)
    CGPathAddLineToPoint(path, nil, 39 - offsetX, 22 - offsetY)
    CGPathAddLineToPoint(path, nil, 38 - offsetX, 10 - offsetY)
    CGPathAddLineToPoint(path, nil, 21 - offsetX, 0 - offsetY)
    CGPathAddLineToPoint(path, nil, 4 - offsetX, 1 - offsetY)
    CGPathAddLineToPoint(path, nil, 3 - offsetX, 15 - offsetY)

    CGPathCloseSubpath(path)

    player.physicsBody = SKPhysicsBody(polygonFromPath: path)
    player.physicsBody?.categoryBitMask = PhysicsCategory.Player
    player.physicsBody?.collisionBitMask = 0
    player.physicsBody?.contactTestBitMask = PhysicsCategory.Obstacle | PhysicsCategory.Ground
    
    worldNode.addChild(player)
    
    let moveUp = SKAction.moveByX(0, y: 10, duration: 0.4)
    moveUp.timingMode = .EaseInEaseOut
    let moveDown = moveUp.reversedAction()
    let sequence = SKAction.sequence([moveUp, moveDown])
    let repeat = SKAction.repeatActionForever(sequence)
    player.runAction(repeat, withKey: "Wobble")
  
  }
  
   
  func setupLabel() {
  
    scoreLabel = SKLabelNode(fontNamed: kFontName)
    scoreLabel.fontColor = SKColor.whiteColor()
    scoreLabel.position = CGPoint(x: size.width/2, y: size.height - kMargin)
    scoreLabel.text = "0"
    scoreLabel.verticalAlignmentMode = .Top
    scoreLabel.zPosition = Layer.UI.rawValue
    worldNode.addChild(scoreLabel)
  
  }
  
  func setupScorecard() {
  
    if score > bestScore() {
      setBestScore(score)
    }
    
    let scorecard = SKSpriteNode(imageNamed: "ScoreCard")
    scorecard.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
    scorecard.name = "Tutorial"
    scorecard.zPosition = Layer.UI.rawValue
    worldNode.addChild(scorecard)
    
    let lastScore = SKLabelNode(fontNamed: kFontName)
    lastScore.fontColor = SKColor(red: 101.0/255.0, green: 71.0/255.0, blue: 73.0/255.0, alpha: 1.0)
    lastScore.position = CGPoint(x: -scorecard.size.width * 0.25, y: -scorecard.size.height * 0.2)
    lastScore.text = "\(score)"
    scorecard.addChild(lastScore)
    
    let bestScoreLabel = SKLabelNode(fontNamed: kFontName)
    bestScoreLabel.fontColor = SKColor(red: 101.0/255.0, green: 71.0/255.0, blue: 73.0/255.0, alpha: 1.0)
    bestScoreLabel.position = CGPoint(x: scorecard.size.width * 0.25, y: -scorecard.size.height * 0.2)
    bestScoreLabel.text = "\(self.bestScore())"
    scorecard.addChild(bestScoreLabel)
    
    let gameOver = SKSpriteNode(imageNamed: "GameOver")
    gameOver.position = CGPoint(x: size.width/2, y: size.height/2 + scorecard.size.height/2 + kMargin + gameOver.size.height/2)
    gameOver.zPosition = Layer.UI.rawValue
    worldNode.addChild(gameOver)
    
    let okButton = SKSpriteNode(imageNamed: "Button")
    okButton.position = CGPoint(x: size.width * 0.25, y: size.height/2 - scorecard.size.height/2 - kMargin - okButton.size.height/2)
    okButton.zPosition = Layer.UI.rawValue
    worldNode.addChild(okButton)
    
    let ok = SKSpriteNode(imageNamed: "OK")
    ok.position = CGPoint.zeroPoint
    ok.zPosition = Layer.UI.rawValue
    okButton.addChild(ok)
    
    let shareButton = SKSpriteNode(imageNamed: "Button")
    shareButton.position = CGPoint(x: size.width * 0.75, y: size.height/2 - scorecard.size.height/2 - kMargin - shareButton.size.height/2)
    shareButton.zPosition = Layer.UI.rawValue
    worldNode.addChild(shareButton)
    
    let share = SKSpriteNode(imageNamed: "Share")
    share.position = CGPoint.zeroPoint
    share.zPosition = Layer.UI.rawValue
    shareButton.addChild(share)
    
    gameOver.setScale(0)
    gameOver.alpha = 0
    let group = SKAction.group([
      SKAction.fadeInWithDuration(kAnimDelay),
      SKAction.scaleTo(1.0, duration: kAnimDelay)
    ])
    group.timingMode = .EaseInEaseOut
    gameOver.runAction(SKAction.sequence([
      SKAction.waitForDuration(kAnimDelay),
      group
    ]))
    
    scorecard.position = CGPoint(x: size.width * 0.5, y: -scorecard.size.height/2)
    let moveTo = SKAction.moveTo(CGPoint(x: size.width/2, y: size.height/2), duration: kAnimDelay)
    moveTo.timingMode = .EaseInEaseOut
    scorecard.runAction(SKAction.sequence([
      SKAction.waitForDuration(kAnimDelay * 2),
      moveTo
    ]))
    
    okButton.alpha = 0
    shareButton.alpha = 0
    let fadeIn = SKAction.sequence([
      SKAction.waitForDuration(kAnimDelay * 3),
      SKAction.fadeInWithDuration(kAnimDelay)
    ])
    okButton.runAction(fadeIn)
    shareButton.runAction(fadeIn)
    
    let pops = SKAction.sequence([
      SKAction.waitForDuration(kAnimDelay),
      popAction,
      SKAction.waitForDuration(kAnimDelay),
      popAction,
      SKAction.waitForDuration(kAnimDelay),
      popAction,
      SKAction.runBlock(switchToGameOver)
    ])
    runAction(pops)
  
  }
  
  func setupTutorial() {
  
    let tutorial = SKSpriteNode(imageNamed: "Tutorial")
    tutorial.position = CGPoint(x: size.width * 0.5, y: playableHeight * 0.4 + playableStart)
    tutorial.name = "Tutorial"
    tutorial.zPosition = Layer.UI.rawValue
    worldNode.addChild(tutorial)
    
    let ready = SKSpriteNode(imageNamed: "Ready")
    ready.position = CGPoint(x: size.width * 0.5, y: playableHeight * 0.7 + playableStart)
    ready.name = "Tutorial"
    ready.zPosition = Layer.UI.rawValue
    worldNode.addChild(ready)
  
  }
  
  func setupMainMenu() {
  
    let logo = SKSpriteNode(imageNamed: "Logo")
    logo.position = CGPoint(x: size.width/2, y: size.height * 0.8)
    logo.zPosition = Layer.UI.rawValue
    worldNode.addChild(logo)
    
    // Play button
    let playButton = SKSpriteNode(imageNamed: "Button")
    playButton.position = CGPoint(x: size.width * 0.5, y: size.height * 0.25)
    playButton.zPosition = Layer.UI.rawValue
    worldNode.addChild(playButton)
    
    let play = SKSpriteNode(imageNamed: "Play")
    play.position = CGPoint.zeroPoint
    playButton.addChild(play)
    
    
    // Bounce button
    let scaleUp = SKAction.scaleTo(1.02, duration: 0.75)
    scaleUp.timingMode = .EaseInEaseOut
    let scaleDown = SKAction.scaleTo(0.98, duration: 0.75)
    scaleDown.timingMode = .EaseInEaseOut
    
    playButton.runAction(SKAction.repeatActionForever(SKAction.sequence([
      scaleUp, scaleDown
    ])))
    
    // learn.removeAllActions() // DONLY
    
  }
  
  func setupPlayerAnimation() {
  
    var textures: Array<SKTexture> = []
    for i in 0..<kNumBirdFrames {
      textures.append(SKTexture(imageNamed: "Bird\(i)"))
    }
    for i in stride(from: kNumBirdFrames-1, through: 0, by: -1) {
      textures.append(SKTexture(imageNamed: "Bird\(i)"))
    }
    
    let playerAnimation = SKAction.animateWithTextures(textures, timePerFrame: 0.07)
    player.runAction(SKAction.repeatActionForever(playerAnimation))
  
  }
  
  // MARK: Gameplay
  
  func createObstacle() -> SKSpriteNode {
    let sprite = SKSpriteNode(imageNamed: "Cactus")
    sprite.zPosition = Layer.Obstacle.rawValue
    
    sprite.userData = NSMutableDictionary()
    
    let offsetX = sprite.size.width * sprite.anchorPoint.x
    let offsetY = sprite.size.height * sprite.anchorPoint.y

    let path = CGPathCreateMutable()

    CGPathMoveToPoint(path, nil, 3 - offsetX, 0 - offsetY)
    CGPathAddLineToPoint(path, nil, 5 - offsetX, 309 - offsetY)
    CGPathAddLineToPoint(path, nil, 16 - offsetX, 315 - offsetY)
    CGPathAddLineToPoint(path, nil, 39 - offsetX, 315 - offsetY)
    CGPathAddLineToPoint(path, nil, 51 - offsetX, 306 - offsetY)
    CGPathAddLineToPoint(path, nil, 49 - offsetX, 1 - offsetY)

    CGPathCloseSubpath(path)
    
    sprite.physicsBody = SKPhysicsBody(polygonFromPath: path)
    sprite.physicsBody?.categoryBitMask = PhysicsCategory.Obstacle
    sprite.physicsBody?.collisionBitMask = 0
    sprite.physicsBody?.contactTestBitMask = PhysicsCategory.Player
    
    return sprite
  }
  
  func spawnObstacle() {
  
    let bottomObstacle = createObstacle()
    let startX = size.width + bottomObstacle.size.width/2
    
    let bottomObstacleMin = (playableStart - bottomObstacle.size.height/2) + playableHeight * kBottomObstacleMinFraction
    let bottomObstacleMax = (playableStart - bottomObstacle.size.height/2) + playableHeight * kBottomObstacleMaxFraction
    bottomObstacle.position = CGPointMake(startX, CGFloat.random(min: bottomObstacleMin, max: bottomObstacleMax))
    bottomObstacle.name = "BottomObstacle"
    worldNode.addChild(bottomObstacle)
    
    let topObstacle = createObstacle()
    topObstacle.zRotation = CGFloat(180).degreesToRadians()
    topObstacle.position = CGPoint(x: startX, y: bottomObstacle.position.y + bottomObstacle.size.height/2 + topObstacle.size.height/2 + player.size.height * kGapMultiplier)
    topObstacle.name = "TopObstacle"
    worldNode.addChild(topObstacle)
    
    let moveX = size.width + topObstacle.size.width
    let moveDuration = moveX / kGroundSpeed
    let sequence = SKAction.sequence([
      SKAction.moveByX(-moveX, y: 0, duration: NSTimeInterval(moveDuration)),
      SKAction.removeFromParent()
    ])
    topObstacle.runAction(sequence)
    bottomObstacle.runAction(sequence)
  
  }
  
  func startSpawning() {
  
    let firstDelay = SKAction.waitForDuration(kFirstSpawnDelay)
    let spawn = SKAction.runBlock(spawnObstacle)
    let everyDelay = SKAction.waitForDuration(kEverySpawnDelay)
    let spawnSequence = SKAction.sequence([
      spawn, everyDelay
    ])
    let foreverSpawn = SKAction.repeatActionForever(spawnSequence)
    let overallSequence = SKAction.sequence([firstDelay, foreverSpawn])
    runAction(overallSequence, withKey: "spawn")
  
  }
  
  func stopSpawning() {
  
    removeActionForKey("spawn")
    
    worldNode.enumerateChildNodesWithName("TopObstacle", usingBlock: { node, stop in
      node.removeAllActions()
    })
    worldNode.enumerateChildNodesWithName("BottomObstacle", usingBlock: { node, stop in
      node.removeAllActions()
    })
  
  }
  
  func flapPlayer() {
  
    // Play sound
    runAction(flapAction)

    // Apply impulse
    playerVelocity = CGPoint(x: 0, y: kImpulse)
    playerAngularVelocity = kAngularVelocity.degreesToRadians()
    lastTouchTime = lastUpdateTime
    lastTouchY = player.position.y
    
    
  }
    
  
   override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
  
    for touch: AnyObject in touches {
        let touchLocation = (touch as! UITouch).locationInNode(self)
  
    switch gameState {
      case .MainMenu:
        if touchLocation.y < size.height * 0.15 {
          playVideo()
        } else if touchLocation.x < size.width * 0.6 {
          switchToNewGame(.Tutorial)
        } else {
          rateApp()
        }
        break
      case .Tutorial:
        switchToPlay()
        break
      case .Play:
        flapPlayer()
        break
      case .Falling:
        break
      case .ShowingScore:
        break
      case .GameOver:
        if touchLocation.x < size.width * 0.6 {
          switchToNewGame(.MainMenu)
        } else {
          shareScore()
        }
        break
    }
    }
  }
  
  // MARK: Updates
  
  override func update(currentTime: CFTimeInterval) {
  
    // return // DONLY
  
    if lastUpdateTime > 0 {
      dt = currentTime - lastUpdateTime
    } else {
      dt = 0
    }
    lastUpdateTime = currentTime
   
    switch gameState {
      case .MainMenu:
        break
      case .Tutorial:
        break
      case .Play:
        updateForeground()
        updatePlayer()
        checkHitObstacle()
        checkHitGround()
        updateScore()
        break
      case .Falling:
        updatePlayer()
        checkHitGround()
        break
      case .ShowingScore:
        break
      case .GameOver:
        break
    }
   
  }
  
  func updatePlayer() {
  
    // Apply gravity
    let gravity = CGPoint(x: 0, y: kGravity)
    let gravityStep = gravity * CGFloat(dt)
    playerVelocity += gravityStep
    
    // Apply velocity
    let velocityStep = playerVelocity * CGFloat(dt)
    player.position += velocityStep
    player.position = CGPoint(x: player.position.x, y: min(player.position.y, size.height))
    
    if player.position.y < lastTouchY {
      playerAngularVelocity = -kAngularVelocity.degreesToRadians()
    }
    
    // Rotate player
    let angularStep = playerAngularVelocity * CGFloat(dt)
    player.zRotation += angularStep
    player.zRotation = min(max(player.zRotation, kMinDegrees.degreesToRadians()), kMaxDegrees.degreesToRadians())
    
  
  }
  
  func updateForeground() {
  
    worldNode.enumerateChildNodesWithName("foreground", usingBlock: { node, stop in
      if let foreground = node as? SKSpriteNode {
        let moveAmt = CGPoint(x: -self.kGroundSpeed * CGFloat(self.dt), y: 0)
        foreground.position += moveAmt
        
        if foreground.position.x < -foreground.size.width {
          foreground.position += CGPoint(x: foreground.size.width * CGFloat(self.kNumForegrounds), y: 0)
        }
        
      }
    })
  
  }
  
  func checkHitObstacle() {
    if hitObstacle {
      hitObstacle = false
      switchToFalling()
    }
  }
  
  func checkHitGround() {
  
    if hitGround {
      hitGround = false
      playerVelocity = CGPoint.zeroPoint
      player.zRotation = CGFloat(-90).degreesToRadians()
      player.position = CGPoint(x: player.position.x, y: playableStart + player.size.width/2)
      runAction(hitGroundAction)
      switchToShowScore()
    }
  
  }
  
  func updateScore() {
  
    worldNode.enumerateChildNodesWithName("BottomObstacle", usingBlock: { node, stop in
      if let obstacle = node as? SKSpriteNode {
        if let passed = obstacle.userData?["Passed"] as? NSNumber {
          if passed.boolValue {
            return
          }
        }
        if self.player.position.x > obstacle.position.x + obstacle.size.width/2 {
          self.score++
          self.scoreLabel.text = "\(self.score)"
          self.runAction(self.coinAction)
          obstacle.userData?["Passed"] = NSNumber(bool: true)
        }
      }
    })
  
  }
  
  // MARK: Game States
  
  func switchToMainMenu() {
  
    gameState = .MainMenu
    setupBackground()
    setupForeground()
    setupPlayer()
    
    setupMainMenu()
    setupPlayerAnimation()
    
    // player.removeAllActions() // DONLY
    
  }
  
  func switchToTutorial() {
    gameState = .Tutorial
    setupBackground()
    setupForeground()
    setupPlayer()
    
    setupLabel()
    setupTutorial()
    setupPlayerAnimation()
  }
  
  func switchToPlay() {
    // Set state
    gameState = .Play
    
    // Remove tutorial
    worldNode.enumerateChildNodesWithName("Tutorial", usingBlock: { node, stop in
      node.runAction(SKAction.sequence([
        SKAction.fadeOutWithDuration(0.5),
        SKAction.removeFromParent()
      ]))
    })
    
    // Stop wobble
    player.removeActionForKey("Wobble")
    
    // Start spawning
    startSpawning()
    
    // Move player
    flapPlayer()
  }
  
  func switchToFalling() {
  
    gameState = .Falling
    
    // Screen shake
    let shake = SKAction.screenShakeWithNode(worldNode, amount: CGPoint(x: 0, y: 7.0), oscillations: 10, duration: 1.0)
    worldNode.runAction(shake)
    
    // Flash
    let whiteNode = SKSpriteNode(color: SKColor.whiteColor(), size: size)
    whiteNode.position = CGPoint(x: size.width/2, y: size.height/2)
    whiteNode.zPosition = Layer.Flash.rawValue
    worldNode.addChild(whiteNode)
    
    whiteNode.runAction(SKAction.removeFromParentAfterDelay(0.01))
    
    runAction(SKAction.sequence([
      whackAction,
      SKAction.waitForDuration(0.1),
      fallingAction
    ]))
    
    player.removeAllActions()
    stopSpawning()
  
  }
  
  func switchToShowScore() {
    gameState = .ShowingScore
    player.removeAllActions()
    stopSpawning()
    setupScorecard()
  }
  
  func switchToNewGame(gameState: GameState) {
  
    runAction(popAction)
    
    let newScene = GameScene(size: size, delegate: gameSceneDelegate, gameState: gameState)
    let transition = SKTransition.fadeWithColor(SKColor.blackColor(), duration: 0.5)
    view?.presentScene(newScene, transition: transition)
  
  }
  
  func switchToGameOver() {
    gameState = .GameOver
  }
  
  // MARK: Score
  
  func bestScore() -> Int {
    return NSUserDefaults.standardUserDefaults().integerForKey("BestScore")
  }

  func setBestScore(bestScore: Int) {
    NSUserDefaults.standardUserDefaults().setInteger(bestScore, forKey: "BestScore")
    NSUserDefaults.standardUserDefaults().synchronize()
  }
  
  func shareScore() {
    
    let urlString = "www.blinds.com"
    let url = NSURL(string: urlString)
    
    let screenshot = gameSceneDelegate.screenshot()
    let initialTextString = "OMG! I scored \(score) points in Flappy John!"
    gameSceneDelegate.shareString(initialTextString, url: url!, image: screenshot)
    
  }

  func rateApp() {
    let urlString = "www.blinds.com"
    let url = NSURL(string: urlString)
    UIApplication.sharedApplication().openURL(url!)
  }
  
  func learn() {
    let urlString = "www.blinds.com"
    let url = NSURL(string: urlString)
    UIApplication.sharedApplication().openURL(url!)
  }
  
  // MARK: Physics

  func didBeginContact(contact: SKPhysicsContact) {
    let other = contact.bodyA.categoryBitMask == PhysicsCategory.Player ? contact.bodyB : contact.bodyA
    
    if other.categoryBitMask == PhysicsCategory.Ground {
      hitGround = true
    }
    if other.categoryBitMask == PhysicsCategory.Obstacle {
      hitObstacle = true
    }
  }
  
}
