import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_colors.dart';
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
    final col = context.col;
    final isSearching = _query.isNotEmpty;
    final entries = isSearching
        ? searchIcons(_query)
        : iconCategories[_category] ?? [];

    return Dialog(
      backgroundColor: col.bg2,
      shape:
          RoundedRectangleBorder(borderRadius: const BorderRadius.all(TH.r10)),
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
                  Text('pick icon',
                      style: TextStyle(
                          color: col.fg,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text('[ cancel ]',
                        style: TextStyle(color: col.fgMute, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: TH.s14),
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(color: col.fg, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'search icons…',
                  hintStyle:
                      TextStyle(color: col.fgFaint, fontSize: 13),
                  prefixIcon: Icon(LucideIcons.search,
                      size: 14, color: col.fgMute),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: col.line2),
                    borderRadius: const BorderRadius.all(TH.r4),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: col.green),
                    borderRadius: const BorderRadius.all(TH.r4),
                  ),
                  fillColor: col.bg1,
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
                            col: col,
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
                    ? Center(
                        child: Text('no icons found',
                            style: TextStyle(
                                color: col.fgFaint, fontSize: 12)))
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
                                    ? col.bg3
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? col.green
                                      : col.line2,
                                ),
                                borderRadius:
                                    const BorderRadius.all(TH.r4),
                              ),
                              child: Tooltip(
                                message: e.key,
                                child: Center(
                                  child: Icon(e.data,
                                      size: 18,
                                      color: isSelected
                                          ? col.green
                                          : col.fgDim),
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
  final AppColors col;
  const _CategoryPill(
      {required this.label,
      required this.selected,
      required this.onTap,
      required this.col});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: TH.s8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? col.green : col.line2),
          borderRadius: const BorderRadius.all(TH.r4),
          color: selected ? col.bg3 : Colors.transparent,
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? col.green : col.fgDim, fontSize: 11)),
      ),
    );
  }
}
