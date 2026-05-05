import UIKit
import Foundation
import GoogleMaps
import flutter_local_notifications
import CallKit
import AVFAudio
import AVKit
import PushKit
import Flutter
import flutter_callkit_incoming
import Firebase
import ReplayKit
import UserNotifications


@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {

  private let screenShareChannelName = "com.orbit.ke/screen_share"
  private let pipChannelName = "com.orbit.ke/picture_in_picture"
  private var pipHandler: AnyObject?


  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }

    // Provide Google Maps API key (enable on simulator and device)
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !apiKey.isEmpty {
      GMSServices.provideAPIKey(apiKey)
    }

    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let screenShareChannel = FlutterMethodChannel(
        name: screenShareChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      screenShareChannel.setMethodCallHandler { [weak self] call, result in
        self?.handleScreenShareMethodCall(call, result: result)
      }

      // Picture in Picture channel
      let pipChannel = FlutterMethodChannel(
        name: pipChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      if #available(iOS 15.0, *) {
        let handler = PictureInPictureHandler(registrar: controller, channel: pipChannel)
        self.pipHandler = handler
        pipChannel.setMethodCallHandler { [weak self] call, result in
          if #available(iOS 15.0, *), let handler = self?.pipHandler as? PictureInPictureHandler {
            handler.handle(call, result: result)
          } else {
            result(FlutterError(code: "IOS_VERSION_UNSUPPORTED", message: "PiP requires iOS 15 or later", details: nil))
          }
        }
      }
    }

    // Set up notification delegate
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    #if !targetEnvironment(simulator)
    let mainQueue = DispatchQueue.main
    let voipRegistry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [PKPushType.voIP]
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

 // Handle updated push credentials
   func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
       let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
       //Save deviceToken to your server
       SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
   }

   func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
       print("didInvalidatePushTokenFor")
       SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
   }

 // Handle incoming pushes
 func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
//     print("didReceiveIncomingPushWith: \(payload.dictionaryPayload)")
     guard type == .voIP else { return }

     let id = payload.dictionaryPayload["session_id"] as? String ?? ""
     let nameCaller = payload.dictionaryPayload["caller_name"] as? String ?? ""
     let handle = payload.dictionaryPayload["handle"] as? String ?? ""
     let callStatus = payload.dictionaryPayload["call_status"] as? String ?? ""
     let is_ending = payload.dictionaryPayload["is_ending"] as!   Bool
     let call_type = payload.dictionaryPayload["call_type"] as? Int ?? 0

     let data = flutter_callkit_incoming.Data(id: id, nameCaller: nameCaller, handle: handle, type: call_type)
//      print(payload.dictionaryPayload)
     // Set extra data
     if let userInfoString = payload.dictionaryPayload["user_info"] as? String,
        let userInfoData = userInfoString.data(using: .utf8),
        let userInfoDict = try? JSONSerialization.jsonObject(with: userInfoData, options: []) as? NSDictionary {
         data.extra = userInfoDict
     } else {
         data.extra = [:]
     }

     if is_ending  == true {
         print("is_ending == true ")
         // End all calls
         SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
     } else {
         print("is_ending == false")
         // Show incoming call
         SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true)
     }

     // Make sure to call completion()
     DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
         completion()
     }
 }



       // Call back from Recent history
          override func application(_ application: UIApplication,
                                    continue userActivity: NSUserActivity,
                                    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {

              // Add this line to ensure the superclass method is called
              // This is often required for Flutter's internal handling of universal links and activities.
              if super.application(application, continue: userActivity, restorationHandler: restorationHandler) {
                  return true
              }

              guard let handleObj = userActivity.handle else {
                  return false
              }

              guard let isVideo = userActivity.isVideo else {
                  return false
              }
              let objData = handleObj.getDecryptHandle()
              let nameCaller = objData["nameCaller"] as? String ?? ""
              let handle = objData["handle"] as? String ?? ""
              let data = flutter_callkit_incoming.Data(id: UUID().uuidString, nameCaller: nameCaller, handle: handle, type: isVideo ? 1 : 0)
              //set more data...
              //data.nameCaller = nameCaller
              SwiftFlutterCallkitIncomingPlugin.sharedInstance?.startCall(data, fromPushKit: true)

              return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
          }

           // Func Call api for Accept
              func onAccept(_ call: Call, _ action: CXAnswerCallAction) {
                  let json = ["action": "ACCEPT", "data": call.data.toJSON()] as [String: Any]
                  print("LOG: onAccept")

              }

              // Func Call API for Decline
              func onDecline(_ call: Call, _ action: CXEndCallAction) {
                  let json = ["action": "DECLINE", "data": call.data.toJSON()] as [String: Any]
                  print("LOG: onDecline")

              }

              // Func Call API for End
              func onEnd(_ call: Call, _ action: CXEndCallAction) {
                  let json = ["action": "END", "data": call.data.toJSON()] as [String: Any]
                  print("LOG: onEnd")

              }

              // Func Call API for TimeOut
              func onTimeOut(_ call: Call) {
                  let json = ["action": "TIMEOUT", "data": call.data.toJSON()] as [String: Any]
                  print("LOG: onTimeOut")

              }

              // Func Callback Toggle Audio Session
              func didActivateAudioSession(_ audioSession: AVAudioSession) {
                  //Use if using WebRTC
                  //RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
                  //RTCAudioSession.sharedInstance().isAudioEnabled = true
              }

              // Func Callback Toggle Audio Session
              func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
                  //Use if using WebRTC
                  //RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
                  //RTCAudioSession.sharedInstance().isAudioEnabled = false
              }

  // MARK: - UNUserNotificationCenterDelegate

  // Handle notification when app is in foreground
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                            willPresent notification: UNNotification,
                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    // Show notification even when app is in foreground
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  // Handle notification tap
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                            didReceive response: UNNotificationResponse,
                            withCompletionHandler completionHandler: @escaping () -> Void) {
    // Handle notification tap here
    completionHandler()
  }

  private func handleScreenShareMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "showSystemBroadcastPicker":
      showSystemBroadcastPicker(result: result)
    case "finishSystemBroadcast":
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func showSystemBroadcastPicker(result: @escaping FlutterResult) {
    if #available(iOS 12.0, *) {
      DispatchQueue.main.async {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
          result(FlutterError(code: "NO_WINDOW", message: "Unable to access key window", details: nil))
          return
        }

        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: -1000, y: -1000, width: 60, height: 60))
        picker.preferredExtension = "com.superup.orbit.BroadcastUploadExtension"
        picker.showsMicrophoneButton = false
        window.addSubview(picker)

        if let button = picker.subviews.compactMap({ $0 as? UIButton }).first {
          button.sendActions(for: .touchUpInside)
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            picker.removeFromSuperview()
          }
          result(true)
        } else {
          picker.removeFromSuperview()
          result(FlutterError(code: "NO_PICKER_BUTTON", message: "Unable to find broadcast picker button", details: nil))
        }
      }
    } else {
      result(FlutterError(code: "IOS_VERSION_UNSUPPORTED", message: "Screen sharing requires iOS 12 or later", details: nil))
    }
  }

}

