// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/live_stream_recording_model.dart';
import 'package:super_up_core/super_up_core.dart';

class StreamPaymentModal extends StatelessWidget {
  final LiveStreamRecordingModel recording;
  final void Function(String phone)? onPayNow;

  const StreamPaymentModal({super.key, required this.recording, this.onPayNow});

  @override
  Widget build(BuildContext context) {
    final phoneCtrl = TextEditingController();
    return CupertinoActionSheet(
      title: const Text('Watch Stream'),
      message: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            recording.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'By ${recording.streamerData.fullName}',
            style: const TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFB48648).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              recording.isPaid ? recording.formattedPrice : 'Free',
              style: const TextStyle(
                color: Color(0xFFB48648),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: phoneCtrl,
            placeholder: 'Your M-Pesa phone (07XXXXXXXX or 2547XXXXXXXX)',
            keyboardType: const TextInputType.numberWithOptions(signed: false),
            clearButtonMode: OverlayVisibilityMode.editing,
          ),
        ],
      ),
      actions: [
        CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () {
            if (onPayNow != null) {
              onPayNow!(phoneCtrl.text.trim());
            } else {
              Navigator.of(context).pop();
              VAppAlert.showSuccessSnackBarWithoutContext(message: 'Payment flow not implemented yet');
            }
          },
          child: const Text('Pay Now'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    );
  }
}
