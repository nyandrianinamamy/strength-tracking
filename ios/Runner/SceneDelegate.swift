import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)

        // Configure Watch connectivity bridge after the Flutter engine is ready
        if let windowScene = scene as? UIWindowScene,
           let controller = windowScene.windows.first?.rootViewController as? FlutterViewController {
            WatchSessionManager.shared.configure(with: controller)
        }
    }
}
