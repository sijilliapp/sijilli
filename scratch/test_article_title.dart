import 'package:sijilli/models/article.dart';

void main() {
  final article = Article(
    id: 'test',
    authorId: 'test_author',
    text: '',
    postStatus: PostStatus.draft,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    audioFiles: ['e2_80_8_e_e2_81_a8_d8_b2_d9_8_a_d9_86_d8_a8_d8_a8_20_d8_a7_d9_84_d8_af_d8_b1_d8_a7_d8_b2_d9_8a_20_d9_85_d8_ad_d8_b1_d9_85_201448_a1b2c3d4e5.mp3'],
  );
  print('Computed Article Title: "${article.title}"');
}
