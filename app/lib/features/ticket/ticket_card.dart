import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/ticket_codes.dart';
import '../../theme/colors.dart';
import '../../theme/text.dart';
import '../../widgets/hotzi_logo.dart';
import '../../widgets/status_chip.dart';

/// Carte du ticket, telle qu'on la montre au client et qu'on la partage en image.
/// Le QR code ne contient que le code d'accès : ni lien, ni donnée personnelle.
class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.ticket});

  final Ticket ticket;

  static const _notch = 24.0;

  @override
  Widget build(BuildContext context) {
    final code = TicketCodes.format(ticket.code);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x1F2D1A7A), blurRadius: 30, offset: Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: HotziColors.violetDeep,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const HotziLogo(size: 20),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Wi-Fi Hotzi',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HotziText.body(13, weight: FontWeight.w700, color: HotziColors.onDeep),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(ticket.planName, style: HotziText.display(23, color: Colors.white)),
                      Text(
                        '${Format.longDuration(ticket.durationMinutes)} · ${Format.fcfa(ticket.priceFcfa)}',
                        style: HotziText.body(15, color: HotziColors.onDeep),
                      ),
                    ],
                  ),
                ),
                ticket.status == TicketStatus.available
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: HotziColors.mango, borderRadius: BorderRadius.circular(999)),
                        child: Text('Disponible', style: HotziText.body(12, weight: FontWeight.w800)),
                      )
                    : StatusChip(ticket.status),
              ],
            ),
          ),
          // Les encoches du ticket sont posées sur le haut du corps : elles suivent
          // l'en-tête quelle que soit sa hauteur (texte agrandi, nom long…).
          Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  children: [
                    Semantics(
                      label: 'QR code du ticket $code',
                      image: true,
                      child: QrImageView(
                        data: ticket.code,
                        size: 168,
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: HotziColors.ink),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: HotziColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FittedBox(child: Text(code, style: HotziText.mono(30))),
                    const SizedBox(height: 4),
                    Text(
                      'Le temps démarre à la première connexion.',
                      textAlign: TextAlign.center,
                      style: HotziText.body(14, color: HotziColors.ink2),
                    ),
                  ],
                ),
              ),
              for (final left in [true, false])
                Positioned(
                  top: -_notch / 2,
                  left: left ? -_notch / 2 : null,
                  right: left ? null : -_notch / 2,
                  child: Container(
                    width: _notch,
                    height: _notch,
                    decoration: const BoxDecoration(color: HotziColors.ground, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
