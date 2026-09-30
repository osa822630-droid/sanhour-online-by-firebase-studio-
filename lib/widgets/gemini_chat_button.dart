// lib/widgets/gemini_chat_button.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/shops_provider.dart';
import '../services/gemini_service.dart';

/// زرار AI عائم يظهر في كل الشاشات الرئيسية
class GeminiChatButton extends StatelessWidget {
  const GeminiChatButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      mini: true,
      backgroundColor: const Color(0xFF5E35B1),
      tooltip: 'مساعد سنهور الذكي',
      heroTag: 'gemini_fab',
      onPressed: () => _openChat(context),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
    );
  }

  void _openChat(BuildContext context) {
    final auth = context.read<AuthProvider>();
    GeminiUserType userType;
    switch (auth.userRole) {
      case UserRole.admin:
        userType = GeminiUserType.admin;
        break;
      case UserRole.merchant:
        userType = GeminiUserType.merchant;
        break;
      default:
        userType = GeminiUserType.customer;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GeminiChatSheet(userType: userType),
    );
  }
}

class GeminiChatSheet extends StatefulWidget {
  final GeminiUserType userType;
  const GeminiChatSheet({super.key, required this.userType});

  @override
  State<GeminiChatSheet> createState() => _GeminiChatSheetState();
}

class _GeminiChatSheetState extends State<GeminiChatSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _gemini = GeminiService();
  final List<GeminiMessage> _messages = [];
  List<String> _suggestions = [];
  bool _isLoading = false;
  bool _suggestionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
    _addWelcome();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcome() {
    String welcome;
    switch (widget.userType) {
      case GeminiUserType.merchant:
        welcome = 'مرحباً أيها التاجر! أنا مساعدك الذكي في سنهور أونلاين. كيف يمكنني مساعدتك في تطوير متجرك اليوم؟';
        break;
      case GeminiUserType.admin:
        welcome = 'مرحباً! أنا مساعدك الإداري الذكي. كيف يمكنني مساعدتك في إدارة التطبيق اليوم؟';
        break;
      default:
        welcome = 'أهلاً! أنا مساعد سنهور الذكي 🌟 سأساعدك في إيجاد أفضل المحلات والعروض. بماذا تحتاج؟';
    }
    setState(() => _messages.add(GeminiMessage(text: welcome, isUser: false)));
  }

  Future<void> _loadSuggestions() async {
    final s = await _gemini.getQuickSuggestions(widget.userType);
    if (mounted) setState(() { _suggestions = s; _suggestionsLoaded = true; });
  }

  Future<void> _send([String? text]) async {
    final msg = (text ?? _controller.text).trim();
    if (msg.isEmpty || _isLoading) return;
    _controller.clear();
    setState(() {
      _messages.add(GeminiMessage(text: msg, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    String reply;
    // ✅ للمستخدم العادي: بحث ذكي حقيقي بالبيانات
    if (widget.userType == GeminiUserType.customer && context.mounted) {
      final provider = context.read<ShopsProvider>();
      final shopsData = provider.shops.take(40).map((s) => {
        'name': s.name, 'category': s.category,
        'rating': s.rating, 'location': s.location,
      }).toList();
      final productsData = provider.products.take(60).map((p) => {
        'name': p.name, 'price': p.price, 'category': p.category, 'shopId': p.shopId,
      }).toList();

      reply = await _gemini.smartSearch(
        query: msg,
        shopsSnapshot: shopsData,
        productsSnapshot: productsData,
        userType: widget.userType,
      );
    } else {
      reply = await _gemini.sendMessage(
        userMessage: msg,
        history: _messages.where((m) => !m.isUser || _messages.indexOf(m) < _messages.length - 1).toList(),
        userType: widget.userType,
      );
    }

    if (mounted) {
      setState(() {
        _messages.add(GeminiMessage(text: reply, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ─── Header ───
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4527A0), Color(0xFF7B1FA2)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('مساعد سنهور الذكي',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  widget.userType == GeminiUserType.merchant ? 'مساعد التجار'
                      : widget.userType == GeminiUserType.admin ? 'مساعد الإدارة'
                      : 'مساعدك في التسوق',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ])),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          // ─── Messages ───
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) return _buildTypingIndicator();
                return _buildMessage(_messages[i]);
              },
            ),
          ),

          // ─── Suggestions ───
          if (_suggestionsLoaded && _suggestions.isNotEmpty && _messages.length <= 2)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: _suggestions.length,
                itemBuilder: (_, i) => ActionChip(
                  label: Text(_suggestions[i], style: const TextStyle(fontSize: 12)),
                  backgroundColor: const Color(0xFF5E35B1).withValues(alpha: 0.08),
                  side: BorderSide(color: const Color(0xFF5E35B1).withValues(alpha: 0.3)),
                  onPressed: () => _send(_suggestions[i]),
                ),
              ),
            ),

          // ─── Input ───
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'اكتب سؤالك...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white10 : Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _send,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4527A0), Color(0xFF7B1FA2)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(GeminiMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF4527A0), Color(0xFF7B1FA2)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? const Color(0xFF5E35B1)
                    : Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2D2D2D) : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                ),
              ),
              child: Text(msg.text,
                style: TextStyle(
                  color: msg.isUser ? Colors.white : null,
                  fontSize: 14, height: 1.5,
                )),
            ),
          ),
          if (msg.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF4527A0), Color(0xFF7B1FA2)]),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2D2D2D) : Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18), topRight: Radius.circular(18),
              bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _dot(0), const SizedBox(width: 4), _dot(150), const SizedBox(width: 4), _dot(300),
          ]),
        ),
      ]),
    );
  }

  Widget _dot(int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (_, v, __) => Opacity(
        opacity: v,
        child: Container(width: 7, height: 7,
            decoration: BoxDecoration(color: Colors.deepPurple.withValues(alpha: 0.7), shape: BoxShape.circle)),
      ),
    );
  }
}
