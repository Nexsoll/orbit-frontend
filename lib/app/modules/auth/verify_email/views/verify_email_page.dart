import 'package:flutter/cupertino.dart';
import 'package:super_up/app/core/api_service/auth/auth_api.dart';
import 'package:super_up/app/modules/auth/login/views/login_view.dart';

class VerifyEmailPage extends StatefulWidget {
  final String? token;
  final String? email;

  const VerifyEmailPage({Key? key, this.token, this.email}) : super(key: key);

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _loading = true;
  bool _success = false;
  String _message = 'Verifying email...';

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    final token = widget.token?.trim();
    final email = widget.email?.trim();

    if (token == null || token.isEmpty || email == null || email.isEmpty) {
      setState(() {
        _loading = false;
        _success = false;
        _message = 'Invalid or missing verification link.';
      });
      return;
    }

    try {
      final api = AuthApi.create();
      final res = await api.verifyLinkRegister({
        'token': token,
        'email': email,
      });

      final ok = (res as dynamic).isSuccessful == true;
      final body = (res as dynamic).body;
      setState(() {
        _loading = false;
        _success = ok;
        _message = ok
            ? (body is Map && body['message'] is String
                ? body['message'] as String
                : 'Email verified successfully.')
            : (body is Map && body['message'] is String
                ? body['message'] as String
                : 'Verification failed.');
      });
      if (ok && mounted) {
        // Navigate to login (account is created after verification)
        Future.microtask(() {
          Navigator.of(context).pushAndRemoveUntil(
            CupertinoPageRoute(
              builder: (_) => const LoginView(),
            ),
            (route) => false,
          );
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _success = false;
        _message = 'Verification error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Verify Email'),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading) const CupertinoActivityIndicator(),
                if (_loading) const SizedBox(height: 12),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (!_loading)
                  CupertinoButton.filled(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(_success ? 'Done' : 'Back'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

