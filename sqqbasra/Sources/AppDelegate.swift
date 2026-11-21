import UIKit
import SpriteKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = GameViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class GameViewController: UIViewController {
    private var presented = false

    override func loadView() {
        let v = SKView()
        v.isMultipleTouchEnabled = true
        view = v
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !presented, view.bounds.width > view.bounds.height,
              let skView = view as? SKView else { return }
        presented = true
        let h: CGFloat = 360
        let w = h * view.bounds.width / view.bounds.height
        let scene = GameScene(size: CGSize(width: w, height: h))
        scene.scaleMode = .aspectFill
        skView.presentScene(scene)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
}
