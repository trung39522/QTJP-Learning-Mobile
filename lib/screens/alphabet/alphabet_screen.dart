import 'package:flutter/material.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import '../../core/theme/qtjp_colors.dart';
import '../../core/widgets/qtjp_feature_intro.dart';
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
    return KyutoScaffold(
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
                  const QTJPFeatureIntro(QTJPFeature.alphabet),
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
                      style: TextStyle(
                        color: context.qtjp.heading,
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
                            color: context.qtjp.surface,
                            borderRadius: BorderRadius.circular(14),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _openKana(kana),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      text,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 26,
                                        color: context.qtjp.heading,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (_showRomaji)
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        kana.romaji,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.qtjp.blue,
                                        ),
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
