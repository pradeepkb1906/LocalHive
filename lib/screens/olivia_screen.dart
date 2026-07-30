import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../services/olivia/groq_client.dart';
import '../services/olivia/olivia_session.dart';
import '../services/olivia/olivia_voice.dart';
import '../theme.dart';
import '../widgets/olivia/olivia_avatar.dart';
import '../widgets/olivia/olivia_lipsync.dart';
import '../widgets/olivia/olivia_stage.dart';
import '../widgets/olivia/olivia_video.dart';
import '../widgets/olivia/order_confirm_card.dart';
import 'profile_screen.dart';

/// Talk to Olivia — the conversational way into LocalHive.
///
/// The customer holds the button and speaks; Olivia looks things up, works out
/// an order, and shows it for confirmation. She can talk, but she cannot place
/// anything: the confirm card does that, and only when tapped.
class OliviaScreen extends StatefulWidget {
  const OliviaScreen({super.key});

  @override
  State<OliviaScreen> createState() => _OliviaScreenState();
}

class _OliviaScreenState extends State<OliviaScreen> {
  final OliviaSession _session = OliviaSession();
  final OliviaVoice _voice = OliviaVoice();
  final ScrollController _scroll = ScrollController();
  // Held as a field, not built inline: this screen rebuilds on every partial
  // speech result, which would otherwise wipe whatever was being typed.
  final TextEditingController _typed = TextEditingController();

  bool _muted = false;
  bool _placing = false;
  bool _micDenied = false;
  String? _placedMessage;

  static const _greeting =
      "Hi, I'm Olivia. Tell me what you need — food from a truck nearby, "
      'groceries from an Indian store, or a cleaner for a few hours.';

