import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/post_provider.dart';
import '../../style/color.dart';
import '../../service/community_service.dart';
import '../../pages/Community/createPostPage.dart';

/// A helper class that provides static methods for creating posts
class CreatePostHelper {
  /// Navigate to the create post page from any context
  static Future<void> navigateToCreatePost(BuildContext context) async {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: postProvider,
          child: CreatePostPage(),
        ),
      ),
    );
  }
}

/// A reusable button widget for creating posts
class CreatePostButton extends StatelessWidget {
  final CommunityService communityService;
  final bool isVisible;
  final bool isExtended;
  final Color? backgroundColor;
  final Color? textColor;
  final double? elevation;

  const CreatePostButton({
    Key? key,
    required this.communityService,
    this.isVisible = true,
    this.isExtended = true,
    this.backgroundColor,
    this.textColor,
    this.elevation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isExtended) {
      return AnimatedScale(
        scale: isVisible ? 1.0 : 0.0,
        duration: Duration(milliseconds: 200),
        child: FloatingActionButton.extended(
          heroTag: 'create_post_button',
          onPressed: communityService.navigateToCreatePost,
          backgroundColor: backgroundColor ?? secondaryColor,
          foregroundColor: textColor ?? Colors.white,
          icon: Icon(Icons.add),
          label: Text('Gönderi Oluştur'),
          elevation: elevation ?? 4,
        ),
      );
    } else {
      return AnimatedScale(
        scale: isVisible ? 1.0 : 0.0,
        duration: Duration(milliseconds: 200),
        child: FloatingActionButton(
          heroTag: 'create_post_button',
          onPressed: communityService.navigateToCreatePost,
          backgroundColor: backgroundColor ?? secondaryColor,
          foregroundColor: textColor ?? Colors.white,
          child: Icon(Icons.add),
          elevation: elevation ?? 4,
        ),
      );
    }
  }
}