// MARK: - PictureInPictureHandler

@available(iOS 15.0, *)
class PictureInPictureHandler: NSObject {
  private let channel: FlutterMethodChannel
  private weak var registrar: FlutterViewController?

  private var pipController: AVPictureInPictureController?
  private var playerVC: AVPlayerViewController?

  init(registrar: FlutterViewController, channel: FlutterMethodChannel) {
    self.registrar = registrar
    self.channel = channel
    super.init()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isPictureInPictureSupported":
      result(AVPictureInPictureController.isPictureInPictureSupported())

    case "enterPictureInPictureMode":
      guard let args = call.arguments as? [String: Any],
            let urlString = args["url"] as? String,
            let url = URL(string: urlString) else {
        result(FlutterError(code: "BAD_ARGS", message: "Missing video url", details: nil))
        return
      }
      enterPiP(url: url, result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func enterPiP(url: URL, result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      let player = AVPlayer(url: url)
      let vc = AVPlayerViewController()
      vc.player = player
      vc.allowsPictureInPicturePlayback = true
      vc.showsPlaybackControls = true
      vc.videoGravity = .resizeAspect
      self.playerVC = vc

      if let topVC = self.registrar {
        topVC.present(vc, animated: true) {
          player.play()

          if let playerLayer = vc.view.layer.sublayers?.first(where: { $0 is AVPlayerLayer }) as? AVPlayerLayer,
             let pip = AVPictureInPictureController(playerLayer: playerLayer) {
            pip.delegate = self
            self.pipController = pip

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
              if pip.isPictureInPicturePossible {
                pip.startPictureInPicture()
              }
            }
          }

          result(true)
        }
      } else {
        result(FlutterError(code: "NO_VC", message: "No root view controller", details: nil))
      }
    }
  }

  func cleanup() {
    pipController?.stopPictureInPicture()
    playerVC?.player?.pause()
    playerVC?.dismiss(animated: true)
    playerVC = nil
    pipController = nil
  }
}

@available(iOS 15.0, *)
extension PictureInPictureHandler: AVPictureInPictureControllerDelegate {
  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureWithCompletionHandler completionHandler: @escaping (Bool) -> Void
  ) {
    if let vc = playerVC, vc.presentingViewController == nil, let registrar = registrar {
      registrar.present(vc, animated: true) {
        completionHandler(true)
      }
    } else {
      completionHandler(true)
    }
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    didStopPictureInPictureWithCompletionHandler completionHandler: @escaping () -> Void
  ) {
    playerVC?.dismiss(animated: true) {
      completionHandler()
    }
    playerVC = nil
    pipController = nil
  }
}
