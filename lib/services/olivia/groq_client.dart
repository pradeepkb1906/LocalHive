import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../olivia_config.dart';

/// Thrown when Olivia cannot reach her brain. The message is written to be
/// spoken aloud to the customer, not logged.
class OliviaUnavailable implements Exception {
  final String spokenMessage;
  OliviaUnavailable(this.spokenMessage);
  @override
  String toString() => spokenMessage;
}

/// Internal: this model did not work out, move to the next one in the chain.
class _TryAnotherModel implements Exception {
  final String spokenMessage;

  /// True when the same model deserves one more immediate attempt first,
  /// because the failure was stochastic rather than structural.
  final bool retrySameModel;
  _TryAnotherModel(this.spokenMessage, {this.retrySameModel = false});
}

/// One turn in the conversation, in the shape Groq's chat API expects.
class OliviaMessage {
  final String role; // 'system' | 'user' | 'assistant' | 'tool'
  final String? content;
  final List<Map<String, dynamic>>? toolCalls;
  final String? toolCallId;
  final String? name;

  const OliviaMessage({
    required this.role,
    this.content,
    this.toolCalls,
    this.toolCallId,
    this.name,
  });

  factory OliviaMessage.user(String text) =>
      OliviaMessage(role: 'user', content: text);

  factory OliviaMessage.system(String text) =>
      OliviaMessage(role: 'system', content: text);

  /// The result of running a tool, fed back so the model can use it.
  factory OliviaMessage.toolResult({
    required String toolCallId,
    required String name,
    required Object result,
  }) =>
      OliviaMessage(
        role: 'tool',
        toolCallId: toolCallId,
        name: name,
        content: jsonEncode(result),
      );

  Map<String, dynamic> toJson() => {
        'role': role,
        if (content != null) 'content': content,
        if (toolCalls != null) 'tool_calls': toolCalls,
        if (toolCallId != null) 'tool_call_id': toolCallId,
        if (name != null) 'name': name,
      };
}

/// What the model wants next: either something to say, or tools to run.
class OliviaReply {
  final String? text;
  final List<Map<String, dynamic>> toolCalls;
  final Map<String, dynamic> rawMessage;

  const OliviaReply({
    this.text,
    this.toolCalls = const [],
    this.rawMessage = const {},
  });

  bool get wantsTools => toolCalls.isNotEmpty;
}

/// Talks to Groq's chat-completions API, either through the Cloudflare Worker
/// (production, key stays server-side) or directly (local development only).
class GroqClient {
  GroqClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';

  /// True when Olivia has somewhere to send requests at all.
  static bool get isConfigured =>
      OliviaConfig.enabled &&
      (OliviaConfig.proxyUrl.isNotEmpty || OliviaConfig.groqKey.isNotEmpty);

  /// True when the key is compiled into this build — safe on localhost, not
  /// for anything published. Surfaced in the UI as a build-time warning.
  static bool get usesEmbeddedKey =>
      OliviaConfig.proxyUrl.isEmpty && OliviaConfig.groqKey.isNotEmpty;

  Uri get _endpoint => Uri.parse(
      OliviaConfig.proxyUrl.isNotEmpty ? OliviaConfig.proxyUrl : _groqUrl);

  Map<String, String> _headers(String? idToken) => {
        'Content-Type': 'application/json',
        if (OliviaConfig.proxyUrl.isNotEmpty && idToken != null)
          // The Worker checks this so only signed-in LocalHive users can
          // spend the Groq quota.
          'Authorization': 'Bearer $idToken'
        else if (OliviaConfig.proxyUrl.isEmpty)
          'Authorization': 'Bearer ${OliviaConfig.groqKey}',
      };

  /// The model that answered most recently — useful when diagnosing why a
  /// reply looked different from usual.
  String? lastModelUsed;

