import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:customer/payment/xendit_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

class XenditScreen extends StatefulWidget {
  final String initialURl;
  final String transId;
  final String apiKey;

  const XenditScreen({super.key, required this.initialURl, required this.transId, required this.apiKey});

  @override
  State<XenditScreen> createState() => _XenditScreenState();
}

class _XenditScreenState extends State<XenditScreen> {
  WebViewController controller = WebViewController();
  bool isLoading = true;

  @override
  void initState() {
    controller.clearCache();
    initController();
    callTransaction();
    super.initState();
  }

  void callTransaction() {
    Timer? timer;
    timer = Timer.periodic(const Duration(seconds: 4), (Timer t) async {
      if (!mounted) {
        timer?.cancel();
        return;
      }
      await Future.delayed(const Duration(seconds: 5)).then((v) async {
        final value = await checkStatus(paymentId: widget.transId);
        if (!mounted) {
          timer?.cancel();
          return;
        }
        if (value.status == 'PAID' || value.status == 'SETTLED') {
          timer?.cancel();

          Get.back(result: true);
        } else if (value.status == 'FAILED') {
          timer?.cancel();
          Get.back(result: false);
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void initController() {
    controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: ((url) {
                setState(() {
                  isLoading = false;
                });
              }),
              onNavigationRequest: (NavigationRequest navigation) async {
                log("URL :: ${navigation.url}");
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.initialURl));
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        _showMyDialog();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          centerTitle: false,
          leading: GestureDetector(
            onTap: () {
              _showMyDialog();
            },
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        body: Stack(alignment: Alignment.center, children: [WebViewWidget(controller: controller), Visibility(visible: isLoading, child: const Center(child: CircularProgressIndicator()))]),
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
                Navigator.of(context).pop(false);
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text('Continue'.tr, style: const TextStyle(color: Colors.green)),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
          ],
        );
      },
    );
  }

  Future<XenditModel> checkStatus({required String paymentId}) async {
    // API endpoint
    var url = Uri.parse('https://api.xendit.co/v2/invoices/$paymentId');

    // Headers
    var headers = {'Content-Type': 'application/json', 'Authorization': generateBasicAuthHeader(widget.apiKey.toString())};

    // Making the POST request
    var response = await http.get(url, headers: headers);

    // Checking the response status
    if (response.statusCode == 200) {
      XenditModel model = XenditModel.fromJson(jsonDecode(response.body));
      return model;
    } else {
      return XenditModel();
    }
  }

  String generateBasicAuthHeader(String apiKey) {
    String credentials = '$apiKey:';
    String base64Encoded = base64Encode(utf8.encode(credentials));
    return 'Basic $base64Encoded';
  }
}
