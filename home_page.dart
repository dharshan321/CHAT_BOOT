import 'dart:typed_data';
import 'dart:io';

import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:image_picker/image_picker.dart';

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Gemini gemini = Gemini.instance;
  List<ChatMessage> messages = [];

  ChatUser currentUser = ChatUser(
      id: "0",
      firstName: "user",
      profileImage: "https://i.pravatar.cc/300?u=123456");
  ChatUser geminiUser = ChatUser(
      id: "1",
      firstName: "Gemini",
      profileImage: "https://i.pravatar.cc/300?u=654321");
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Gemini Chart"),
      ),
      body: _builtUI(),
    );
  }

  Widget _builtUI() {
    return DashChat(
        inputOptions: InputOptions(trailing: [
          IconButton(onPressed: _sendMediaMessage, icon: Icon(Icons.image))
        ]),
        currentUser: currentUser,
        onSend: _sendMessage,
        messages: messages);
  }

  Future<void> _sendMessage(ChatMessage chatmessage) async {
    setState(() {
      messages = [chatmessage, ...messages];
    });

    String question = chatmessage.text;
    List<Uint8List>? images;

    if (chatmessage.medias?.isNotEmpty ?? false) {
      try {
        images = [];
        for (var media in chatmessage.medias!) {
          if (media.type == MediaType.image) {
            final file = File(media.url);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              images.add(bytes);
            }
          }
        }
      } catch (e) {
        setState(() {
          messages = [
            ChatMessage(
              user: geminiUser,
              createdAt: DateTime.now(),
              text:
                  "Error processing image: ${e.toString()}. Please try again.",
            ),
            ...messages
          ];
        });
        return;
      }
    }

    StringBuffer buffer = StringBuffer();

    try {
      gemini.streamGenerateContent(question, images: images).listen((event) {
        String chunk = event.content?.parts
                ?.map((part) => part is TextPart ? part.text : part.toString())
                .join("") ??
            "";
        buffer.write(chunk);

        setState(() {
          int geminiIndex = messages.indexWhere((m) => m.user == geminiUser);
          if (geminiIndex == 0) {
            messages[0] = ChatMessage(
              user: geminiUser,
              createdAt: messages[0].createdAt,
              text: buffer.toString(),
            );
          } else {
            messages = [
              ChatMessage(
                user: geminiUser,
                createdAt: DateTime.now(),
                text: buffer.toString(),
              ),
              ...messages
            ];
          }
        });
      });
    } catch (e) {
      print(e);
    }
  }

  void _sendMediaMessage() async {
    try {
      setState(() {
        messages = [
          ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: "Selecting image...",
          ),
          ...messages
        ];
      });

      ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Optimize image quality
      );

      if (image != null) {
        setState(() {
          messages[0] = ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: "Processing image...",
          );
        });

        final imagePrompt =
            "Please provide a detailed description of this image, including:\n"
            "1. The main subject or focus\n"
            "2. Colors, lighting, and visual elements\n"
            "3. Any text or significant details\n"
            "4. The overall context or setting";

        ChatMessage chatMessage = ChatMessage(
          user: currentUser,
          createdAt: DateTime.now(),
          text: imagePrompt,
          medias: [
            ChatMedia(
              url: image.path,
              fileName: image.name,
              type: MediaType.image,
            )
          ],
        );

        setState(() {
          messages = [chatMessage, ...messages.sublist(1)];
        });

        _sendMessage(chatMessage);
      } else {
        setState(() {
          messages[0] = ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: "No image was selected. Please try again.",
          );
        });
      }
    } catch (e) {
      setState(() {
        messages = [
          ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: "Error processing image: ${e.toString()}. Please try again.",
          ),
          ...messages
        ];
      });
    }
  }
}
