import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/address_search.dart';
import '../theme.dart';

/// An address input the way map apps do it: type a few characters and pick
/// from live suggestions, or tap the location arrow to fill in the street
/// address of where you are standing right now. Used everywhere the app asks
/// for a street/city/state address.
class AddressField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;

  /// Injectable lookups so widget tests never hit the network.
  final Future<List<AddressSuggestion>> Function(String) search;
  final Future<String?> Function() locate;

  const AddressField({
    super.key,
    required this.controller,
    required this.hintText,
    this.search = searchUsAddresses,
    this.locate = currentStreetAddress,
  });

  @override
  State<AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<AddressField> {
  Timer? _debounce;
  List<AddressSuggestion> _suggestions = const [];
  bool _locating = false;

  /// Set when a suggestion or the locate button fills the field, so the
  /// resulting text change does not immediately re-open the list.
  bool _justFilled = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String text) {
    if (_justFilled) {
      _justFilled = false;
      return;
    }
    _debounce?.cancel();
    if (text.trim().length < 3) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    // Debounced so a fast typist causes one lookup, not one per keystroke —
    // Nominatim's fair-use policy expects at most one request a second.
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await widget.search(text);
      if (!mounted || widget.controller.text != text) return;
      setState(() => _suggestions = results);
    });
  }

  void _pick(AddressSuggestion s) {
    _justFilled = true;
    widget.controller.text = s.address;
    setState(() => _suggestions = const []);
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _suggestions = const [];
    });
    final address = await widget.locate();
    if (!mounted) return;
    setState(() => _locating = false);
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not read your location — allow location '
              'access, or type the address.')));
      return;
    }
    _justFilled = true;
    widget.controller.text = address;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Filled in your current address — adjust the unit '
              'or house number if needed.')));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          textCapitalization: TextCapitalization.words,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(CupertinoIcons.search,
                color: LhColors.inkSecondary, size: 20),
            suffixIcon: _locating
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    tooltip: 'Use my current location',
                    icon: const Icon(CupertinoIcons.location_fill,
                        color: LhColors.blue, size: 20),
                    onPressed: _useMyLocation,
                  ),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 6),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < _suggestions.length; i++) ...[
                  ListTile(
                    dense: true,
                    leading: const Icon(CupertinoIcons.map_pin_ellipse,
                        size: 18, color: LhColors.inkSecondary),
                    title: Text(_suggestions[i].title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(_suggestions[i].address,
                        style: const TextStyle(
                            fontSize: 12.5, color: LhColors.inkSecondary)),
                    onTap: () => _pick(_suggestions[i]),
                  ),
                  if (i != _suggestions.length - 1)
                    const Padding(
                        padding: EdgeInsets.only(left: 48), child: Divider()),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
