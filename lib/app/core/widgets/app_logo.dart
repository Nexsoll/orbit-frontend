import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final double fontSize;
  final bool showChatText;

  const AppLogo({
    super.key,
    this.size = 25,
    this.fontSize = 20,
    this.showChatText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/logo.png',
          width: size,
          height: size,
        ),
        const SizedBox(width: 2),
        RichText(
          text: TextSpan(
            style: context.cupertinoTextTheme.textStyle.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w400,
            ),
            children: [
              TextSpan(
                text: 'rbit ',
                style: TextStyle(
                  color: context.isDark ? Colors.white : Colors.black,
                ),
              ),
              if (showChatText)
                const TextSpan(
                  text: 'chat',
                  style: TextStyle(color: Color(0xFFB48648)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
