import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class RegisterEmailVerifiedEvent extends VAppEvent {
  final String email;
  RegisterEmailVerifiedEvent(this.email);
  @override
  List<Object?> get props => [email];
}
