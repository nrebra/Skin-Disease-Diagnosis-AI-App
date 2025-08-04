import 'package:flutter/material.dart';
import 'package:skincancer/style/color.dart';
import 'dart:ui';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:skincancer/service/chat_service.dart';

class ChatMessageWidget extends StatefulWidget {
  final String message;
  final bool isUser;
  final VoidCallback? onDelete;
  final VoidCallback? onPlayAudio;
  final DateTime timestamp;
  final String? imagePath;
  final String? audioPath;
  final VoidCallback? onLongPress;

  const ChatMessageWidget({
    Key? key,
    required this.message,
    required this.isUser,
    this.onDelete,
    this.onPlayAudio,
    required this.timestamp,
    this.imagePath,
    this.audioPath,
    this.onLongPress,
  }) : super(key: key);

  @override
  State<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<ChatMessageWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _showOptions = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getFormattedTime() {
    return "${widget.timestamp.hour.toString().padLeft(2, '0')}:${widget.timestamp.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Align(
        alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: widget.isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: () {
                  setState(() {
                    _showOptions = !_showOptions;
                  });

                  if (widget.onLongPress != null) {
                    widget.onLongPress!();
                  }
                },
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isUser ? primaryColor : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    gradient: widget.isUser
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              primaryColor,
                              primaryColor.withOpacity(0.8),
                            ],
                          )
                        : null,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.imagePath != null &&
                          widget.imagePath!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(widget.imagePath!),
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 150,
                                  color: Colors.grey[200],
                                  child: Center(
                                    child:
                                        Icon(Icons.error, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      Text(
                        widget.message,
                        style: TextStyle(
                          color: widget.isUser ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getFormattedTime(),
                        style: TextStyle(
                          color: widget.isUser
                              ? Colors.white.withOpacity(0.7)
                              : Colors.black54,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showOptions)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!widget.isUser && widget.audioPath != null)
                              IconButton(
                                icon: const Icon(Icons.play_arrow,
                                    color: Colors.white),
                                onPressed: widget.onPlayAudio,
                                tooltip: 'Play Audio',
                              ),
                            IconButton(
                              icon: const Icon(Icons.copy, color: Colors.white),
                              onPressed: () {
                                // Copy message logic here
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Mesaj panoya kopyalandı'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              tooltip: 'Copy',
                            ),
                            if (widget.isUser && widget.onDelete != null)
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.white),
                                onPressed: widget.onDelete,
                                tooltip: 'Delete',
                              ),
                            IconButton(
                              icon:
                                  const Icon(Icons.reply, color: Colors.white),
                              onPressed: () {
                                // Reply logic here
                              },
                              tooltip: 'Reply',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
