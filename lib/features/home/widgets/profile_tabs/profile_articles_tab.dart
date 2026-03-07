import 'package:flutter/material.dart';
import '../../../../core/constants/app_dimens.dart';
import '../private_profile_wall.dart';

class ProfileArticlesTab extends StatelessWidget {
  const ProfileArticlesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8.0, AppDimens.spaceS, 8.0, AppDimens.spaceGiant),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.1),
        const ProfileEmptyState(
          icon: Icons.article_outlined,
          title: 'لا توجد مقالات',
          description: 'هذا المستخدم لم يقم بنشر أي مقالات بعد.',
          action: SizedBox(),
        ),
      ],
    );
  }
}
