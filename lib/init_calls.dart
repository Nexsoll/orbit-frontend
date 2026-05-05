// import 'package:connectycube_flutter_call_kit/connectycube_flutter_call_kit.dart';
//
// Future initCalls() async {
//   // var canUseFullScreenIntent =
//   //     await ConnectycubeFlutterCallKit.canUseFullScreenIntent();
//   //
//   // if (!canUseFullScreenIntent) {
//   //   ConnectycubeFlutterCallKit.provideFullScreenIntentAccess();
//   // }
//   await Future.delayed(const Duration(seconds: 5));
//
//   CallEvent callEvent = CallEvent(
//     sessionId: "${DateTime.now().microsecondsSinceEpoch}",
//     callType: 1,
//     callerId: 1,
//     callerName: 'Caller Name',
//     opponentsIds: const {1, 2},
//     callPhoto:
//         'https://e7.pngegg.com/pngimages/753/432/png-clipart-user-profile-2018-in-sight-user-conference-expo-business-default-business-angle-service.png',
//     userInfo: const {'customParameter1': 'value1'},
//   );
//   ConnectycubeFlutterCallKit.showCallNotification(callEvent);
// }
