import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_browser/custom_image.dart';
import 'package:flutter_browser/util.dart';
import 'package:flutter_browser/webview_tab.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import 'models/browser_model.dart';
import 'models/webview_model.dart';
import 'models/window_model.dart';

class EmptyTab extends StatefulWidget {
  const EmptyTab({super.key});

  @override
  State<EmptyTab> createState() => _EmptyTabState();
}

class _EmptyTabState extends State<EmptyTab> {
  final _controller = TextEditingController();

  List<Map<String, dynamic>> _quickLinks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchQuickLinks();
  }

  Future<void> _fetchQuickLinks() async {
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(
          'https://usdable.oss-cn-hongkong.aliyuncs.com/tagCollection.json'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody);
        final data = json['data'] as List;

        List<Map<String, dynamic>> parsedItems = [];
        for (var collection in data) {
          final links = collection['links'] as List;
          for (var link in links) {
            parsedItems.add({
              "title": link['name'],
              "url": link['url'],
              "iconUrl": link['icon'],
            });
          }
        }

        if (mounted) {
          setState(() {
            _quickLinks = parsedItems.take(9).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildShortcutItem(int index) {
    if (index >= _quickLinks.length) return Container();
    var item = _quickLinks[index];

    return GestureDetector(
        onTap: () => openNewTab(item["url"]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
                child: Container(
                    decoration: BoxDecoration(
                        color: const Color(0xFFF4F7FB),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.01),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ]),
                    child: Center(
                      child: CustomImage(
                        url: WebUri(item["iconUrl"] as String),
                        maxWidth: 32.0,
                        height: 32.0,
                      ),
                    ))),
            const SizedBox(height: 8),
            Text(item["title"] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.0, color: Color(0xFF333333))),
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                  top: 60.0, left: 24.0, right: 24.0, bottom: 40.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title section
                    Center(
                        child: RichText(
                            text: const TextSpan(
                                style: TextStyle(
                                    fontSize: 34.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent),
                                children: [
                          TextSpan(
                              text: "// ",
                              style: TextStyle(color: Colors.lightBlue)),
                          TextSpan(
                              text: "你想去 ",
                              style: TextStyle(color: Color(0xFF333333))),
                          TextSpan(
                              text: "哪里？",
                              style: TextStyle(color: Colors.lightBlue)),
                        ]))),
                    const SizedBox(height: 20),
                    // Subtitle
                    Center(
                        child: Text(
                      ">_ 输入网址、搜索内容，或直接发送指令",
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12.0,
                          letterSpacing: 0.5),
                    )),
                    const SizedBox(height: 30),
                    // Search Bar
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30.0),
                          border: Border.all(
                              color: Colors.lightBlue[100]!, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.04),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ]),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(Icons.search,
                              color: Colors.grey[400], size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                              child: TextField(
                            controller: _controller,
                            onSubmitted: (value) => openNewTab(value),
                            textInputAction: TextInputAction.go,
                            decoration: InputDecoration(
                              hintText: "去哪儿？搜点什么？...",
                              hintStyle: TextStyle(
                                  color: Colors.grey[400], fontSize: 15.0),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14.0),
                            ),
                            style: const TextStyle(
                                color: Colors.black87, fontSize: 15.0),
                          )),
                          Padding(
                            padding: const EdgeInsets.only(
                                right: 6.0, top: 6.0, bottom: 6.0),
                            child: ElevatedButton(
                              onPressed: () {
                                openNewTab(_controller.text);
                                FocusScope.of(context).unfocus();
                              },
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: const Color(0xFFF0F0F0),
                                foregroundColor: Colors.grey[700],
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(25.0)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0),
                              ),
                              child: const Text("RUN",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.0)),
                            ),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 50),

                    // Quick access title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text("[ ",
                            style: TextStyle(
                                color: Colors.blue,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const Text("快速入口",
                            style: TextStyle(
                                color: Color(0xFF333333),
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const Text(" ]",
                            style: TextStyle(
                                color: Colors.blue,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Expanded(child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Container(
                              height: 1.5,
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                Colors.blue[300]!,
                                Colors.grey[200]!,
                                Colors.transparent
                              ])),
                            );
                          },
                        ))
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Quick access subtitle
                    Row(children: [
                      Text("// QUICK ACCESS ",
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11.0,
                              letterSpacing: 0.5)),
                      const Icon(Icons.circle,
                          size: 8, color: Colors.green),
                      const SizedBox(width: 4),
                      const Text("SYNC",
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: 11.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                      Text(" | ${_quickLinks.length} nodes",
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 11.0)),
                    ]),

                    const SizedBox(height: 24),

                    // Grid View
                    _isLoading
                        ? const Center(
                            child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ))
                        : GridView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _quickLinks.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.9,
                              crossAxisSpacing: 16.0,
                              mainAxisSpacing: 16.0,
                            ),
                            itemBuilder: (context, index) {
                              return _buildShortcutItem(index);
                            })
                  ]))),
    );
  }

  void openNewTab(value) {
    if (value == null || value.toString().trim().isEmpty) return;

    final windowModel = Provider.of<WindowModel>(context, listen: false);
    final browserModel = Provider.of<BrowserModel>(context, listen: false);
    final settings = browserModel.getSettings();

    var url = WebUri(value.trim());
    if (Util.isLocalizedContent(url) ||
        (url.isValidUri && url.toString().split(".").length > 1)) {
      url = url.scheme.isEmpty ? WebUri("https://$url") : url;
    } else {
      url = WebUri(settings.searchEngine.searchUrl + value);
    }

    windowModel.addTab(WebViewTab(
      key: GlobalKey(),
      webViewModel: WebViewModel(url: url),
    ));
  }
}
