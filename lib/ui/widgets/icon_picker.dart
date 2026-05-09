import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/icon_library.dart';
import '../../theme/tokens.dart';

class IconPickerDialog extends StatefulWidget {
  final String? initial;
  const IconPickerDialog({super.key, this.initial});

  static Future<String?> show(BuildContext context, {String? initial}) =>
      showDialog<String>(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => IconPickerDialog(initial: initial),
      );

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  final _searchCtrl = TextEditingController();
  String? _selected;
  String _query = '';
  String _category = iconCategories.keys.first;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _query.isNotEmpty;
    final entries = isSearching
        ? searchIcons(_query)
        : iconCategories[_category] ?? [];

    return Dialog(
      backgroundColor: TH.bg2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 460,
        height: 500,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('pick icon',
                      style: TextStyle(
                          color: TH.fg,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text('[ cancel ]',
                        style: TextStyle(color: TH.fgMute, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: TH.s14),
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: TH.fg, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'search icons…',
                  hintStyle:
                      const TextStyle(color: TH.fgFaint, fontSize: 13),
                  prefixIcon: const Icon(LucideIcons.search,
                      size: 14, color: TH.fgMute),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: TH.line2),
                    borderRadius: BorderRadius.all(TH.r4),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: TH.green),
                    borderRadius: BorderRadius.all(TH.r4),
                  ),
                  fillColor: TH.bg1,
                  filled: true,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: TH.s8, vertical: TH.s8),
                ),
              ),
              const SizedBox(height: TH.s8),
              if (!isSearching)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final cat in iconCategories.keys)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _CategoryPill(
                            label: cat,
                            selected: _category == cat,
                            onTap: () =>
                                setState(() => _category = cat),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: TH.s8),
              Expanded(
                child: entries.isEmpty
                    ? const Center(
                        child: Text('no icons found',
                            style: TextStyle(
                                color: TH.fgFaint, fontSize: 12)))
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 48,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemCount: entries.length,
                        itemBuilder: (_, i) {
                          final e = entries[i];
                          final isSelected = _selected == e.key;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selected = e.key);
                              Navigator.of(context).pop(e.key);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? TH.bg3
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? TH.green
                                      : TH.line2,
                                ),
                                borderRadius:
                                    BorderRadius.all(TH.r4),
                              ),
                              child: Tooltip(
                                message: e.key,
                                child: Center(
                                  child: Icon(e.data,
                                      size: 18,
                                      color: isSelected
                                          ? TH.green
                                          : TH.fgDim),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryPill(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: TH.s8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? TH.green : TH.line2),
          borderRadius: BorderRadius.all(TH.r4),
          color: selected ? TH.bg3 : Colors.transparent,
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? TH.green : TH.fgDim, fontSize: 11)),
      ),
    );
  }
}
