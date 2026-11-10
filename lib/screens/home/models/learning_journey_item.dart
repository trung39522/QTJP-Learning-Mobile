class LearningJourneyItem {
  const LearningJourneyItem({
    required this.number,
    required this.symbol,
    required this.tag,
    required this.title,
    required this.description,
    required this.actionLabel,
  });

  final String number;
  final String symbol;
  final String tag;
  final String title;
  final String description;
  final String actionLabel;
}

const learningJourneyItems = <LearningJourneyItem>[
  LearningJourneyItem(
    number: '01',
    symbol: 'あ',
    tag: 'CHÂN NÚI · KHỞI HÀNH',
    title: 'Làm quen',
    description:
        'Bắt đầu với Hiragana, Katakana và tập nhận diện mặt chữ, đọc đúng âm.',
    actionLabel: 'Học bảng chữ cái',
  ),
  LearningJourneyItem(
    number: '02',
    symbol: '語',
    tag: 'SƯỜN NÚI · TÍCH LŨY',
    title: 'Xây nền kiến thức',
    description:
        'Ghi nhớ từ vựng qua Flashcard và kết hợp ngữ pháp theo cấp độ JLPT.',
    actionLabel: 'Khám phá Flashcard',
  ),
  LearningJourneyItem(
    number: '03',
    symbol: '書',
    tag: 'LƯNG NÚI · VẬN DỤNG',
    title: 'Thực hành mỗi ngày',
    description:
        'Luyện viết, nhận AI góp ý và học từ nội dung tiếng Nhật thực tế.',
    actionLabel: 'Luyện viết với AI',
  ),
  LearningJourneyItem(
    number: '04',
    symbol: '試',
    tag: 'ĐỈNH NÚI · CHINH PHỤC',
    title: 'Kiểm tra tiến bộ',
    description:
        'Thử sức với đề JLPT N5–N1, xem kết quả và củng cố kiến thức còn yếu.',
    actionLabel: 'Thi thử JLPT',
  ),
];
