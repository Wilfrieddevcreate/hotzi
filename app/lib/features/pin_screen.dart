import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/entrance.dart';
import '../widgets/hotzi_logo.dart';

/// Code secret à 4 chiffres : le choisir ([creating]) ou le taper pour ouvrir Hotzi.
class PinScreen extends StatefulWidget {
  const PinScreen({super.key, this.creating = false, this.onCancel});

  final bool creating;
  final VoidCallback? onCancel;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> with SingleTickerProviderStateMixin {
  static const _length = 4;
  static const _maxFailures = 5;
  static const _blockFor = Duration(seconds: 30);

  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  String _digits = '';
  String? _first;
  String? _message;
  int _failures = 0;
  DateTime? _blockedUntil;
  Timer? _countdown;

  bool get _blocked => _blockedUntil != null && DateTime.now().isBefore(_blockedUntil!);

  String get _title {
    if (!widget.creating) return 'Entre ton code secret';
    return _first == null ? 'Choisis ton code secret' : 'Tape-le encore une fois';
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _shake.dispose();
    super.dispose();
  }

  void _press(String digit) {
    if (_blocked || _digits.length == _length) return;
    HapticFeedback.selectionClick();
    setState(() {
      _digits += digit;
      _message = null;
    });
    if (_digits.length == _length) {
      // Petite pause pour que le 4e point ait le temps de se remplir.
      Timer(const Duration(milliseconds: 160), () {
        if (mounted) _complete();
      });
    }
  }

  void _erase() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  void _complete() {
    final state = HotziScope.read(context);
    if (widget.creating) {
      if (_first == null) {
        setState(() {
          _first = _digits;
          _digits = '';
        });
      } else if (_first == _digits) {
        state.setPin(_digits);
      } else {
        _fail('Les deux codes ne sont pas pareils. Recommence.', restart: true);
      }
      return;
    }
    if (state.unlock(_digits)) return;
    _failures++;
    if (_failures >= _maxFailures) {
      _failures = 0;
      _blockedUntil = DateTime.now().add(_blockFor);
      _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (!_blocked) {
          timer.cancel();
          setState(() => _message = null);
        } else {
          setState(() => _message = _blockedMessage());
        }
      });
      _fail(_blockedMessage());
    } else {
      _fail('Ce n\'est pas le bon code.');
    }
  }

  String _blockedMessage() {
    final seconds = _blockedUntil!.difference(DateTime.now()).inSeconds + 1;
    return 'Trop d\'essais. Attends $seconds s.';
  }

  void _fail(String message, {bool restart = false}) {
    HapticFeedback.heavyImpact();
    setState(() {
      _digits = '';
      _message = message;
      if (restart) _first = null;
    });
    if (!MediaQuery.disableAnimationsOf(context)) _shake.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HotziColors.violetDeep,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: widget.onCancel == null
                      ? null
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: widget.onCancel,
                            tooltip: 'Retour',
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          ),
                        ),
                ),
                const Spacer(),
                const HotziLogo(size: 76, animate: true),
                const SizedBox(height: 6),
                Text('hotzi', style: HotziText.display(36, color: Colors.white, letterSpacing: -0.04)),
                const SizedBox(height: 22),
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: HotziText.body(18, weight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text('4 chiffres', style: HotziText.body(14, color: HotziColors.onDeep)),
                const SizedBox(height: 18),
                AnimatedBuilder(
                  animation: _shake,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(sin(_shake.value * pi * 4) * 10 * (1 - _shake.value), 0),
                    child: child,
                  ),
                  child: Semantics(
                    label: '${_digits.length} chiffres sur $_length',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < _length; i++)
                          AnimatedContainer(
                            duration: motion(context, const Duration(milliseconds: 180)),
                            margin: const EdgeInsets.symmetric(horizontal: 9),
                            width: i < _digits.length ? 20 : 18,
                            height: i < _digits.length ? 20 : 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < _digits.length ? HotziColors.mango : Colors.transparent,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: Center(
                    child: _message == null
                        ? null
                        : Text(
                            _message!,
                            textAlign: TextAlign.center,
                            style: HotziText.body(15, weight: FontWeight.w700, color: HotziColors.sun),
                          ),
                  ),
                ),
                const Spacer(),
                _Keypad(onDigit: _press, onErase: _erase, enabled: !_blocked),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onErase, required this.enabled});

  final ValueChanged<String> onDigit;
  final VoidCallback onErase;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget key(String digit) => _Key(
      onTap: enabled ? () => onDigit(digit) : null,
      child: Text(
        digit,
        style: HotziText.display(28, weight: FontWeight.w700, color: Colors.white),
      ),
    );
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final digit in row) Expanded(child: key(digit))]),
        Row(
          children: [
            const Expanded(child: SizedBox()),
            Expanded(child: key('0')),
            Expanded(
              child: _Key(
                onTap: enabled ? onErase : null,
                transparent: true,
                child: const Icon(Icons.backspace_outlined, color: Colors.white, size: 26, semanticLabel: 'Effacer'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.onTap, required this.child, this.transparent = false});

  final VoidCallback? onTap;
  final Widget child;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: transparent ? Colors.transparent : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(height: 64, child: Center(child: child)),
        ),
      ),
    );
  }
}
