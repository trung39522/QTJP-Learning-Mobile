import 'package:flutter/material.dart';

import '../../core/theme/qtjp_colors.dart';
import 'models/kana.dart';
import 'widgets/kana_detail_sheet.dart';

class AlphabetScreen extends StatefulWidget {
  const AlphabetScreen({super.key});

  @override
  State<AlphabetScreen> createState() => _AlphabetScreenState();
}

class _AlphabetScreenState extends State<AlphabetScreen> {
  KanaScript _script = KanaScript.hiragana;
  bool _showRomaji = true;

  void _openKana(Kana kana) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => KanaDetailSheet(initialKana: kana, script: _script),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bảng chữ cái Nhật')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'JAPANESE ALPHABET',
                    style: TextStyle(
                      color: QTJPColors.red,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Khởi đầu từ từng nét chữ',
                    style: TextStyle(
                      color: QTJPColors.navyDark,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chạm vào một chữ để nghe cách đọc, xem thứ tự nét viết và '
                    'chữ tương ứng ở bảng còn lại. Nét viết có thể xem khi không có mạng.',
                    style: TextStyle(color: QTJPColors.muted, height: 1.6),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (final script in KanaScript.values)
                        ChoiceChip(
                          label: Text(
                            script == KanaScript.hiragana
                                ? 'Hiragana'
                                : 'Katakana',
                          ),
                          selected: _script == script,
                          onSelected: (_) => setState(() => _script = script),
                        ),
                    ],
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hiện romaji'),
                    value: _showRomaji,
                    onChanged: (value) => setState(() => _showRomaji = value),
                  ),
                  for (final group in kanaGroups) ...[
                    const SizedBox(height: 20),
                    Text(
                      group.title,
                      style: const TextStyle(
                        color: QTJPColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: group.cells.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: group.columns,
                        mainAxisExtent:
                            60 + MediaQuery.textScalerOf(context).scale(24),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 6,
                      ),
                      itemBuilder: (context, index) {
                        final kana = group.cells[index];
                        if (kana == null) return const SizedBox.shrink();
                        final text = kana.text(_script);
                        return Semantics(
                          key: ValueKey('kana-$text'),
                          button: true,
                          label: '$text, ${kana.romaji}',
                          excludeSemantics: true,
                          onTap: () => _openKana(kana),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _openKana(kana),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    text,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      color: QTJPColors.navy,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (_showRomaji)
                                    Text(
                                      kana.romaji,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: QTJPColors.blue,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
