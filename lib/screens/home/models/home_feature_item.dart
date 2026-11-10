enum HomeFeatureAccent { blue, red }

class HomeFeatureItem {
  const HomeFeatureItem({
    required this.id,
    required this.number,
    required this.symbol,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.actionLabel,
    required this.accent,
    this.supportsJlptLevel = false,
  });

  final String id;
  final String number;
  final String symbol;
  final String title;
  final String subtitle;
  final String description;
  final String actionLabel;
  final HomeFeatureAccent accent;
  final bool supportsJlptLevel;
}

const homeFeatureItems = <HomeFeatureItem>[
  HomeFeatureItem(
    id: 'alphabet',
    number: '01',
    symbol: 'あ',
    title: 'Bảng chữ cái Nhật',
    subtitle: 'Khởi đầu từ Hiragana và Katakana',
    description:
        'Làm quen mặt chữ, cách đọc, luyện nhận diện và phát âm tiếng Nhật.',
    actionLabel: 'Học bảng chữ cái',
    accent: HomeFeatureAccent.blue,
  ),
  HomeFeatureItem(
    id: 'flashcard',
    number: '02',
    symbol: '語',
    title: 'Flashcard từ vựng',
    subtitle: 'Học từ vựng theo cấp độ N5–N1',
    description:
        'Lật thẻ để học Kanji, cách đọc, nghĩa tiếng Việt và ghi nhớ lâu hơn.',
    actionLabel: 'Khám phá Flashcard',
    accent: HomeFeatureAccent.red,
    supportsJlptLevel: true,
  ),
  HomeFeatureItem(
    id: 'grammar',
    number: '03',
    symbol: '文',
    title: 'Ngữ pháp tiếng Nhật',
    subtitle: 'Tra cứu và học theo cấp độ',
    description: 'Xem cấu trúc, cách sử dụng, ví dụ minh họa và bảng chia thể.',
    actionLabel: 'Học ngữ pháp',
    accent: HomeFeatureAccent.blue,
    supportsJlptLevel: true,
  ),
  HomeFeatureItem(
    id: 'dictionary',
    number: '04',
    symbol: '辞',
    title: 'Từ điển Nhật – Việt',
    subtitle: 'Tra từ nhanh khi đang học',
    description:
        'Tìm từ tiếng Nhật, xem nghĩa, cách đọc, ví dụ và lịch sử tra cứu.',
    actionLabel: 'Mở từ điển',
    accent: HomeFeatureAccent.red,
  ),
  HomeFeatureItem(
    id: 'writing',
    number: '05',
    symbol: '書',
    title: 'Luyện viết với AI',
    subtitle: 'Nhận phản hồi để cải thiện bài viết',
    description:
        'Luyện theo chủ đề và nhận góp ý về ngữ pháp, từ vựng, cách diễn đạt.',
    actionLabel: 'Bắt đầu luyện viết',
    accent: HomeFeatureAccent.blue,
  ),
  HomeFeatureItem(
    id: 'exam',
    number: '06',
    symbol: '試',
    title: 'Thi thử JLPT',
    subtitle: 'Luyện đề và xem lại kết quả',
    description:
        'Làm đề theo cấp độ N5–N1, tính thời gian và theo dõi lịch sử thi.',
    actionLabel: 'Xem đề thi JLPT',
    accent: HomeFeatureAccent.red,
    supportsJlptLevel: true,
  ),
  HomeFeatureItem(
    id: 'video',
    number: '07',
    symbol: '映',
    title: 'Học qua video',
    subtitle: 'Tiếng Nhật trong nội dung thực tế',
    description: 'Luyện nghe và khám phá từ vựng, ngữ pháp trong từng video.',
    actionLabel: 'Khám phá video',
    accent: HomeFeatureAccent.blue,
  ),
];
