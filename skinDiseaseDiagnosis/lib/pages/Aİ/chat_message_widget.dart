import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:skincancer/style/color.dart';

class ChatMessageWidget extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isUser;
  final VoidCallback? onLongPress;

  const ChatMessageWidget({
    Key? key,
    required this.message,
    required this.isUser,
    this.onLongPress,
  }) : super(key: key);

  @override
  State<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<ChatMessageWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String audioPath) async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() => _isPlaying = false);
        return;
      }

      await _audioPlayer.play(UrlSource(audioPath));
      setState(() => _isPlaying = true);

      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() => _isPlaying = false);
      });
    } catch (e) {
      print('Audio playback error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisAlignment:
              widget.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!widget.isUser) _buildAvatar(),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isUser ? primaryColor : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.message['imagePath'] != null)
                      _buildImagePreview(widget.message['imagePath']!),
                    if ((widget.message['text'] ?? '').isNotEmpty)
                      Text(
                        widget.message['text'] ?? '',
                        style: TextStyle(
                          color: widget.isUser ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    if (widget.message['audioPath'] != null)
                      _buildAudioPlayer(),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm').format(widget.message['timestamp']),
                      style: TextStyle(
                        color: widget.isUser
                            ? Colors.white.withOpacity(0.7)
                            : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.isUser) _buildAvatar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      backgroundColor: widget.isUser ? primaryColor : Colors.grey[300],
      child: Icon(
        widget.isUser ? Icons.person : Icons.android,
        color: widget.isUser ? Colors.white : Colors.grey[700],
      ),
    );
  }

  Widget _buildImagePreview(String imagePath) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(
        maxWidth: 200,
        maxHeight: 200,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(imagePath),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildAudioPlayer() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: widget.isUser ? Colors.white : primaryColor,
            ),
            onPressed: () {
              if (widget.message['audioPath'] != null) {
                _playAudio(widget.message['audioPath']!);
              }
            },
          ),
          const SizedBox(width: 8),
          Text(
            'Sesli Yanıt',
            style: TextStyle(
              color: widget.isUser ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
