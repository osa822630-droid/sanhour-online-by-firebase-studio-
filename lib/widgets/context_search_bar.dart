// lib/widgets/context_search_bar.dart
// شريط بحث موحّد قابل للتخصيص لكل شاشة
// يدعم: hint مخصّص، فلاتر inline، بحث صوتي، فتح البحث المتقدم
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

/// وصف فلتر واحد يُعرَض داخل شريط البحث
class SearchFilter {
  final String id;
  final String label;
  final List<String> options;
  String selectedOption;

  SearchFilter({
    required this.id,
    required this.label,
    required this.options,
    String? defaultOption,
  }) : selectedOption = defaultOption ?? options.first;
}

class ContextSearchBar extends StatefulWidget {
  /// النص التوضيحي داخل الحقل
  final String hint;

  /// يُستدعى عند تغيير نص البحث (مع debounce 400ms)
  final ValueChanged<String> onSearch;

  /// يُستدعى عند تغيير قيمة أي فلتر — id الفلتر + القيمة الجديدة
  final void Function(String filterId, String value)? onFilterChanged;

  /// قائمة الفلاتر المتاحة (اختياري — تظهر زر filter عند وجودها)
  final List<SearchFilter> filters;

  /// فتح شاشة البحث المتقدم (اختياري)
  final VoidCallback? onAdvancedSearch;

  /// FocusNode خارجي للتحكم في التركيز من AppBar
  final FocusNode? focusNode;

  /// هل يظهر الزر الأيمن (البحث المتقدم أو الفلاتر)؟
  final bool showFilterButton;

  const ContextSearchBar({
    super.key,
    required this.hint,
    required this.onSearch,
    this.onFilterChanged,
    this.filters = const [],
    this.onAdvancedSearch,
    this.focusNode,
    this.showFilterButton = true,
  });

  @override
  State<ContextSearchBar> createState() => _ContextSearchBarState();
}

class _ContextSearchBarState extends State<ContextSearchBar>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;
  late final stt.SpeechToText _speech;
  late final AnimationController _filterAnim;
  late final Animation<double> _filterFade;

  Timer? _debounce;
  bool _isListening = false;
  bool _filtersExpanded = false;
  bool _hasActiveFilter = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _speech = stt.SpeechToText();
    _filterAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _filterFade = CurvedAnimation(
        parent: _filterAnim, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _speech.stop();
    _filterAnim.dispose();
    // لا نتصرف في _focusNode إذا أُعطيَ من الخارج
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      widget.onSearch(q);
    });
  }

  void _clear() {
    _ctrl.clear();
    setState(() {});
    widget.onSearch('');
    _focusNode.unfocus();
  }

  Future<void> _listen() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى السماح بصلاحية الميكروفون')),
      );
      return;
    }
    if (!_isListening) {
      final ok = await _speech.initialize();
      if (ok && mounted) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            if (!mounted) return;
            _ctrl.text = val.recognizedWords;
            _ctrl.selection = TextSelection.fromPosition(
                TextPosition(offset: _ctrl.text.length));
            setState(() {});
            widget.onSearch(val.recognizedWords);
          },
          localeId: 'ar_EG',
        );
      }
    } else {
      if (mounted) setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _toggleFilters() {
    setState(() => _filtersExpanded = !_filtersExpanded);
    if (_filtersExpanded) {
      _filterAnim.forward();
    } else {
      _filterAnim.reverse();
    }
  }

  bool _checkActiveFilters() {
    return widget.filters.any((f) => f.selectedOption != f.options.first);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _hasActiveFilter = _checkActiveFilters();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── شريط البحث الرئيسي ───────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252535) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? const Color(0xFF5E35B1)
                  : Colors.grey.withValues(alpha: 0.25),
              width: _focusNode.hasFocus ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(Icons.search, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: TextStyle(
                        color: Colors.grey[400], fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: _onChanged,
                  onSubmitted: (v) {
                    widget.onSearch(v);
                    _focusNode.unfocus();
                  },
                ),
              ),
              // ── أيقونات اليمين ────────────────────────────────
              if (_ctrl.text.isNotEmpty)
                GestureDetector(
                  onTap: _clear,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close, size: 18, color: Colors.grey),
                  ),
                ),
              // بحث صوتي
              GestureDetector(
                onTap: _listen,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 20,
                    color: _isListening
                        ? const Color(0xFF5E35B1)
                        : Colors.grey,
                  ),
                ),
              ),
              // ── زر الفلاتر أو البحث المتقدم ─────────────────
              if (widget.showFilterButton) ...[
                Container(
                  width: 1,
                  height: 22,
                  color: Colors.grey.withValues(alpha: 0.2),
                ),
                GestureDetector(
                  onTap: widget.filters.isNotEmpty
                      ? _toggleFilters
                      : widget.onAdvancedSearch,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          widget.filters.isNotEmpty
                              ? Icons.tune
                              : Icons.manage_search,
                          color: (_filtersExpanded || _hasActiveFilter)
                              ? const Color(0xFF5E35B1)
                              : Colors.grey,
                          size: 22,
                        ),
                        if (_hasActiveFilter)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF5E35B1),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── الفلاتر المنسدلة ─────────────────────────────────────
        if (widget.filters.isNotEmpty)
          FadeTransition(
            opacity: _filterFade,
            child: SizeTransition(
              sizeFactor: _filterFade,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...widget.filters.map(
                      (filter) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildFilterRow(filter, isDark),
                      ),
                    ),
                    // زر البحث المتقدم (إذا توفر)
                    if (widget.onAdvancedSearch != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: widget.onAdvancedSearch,
                          icon: const Icon(Icons.manage_search,
                              size: 16, color: Color(0xFF5E35B1)),
                          label: const Text(
                            'بحث متقدم',
                            style: TextStyle(
                                color: Color(0xFF5E35B1), fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterRow(SearchFilter filter, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          filter.label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500]),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filter.options.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final opt = filter.options[i];
              final isSelected = filter.selectedOption == opt;
              return GestureDetector(
                onTap: () {
                  setState(() => filter.selectedOption = opt);
                  _hasActiveFilter = _checkActiveFilters();
                  widget.onFilterChanged?.call(filter.id, opt);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF5E35B1)
                        : (isDark
                            ? Colors.grey[800]
                            : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                              ? Colors.grey[300]
                              : Colors.grey[700]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
