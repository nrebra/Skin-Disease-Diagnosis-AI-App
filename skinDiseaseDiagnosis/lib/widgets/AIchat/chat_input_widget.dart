import 'dart:io';
import 'package:flutter/material.dart';
import 'package:skincancer/style/color.dart';
import 'package:skincancer/service/chat_service.dart';

class ChatInputWidget extends StatefulWidget {
  final ChatService chatService;
  final VoidCallback onSendMessage;
  final Function(String) onTextChanged;
  final Function(File?) onImageSelected;

  const ChatInputWidget({
    Key? key,
    required this.chatService,
    required this.onSendMessage,
    required this.onTextChanged,
    required this.onImageSelected,
  }) : super(key: key);

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  String _recognizedText = '';

  Future<void> _handleVoiceInputStart(BuildContext context) async {
    try {
      await widget.chatService.startListening((text) {
        setState(() {
          _recognizedText = text;
          // Sürekli olarak tanınan metni gösteren text field'ı güncelle
          widget.chatService.messageController.text = text;
          widget.onTextChanged(text);
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ses tanıma hatası: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleVoiceInputEnd() {
    widget.chatService.stopListening();
    // Tanınan metin boş değilse, otomatik olarak gönder seçeneği eklenebilir
    // if (_recognizedText.trim().isNotEmpty) {
    //   widget.onSendMessage();
    // }
  }

  // Kamera veya galeri seçim modalını göster
  Future<void> _showImagePickerOptions(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Resim Ekle",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor1,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Kamera seçeneği
                _buildOptionItem(
                  context: context,
                  icon: Icons.camera_alt_rounded,
                  title: "Kamera",
                  color: primaryColor,
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      final image = await widget.chatService.takePicture();
                      if (image != null) {
                        widget.onImageSelected(image);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  },
                ),
                // Galeri seçeneği
                _buildOptionItem(
                  context: context,
                  icon: Icons.photo_library_rounded,
                  title: "Galeri",
                  color: cameraColor,
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      final image = await widget.chatService.pickImage();
                      if (image != null) {
                        widget.onImageSelected(image);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Kamera veya galeri seçeneği için widget
  Widget _buildOptionItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: textColor1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isInputValid =
        widget.chatService.messageController.text.isNotEmpty ||
            widget.chatService.selectedImage != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? MediaQuery.of(context).viewInsets.bottom
            : MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ses kaydı göstergesi
          if (widget.chatService.isListening)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Dalgalanan animasyon
                  _buildPulsingDot(),
                  const SizedBox(width: 12),
                  Text(
                    "Dinleniyor...",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _recognizedText.isNotEmpty
                        ? "\"${_recognizedText.length > 20 ? '${_recognizedText.substring(0, 20)}...' : _recognizedText}\""
                        : "Konuşun",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Mikrofon butonu
              Container(
                decoration: BoxDecoration(
                  color: widget.chatService.isListening
                      ? primaryColor.withOpacity(0.2)
                      : primaryColorLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTapDown: (_) => _handleVoiceInputStart(context),
                    onTapUp: (_) => _handleVoiceInputEnd(),
                    onTapCancel: () => _handleVoiceInputEnd(),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Icon(
                        widget.chatService.isListening
                            ? Icons.mic
                            : Icons.mic_none,
                        color: widget.chatService.isListening
                            ? primaryColor
                            : Colors.grey[600],
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Resim ekleme butonu - İki seçenek için modal açacak
              Container(
                decoration: BoxDecoration(
                  color: primaryColorLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () => _showImagePickerOptions(context),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        color: cameraColor,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Mesaj yazma alanı
              Expanded(
                child: TextField(
                  controller: widget.chatService.messageController,
                  maxLines: 5,
                  minLines: 1,
                  onChanged: widget.onTextChanged,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(fontSize: 15, color: textColor1),
                  decoration: InputDecoration(
                    hintText: widget.chatService.isListening
                        ? "Konuşun..."
                        : "Mesajınızı yazın...",
                    hintStyle: TextStyle(color: textColor2.withOpacity(0.5)),
                    filled: true,
                    fillColor: backgroundColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: primaryColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Gönder butonu
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isInputValid
                      ? secondaryColor
                      : textColor2.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: isInputValid ? widget.onSendMessage : null,
                    child: const Center(
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.all(2.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withOpacity(value),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3 * value),
                blurRadius: 5.0 * value,
                spreadRadius: 2.0 * value,
              )
            ],
          ),
        );
      },
      onEnd: () {
        // Animasyonu sürekli tekrarla
        if (mounted && widget.chatService.isListening) {
          setState(() {});
        }
      },
    );
  }
}
