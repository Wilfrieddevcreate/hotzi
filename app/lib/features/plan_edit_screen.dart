import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/format.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/entrance.dart';
import '../widgets/hotzi_button.dart';

/// Création ([plan] nul) ou modification d'un forfait.
class PlanEditScreen extends StatefulWidget {
  const PlanEditScreen({super.key, this.plan});

  final Plan? plan;

  @override
  State<PlanEditScreen> createState() => _PlanEditScreenState();
}

class _PlanEditScreenState extends State<PlanEditScreen> {
  static const _presets = [30, 60, 3 * 60, 6 * 60, 12 * 60, 24 * 60];
  static const _maxPrice = 1000000;

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.plan?.name ?? '');
  late final _price = TextEditingController(text: widget.plan?.priceFcfa.toString() ?? '');
  late final _description = TextEditingController(text: widget.plan?.description ?? '');
  late int _minutes = widget.plan?.durationMinutes ?? 60;
  late bool _active = widget.plan?.active ?? true;
  bool _saving = false;

  List<int> get _durations => {..._presets, ?widget.plan?.durationMinutes}.toList()..sort();

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final state = HotziScope.read(context);
    final base = widget.plan ?? Plan(name: '', durationMinutes: _minutes, priceFcfa: 0, createdAt: state.now);
    await state.savePlan(
      base.copyWith(
        name: _name.text.trim(),
        durationMinutes: _minutes,
        priceFcfa: int.parse(_price.text),
        active: _active,
        description: _description.text.trim(),
      ),
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Forfait enregistré')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Retour',
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Text(widget.plan == null ? 'Nouveau forfait' : 'Modifier le forfait', style: HotziText.display(24)),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    Entrance(
                      child: _Field(
                        label: 'Nom du forfait',
                        child: TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.sentences,
                          maxLength: 30,
                          style: HotziText.body(17),
                          decoration: const InputDecoration(hintText: 'Ex. : Standard', counterText: ''),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty) ? 'Donne un nom au forfait.' : null,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    Entrance(
                      delay: Entrance.step(1),
                      child: _Field(
                        label: 'Durée d\'Internet',
                        child: GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 2.3,
                          children: [
                            for (final minutes in _durations)
                              _DurationChoice(
                                label: Format.shortDuration(minutes),
                                selected: minutes == _minutes,
                                onTap: () => setState(() => _minutes = minutes),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Entrance(
                      delay: Entrance.step(2),
                      child: _Field(
                        label: 'Prix',
                        child: TextFormField(
                          controller: _price,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(7),
                          ],
                          style: HotziText.display(22),
                          decoration: InputDecoration(
                            hintText: 'Ex. : 100',
                            suffixText: 'FCFA',
                            suffixStyle: HotziText.body(15, weight: FontWeight.w700, color: HotziColors.ink3),
                          ),
                          validator: (value) {
                            final price = int.tryParse(value ?? '');
                            if (price == null) return 'Indique un prix.';
                            if (price > _maxPrice) return 'Ce prix est trop élevé.';
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    Entrance(
                      delay: Entrance.step(3),
                      child: _Field(
                        label: 'Petite description (si tu veux)',
                        child: TextFormField(
                          controller: _description,
                          maxLines: 2,
                          maxLength: 80,
                          style: HotziText.body(16),
                          decoration: const InputDecoration(hintText: 'Ex. : idéal pour une vidéo', counterText: ''),
                        ),
                      ),
                    ),
                    Entrance(
                      delay: Entrance.step(4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: HotziColors.line),
                        ),
                        child: SwitchListTile(
                          value: _active,
                          onChanged: (value) => setState(() => _active = value),
                          title: Text(
                            _active ? 'Proposé à la vente' : 'Caché à la vente',
                            style: HotziText.body(16, weight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Entrance(delay: Entrance.step(5), child: _preview()),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: HotziButton(label: 'Enregistrer', height: 58, fontSize: 17, onPressed: _saving ? null : _save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    final name = _name.text.trim().isEmpty ? 'Sans nom' : _name.text.trim();
    final price = int.tryParse(_price.text) ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: HotziColors.violetDeep, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sur le ticket du client', style: HotziText.body(13, color: HotziColors.onDeep)),
                Text('$name · ${Format.longDuration(_minutes)}', style: HotziText.display(18, color: Colors.white)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: HotziColors.mango, borderRadius: BorderRadius.circular(999)),
            child: Text(Format.fcfa(price), style: HotziText.display(16)),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: HotziText.body(15, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _DurationChoice extends StatelessWidget {
  const _DurationChoice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: motion(context, const Duration(milliseconds: 200)),
        decoration: BoxDecoration(
          color: selected ? HotziColors.violet : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? HotziColors.violet : HotziColors.line, width: 1.5),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: Text(label, style: HotziText.display(17, color: selected ? Colors.white : HotziColors.ink)),
            ),
          ),
        ),
      ),
    );
  }
}
