import 'dart:async';

import 'package:customer/constant/constant.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MercadoPagoScreen extends StatefulWidget {
  final String initialURl;

  const MercadoPagoScreen({super.key, required this.initialURl});

  @override
  State<MercadoPagoScreen> createState() => _MercadoPagoScreenState();
}

class _MercadoPagoScreenState extends State<MercadoPagoScreen> {
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
              onPageStarted: (String url) {},
              onPageFinished: (String url) {
                setState(() => isLoading = false);
              },
              onWebResourceError: (WebResourceError error) {},
              onNavigationRequest: (NavigationRequest navigation) async {
                debugPrint("--->2 ${navigation.url}");
                final uri = Uri.parse(navigation.url);

                if (navigation.url.contains("${Constant.globalUrl}payment/success")) {
                  final status = uri.queryParameters['status'];

                  if (status == "successful" || status == "success") {
                    Get.back(result: true);
                  } else {
                    // cancelled / failed / anything else
                    Get.back(result: false);
                  }

                  return NavigationDecision.prevent;
                }
                if (uri.path.contains("/payment/failure") || uri.path.contains("/payment/pending")) {
                  Get.back(result: false);
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.initialURl));
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
          title: Text("Payment".tr),
          centerTitle: false,
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
          title: Text('Cancel Payment'.tr),
          content: SingleChildScrollView(child: Text("Cancel Payment?".tr)),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'.tr, style: const TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                Get.back(result: false);
              },
            ),
            TextButton(
              child: Text('Continue'.tr, style: const TextStyle(color: Colors.green)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
