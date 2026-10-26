// ignore_for_file: file_names

import 'dart:developer';

import 'package:customer/models/payment_model/pay_fast_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PayFastScreen extends StatefulWidget {
  final String htmlData;
  final PayFastModel payFastSettingData;

  const PayFastScreen({super.key, required this.htmlData, required this.payFastSettingData});

  @override
  State<PayFastScreen> createState() => _PayFastScreenState();
}

class _PayFastScreenState extends State<PayFastScreen> {
  WebViewController controller = WebViewController();
  bool isLoading = true;

  @override
  void initState() {
    initController();
    super.initState();
  }

  void initController() {
    controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (int progress) {},
              onPageFinished: (String url) {
                setState(() => isLoading = false);
              },
              onWebResourceError: (WebResourceError error) {},
              onNavigationRequest: (NavigationRequest navigation) async {
                if (kDebugMode) {
                  log("--->2 $navigation");
                }
                if (navigation.url == widget.payFastSettingData.returnUrl) {
                  Get.back(result: true);
                } else if (navigation.url == widget.payFastSettingData.notifyUrl) {
                  Get.back(result: false);
                } else if (navigation.url == widget.payFastSettingData.cancelUrl) {
                  _showMyDialog();
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadHtmlString((widget.htmlData));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showMyDialog();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: GestureDetector(
            onTap: () {
              _showMyDialog();
            },
            child: const Icon(Icons.arrow_back),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: controller),
            Visibility(visible: isLoading, child: const Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }

  Future<void> _showMyDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Payment'),
          content: SingleChildScrollView(child: Text("Cancel Payment?".tr)),
          actions: <Widget>[
            TextButton(
              child: Text('Exit'.tr, style: TextStyle(color: Colors.red)),
              onPressed: () {
                Get.back();
                Get.back(result: false);
              },
            ),
            TextButton(
              child: Text('Continue Payment'.tr, style: TextStyle(color: Colors.green)),
              onPressed: () {
                Get.back();
              },
            ),
          ],
        );
      },
    );
  }
}