  /// One round trip. Returns either spoken text or a set of tool calls to run.
  ///
  /// Walks [OliviaConfig.models] in order. A model that is rate-limited, over
  /// capacity, briefly broken, or that garbles its own tool-call syntax is
  /// skipped and the next one takes over, so no single model going down takes
  /// Olivia offline. Only a genuine problem — bad sign-in, no network, every
  /// model exhausted — surfaces to the customer.
  Future<OliviaReply> complete({
    required List<OliviaMessage> messages,
    required List<Map<String, dynamic>> tools,
    String? idToken,
    int maxTokens = 700,
  }) async {
    if (!isConfigured) {
      throw OliviaUnavailable(
          'My assistant service is not set up yet on this build.');
    }

    const models = OliviaConfig.models;
    OliviaUnavailable? lastFailure;

    for (final model in models) {
      // One immediate retry on the same model first: a garbled tool call is
      // stochastic, so asking again is cheaper than switching.
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final reply = await _callModel(
            model: model,
            messages: messages,
            tools: tools,
            idToken: idToken,
            maxTokens: maxTokens,
          );
          lastModelUsed = model;
          return reply;
        } on _TryAnotherModel catch (e) {
          lastFailure = OliviaUnavailable(e.spokenMessage);
          if (!e.retrySameModel || attempt == 1) break;
        }
      }
      debugPrint('Olivia falling back from $model to the next model');
    }

    throw lastFailure ??
        OliviaUnavailable(
            'My assistant service is busy right now. Please try again in a '
            'moment.');
  }

  Future<OliviaReply> _callModel({
    required String model,
    required List<OliviaMessage> messages,
    required List<Map<String, dynamic>> tools,
    required String? idToken,
    required int maxTokens,
  }) async {
    final body = jsonEncode({
      'model': model,
      'temperature': 0.2,
      'max_tokens': maxTokens,
      'messages': messages.map((m) => m.toJson()).toList(),
      if (tools.isNotEmpty) ...{
        'tools': tools,
        'tool_choice': 'auto',
      },
    });

    http.Response resp;
    try {
      resp = await _http
          .post(_endpoint, headers: _headers(idToken), body: body)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('Olivia network error on $model: $e');
      throw _TryAnotherModel(
          "I can't reach my assistant service right now. Please check your "
          'connection and try again.');
    }

    // Rate limit or capacity: another model may well have room.
    if (resp.statusCode == 429 || resp.statusCode >= 500) {
      debugPrint('Olivia: $model returned ${resp.statusCode}');
      throw _TryAnotherModel(
          "I'm getting a lot of requests at the moment. Give me a few seconds "
          'and ask me again.');
    }
    // A bad sign-in is not the model's fault — switching would not help.
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      debugPrint('Olivia auth rejected: ${resp.statusCode}');
      throw OliviaUnavailable(
          "I couldn't verify your sign-in. Please sign out and back in.");
    }
    if (resp.statusCode != 200) {
      debugPrint('Olivia HTTP ${resp.statusCode} from $model: ${resp.body}');
      // The model sometimes emits its tool call in a malformed shape and Groq
      // rejects the whole request. Worth one more go on the same model before
      // moving on, since generation is stochastic.
      if (resp.statusCode == 400 && resp.body.contains('tool_use_failed')) {
        throw _TryAnotherModel(
            'I had trouble working that out. Please ask me again.',
            retrySameModel: true);
      }
      if (resp.statusCode == 400 && resp.body.contains('model')) {
        // e.g. a model id that is no longer served.
        throw _TryAnotherModel('That model is unavailable.');
      }
      throw OliviaUnavailable(
          'Something went wrong on my side. Please try again in a moment.');
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      throw OliviaUnavailable('I got a garbled response. Please try again.');
    }

    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw OliviaUnavailable("I didn't catch that. Could you say it again?");
    }
    final message = (choices.first as Map)['message'] as Map<String, dynamic>;
    final rawCalls = message['tool_calls'] as List?;

    return OliviaReply(
      text: message['content'] as String?,
      toolCalls: rawCalls == null
          ? const []
          : rawCalls.map((c) => Map<String, dynamic>.from(c as Map)).toList(),
      rawMessage: message,
    );
  }

  void dispose() => _http.close();
}