  static const _openers = [
    'Any biryani near me right now?',
    'I need a cleaner tomorrow morning',
    'Order groceries for delivery',
    'Where is my order?',
  ];

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _greet());
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    _voice.dispose();
    _scroll.dispose();
    _typed.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() {});
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _greet() async {
    if (!_session.isConfigured) return;
    _session.transcript.add(const OliviaTurn(false, _greeting));
    if (mounted) setState(() {});
    if (!_muted) await _voice.speak(_greeting);
  }

  Future<void> _startListening() async {
    await _voice.stopSpeaking();
    final ok = await _voice.listen(
      onPartial: _session.showPartial,
      onFinal: (text) {
        _session.clearPartial();
        _handleUtterance(text);
      },
    );
    if (!ok && mounted) {
      setState(() => _micDenied = true);
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _stopListening() async {
    await _voice.stopListening();
    if (mounted) setState(() {});
  }

  Future<void> _handleUtterance(String text) async {
    if (text.trim().isEmpty) return;
    final reply = await _session.ask(text);
    if (reply != null && !_muted && mounted) {
      await _voice.speak(reply);
    }
  }

  /// The one place a conversation turns into a real booking.
  Future<void> _confirmDraft() async {
    final draft = _session.pendingDraft;
    if (draft == null || !draft.isReady) return;

    if (!AppState.instance.signedIn) {
      await _voice.speak('Please sign in first so I can save your order.');
      if (mounted) {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SignInScreen()));
      }
      return;
    }

    setState(() => _placing = true);
    final id = await AppState.instance.addBookingAndWait(draft.toBooking());
    if (!mounted) return;

    final ok = id != null;
    final spoken = ok
        ? (draft.kind == 'home_service'
            ? '${draft.providerName} has your request and will confirm shortly. '
                'You pay them directly on the day.'
            : "That's in with ${draft.providerName}. "
                'Pay them \$${draft.total.toStringAsFixed(2)} when you '
                '${draft.isDelivery ? 'get it' : 'collect it'}.')
        : "I couldn't save that. Please check your connection and try again.";

    if (ok) {
      _session.noteOrderPlaced(draft.providerName, draft.detail);
      _session.clearDraft();
    }

    setState(() {
      _placing = false;
      _placedMessage = ok ? spoken : null;
    });
    _session.transcript.add(OliviaTurn(false, spoken));
    if (!_muted) await _voice.speak(spoken);
  }

  void _cancelDraft() {
    _session.clearDraft();
    const said = 'No problem, I have cancelled that. Anything else?';
    _session.transcript.add(const OliviaTurn(false, said));
    setState(() {});
    if (!_muted) _voice.speak(said);
  }

  // --------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    if (!_session.isConfigured) return _unavailable();

    final state = _session.state;
    final listening = _voice.isListening;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Olivia'),
        actions: [
          IconButton(
            tooltip: _muted ? 'Unmute Olivia' : 'Mute Olivia',
            icon: Icon(
                _muted
                    ? CupertinoIcons.speaker_slash_fill
                    : CupertinoIcons.speaker_2_fill,
                size: 20),
            onPressed: () {
              setState(() => _muted = !_muted);
              if (_muted) _voice.stopSpeaking();
            },
          ),
          IconButton(
            tooltip: 'Start over',
            icon: const Icon(CupertinoIcons.refresh, size: 20),
            onPressed: () {
              _voice.stopSpeaking();
              _session.reset();
              setState(() {
                _placedMessage = null;
                _micDenied = false;
              });
              _greet();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _header(state, listening),
          const Divider(height: 1),
          Expanded(child: _transcript()),
          _composer(listening),
        ],
      ),
    );
  }

  Widget _header(OliviaState state, bool listening) {
    // Full width, and as much height as the window can spare — she should be
    // visible from the LocalHive sign behind her down to her sweater, not
    // cropped to a band across her eyes.
    final height = OliviaStage.heightIn(MediaQuery.sizeOf(context));

    return Container(
      width: double.infinity,
      color: LhColors.surface,
      child: Column(
        children: [
          // Olivia is her video clip. If it cannot play, the next best thing
          // is the set of mouth frames cut from that same clip driven by her
          // speech, then the still photo, then the drawn face. Each one crops
          // to fill this box, so they all sit in exactly the same place.
          SizedBox(
            height: height,
            width: double.infinity,
            child: ValueListenableBuilder<double>(
              valueListenable: _voice.mouthOpen,
              builder: (context, mouth, _) => OliviaVideo(
                expand: true,
                speaking: _voice.isSpeaking,
                listening: listening,
                thinking: state == OliviaState.thinking,
                fallback: OliviaLipSync(
                  expand: true,
                  mouthOpen: mouth,
                  speaking: _voice.isSpeaking,
                  listening: listening,
                  thinking: state == OliviaState.thinking,
                  // The drawn face is a circle, so it centres in the space
                  // rather than filling it.
                  fallback: Center(
                    child: OliviaAvatar(
                      size: height - 24,
                      mouthOpen: mouth,
                      listening: listening,
                      thinking: state == OliviaState.thinking,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            switch (state) {
              OliviaState.listening => 'Listening…',
              OliviaState.thinking => 'Looking that up…',
              _ => listening
                  ? 'Listening…'
                  : _voice.isSpeaking
                      ? 'Speaking'
                      : 'Your LocalHive assistant',
            },
            style: const TextStyle(fontSize: 13, color: LhColors.inkSecondary),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _transcript() {
    final turns = _session.transcript;
    final draft = _session.pendingDraft;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      children: [
        if (GroqClient.usesEmbeddedKey) _devKeyWarning(),
        for (final turn in turns) _bubble(turn),
        if (draft != null) ...[
          const SizedBox(height: 6),
          OrderConfirmCard(
            draft: draft,
            busy: _placing,
            onConfirm: _confirmDraft,
            onCancel: _cancelDraft,
          ),
        ],
        if (_placedMessage != null) ...[
          const SizedBox(height: 10),
          _placedBanner(),
        ],
        if (turns.length <= 1 && draft == null) ...[
          const SizedBox(height: 14),
          _suggestions(),
        ],
        if (_micDenied) ...[
          const SizedBox(height: 12),
          _micHelp(),
        ],
      ],
    );
  }

  Widget _bubble(OliviaTurn turn) {
    final mine = turn.fromCustomer;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine
              ? LhColors.blue.withValues(alpha: turn.isPartial ? 0.45 : 1)
              : LhColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: mine ? null : Border.all(color: LhColors.hairline),
        ),
        child: Text(
          turn.text,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.35,
            fontStyle: turn.isPartial ? FontStyle.italic : FontStyle.normal,
            color: mine ? Colors.white : LhColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _suggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TRY ASKING',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: LhColors.inkSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opener in _openers)
              ActionChip(
                label: Text(opener, style: const TextStyle(fontSize: 12.5)),
                onPressed: () => _handleUtterance(opener),
              ),
          ],
        ),
      ],
    );
  }

  Widget _placedBanner() {
    return Card(
      color: LhColors.green.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(CupertinoIcons.checkmark_seal_fill,
                color: LhColors.green, size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('All set — you can follow it in the Bookings tab.',
                  style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _devKeyWarning() {
    return Card(
      color: LhColors.orange.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(CupertinoIcons.exclamationmark_shield_fill,
                color: LhColors.orange, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                  'Development build: the Groq key is compiled in. Deploy the '
                  'proxy before publishing this app.',
                  style:
                      TextStyle(fontSize: 11.5, color: LhColors.inkSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _micHelp() {
    return Card(
      color: LhColors.orange.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(CupertinoIcons.mic_slash_fill,
                color: LhColors.orange, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                  'I cannot hear you — microphone access is off. Allow it in '
                  'your settings, or just type to me instead.',
                  style: TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(bool listening) {
    final busy = _session.state == OliviaState.thinking || _placing;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: LhColors.surface,
          border: Border(top: BorderSide(color: LhColors.hairline)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTapDown: busy ? null : (_) => _startListening(),
                onTapUp: (_) => _stopListening(),
                onTapCancel: _stopListening,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: busy
                        ? LhColors.hairline
                        : listening
                            ? LhColors.green
                            : LhColors.navy,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          listening
                              ? CupertinoIcons.waveform
                              : CupertinoIcons.mic_fill,
                          color: Colors.white,
                          size: 20),
                      const SizedBox(width: 10),
                      Text(
                          busy
                              ? 'One moment…'
                              : listening
                                  ? 'Listening — release when done'
                                  : 'Hold to talk to Olivia',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _typeRow(busy),
          ],
        ),
      ),
    );
  }

  /// Typing is always available: web microphones are unreliable, and some
  /// people would simply rather type.
  Widget _typeRow(bool busy) {
    void send() {
      final text = _typed.text.trim();
      if (text.isEmpty) return;
      _typed.clear();
      _handleUtterance(text);
    }

    return Row(
      children: [
        Expanded(
          // Enter is handled here rather than relying on onSubmitted, which
          // does not fire dependably for a send action on Flutter web.
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.enter): _SendIntent(),
              SingleActivator(LogicalKeyboardKey.numpadEnter): _SendIntent(),
            },
            child: Actions(
              actions: {
                _SendIntent: CallbackAction<_SendIntent>(onInvoke: (_) {
                  send();
                  return null;
                }),
              },
              child: TextField(
                controller: _typed,
                enabled: !busy,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => send(),
                decoration: const InputDecoration(
                  hintText: 'or type your request',
                  isDense: true,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          height: 44,
          child: FilledButton(
            onPressed: busy ? null : send,
            style: compactButtonStyle(width: 48, height: 44),
            child: const Icon(CupertinoIcons.arrow_up, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _unavailable() {
    return Scaffold(
      appBar: AppBar(title: const Text('Olivia')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const OliviaAvatar(size: 130),
              const SizedBox(height: 16),
              const Text('Olivia is coming soon',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                  'She will take your order by voice — a food truck nearby, '
                  'groceries from an Indian store, or a cleaner for a few '
                  'hours. Everything else in LocalHive works now.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 13.5, color: LhColors.inkSecondary)),
              // How to actually switch her on. Only in a debug build: on the
              // public site this screen is read by people wanting the app, not
              // by whoever builds it.
              if (kDebugMode) ...[
                const SizedBox(height: 20),
                const Text(
                    'Set OliviaConfig.proxyUrl to the deployed '
                    'worker/olivia-proxy, or groqKey for local development.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: LhColors.orange)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pressing Enter in the type-to-Olivia field sends the message.
class _SendIntent extends Intent {
  const _SendIntent();
}
