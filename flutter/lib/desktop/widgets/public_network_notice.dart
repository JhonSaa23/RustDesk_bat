import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/tabbar_widget.dart';

/// Diálogo modal con el anuncio de advertencia sobre la red pública y el límite de 3 minutos.
void showPublicNetworkNoticeDialog(BuildContext context, {bool isExpired = false}) {
  showDialog(
    context: context,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF1E2028),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.security_rounded,
                  color: Color(0xFFEF4444),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isExpired
                    ? "Sesión Finalizada (Límite de 3 Minutos)"
                    : "Advertencia de Seguridad",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Proyecto público: Su equipo puede ser vulnerado con la red pública de RustDesk.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFCA5A5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isExpired
                    ? "La sesión remota se ha cerrado automáticamente porque se alcanzaron los 3 minutos máximos establecidos.\n\nPuede volver a conectarse inmediatamente; cada nueva sesión iniciará un nuevo contador de 3 minutos."
                    : "Este es un proyecto público. Tenga en cuenta que su equipo puede ser vulnerado a través de la red pública de RustDesk.\n\nPor motivos de seguridad, cada sesión remota cuenta con un temporizador estricto de 3 minutos y se cerrará automáticamente al finalizar el tiempo. Puede volver a entrar una y otra vez.",
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.4,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    "Entendido",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Badge contador regresivo de 3 minutos visible en el header/tabbar de la sesión remota.
class SessionCountdownBadge extends StatefulWidget {
  final DesktopTabController tabController;
  final VoidCallback? onExpire;

  const SessionCountdownBadge({
    Key? key,
    required this.tabController,
    this.onExpire,
  }) : super(key: key);

  @override
  State<SessionCountdownBadge> createState() => _SessionCountdownBadgeState();
}

class _SessionCountdownBadgeState extends State<SessionCountdownBadge> {
  static const int kInitialCountdownSeconds = 180; // 3 minutos
  int _remainingSeconds = kInitialCountdownSeconds;
  Timer? _timer;
  StreamSubscription? _tabSubscription;
  final Set<String> _activeTabs = {};

  @override
  void initState() {
    super.initState();
    _activeTabs.addAll(widget.tabController.state.value.tabs.map((t) => t.key));
    if (_activeTabs.isNotEmpty) {
      _startCountdown();
    }
    _tabSubscription = widget.tabController.state.listen((tabState) {
      final currentKeys = tabState.tabs.map((t) => t.key).toSet();
      if (currentKeys.isEmpty) {
        _timer?.cancel();
        _activeTabs.clear();
        _remainingSeconds = kInitialCountdownSeconds;
        if (mounted) setState(() {});
        return;
      }

      final hasNewTab = currentKeys.difference(_activeTabs).isNotEmpty;
      final wasEmpty = _activeTabs.isEmpty;
      _activeTabs
        ..clear()
        ..addAll(currentKeys);

      // Reiniciar contador de 3 minutos cada vez que entra una sesión o se reconecta
      if (hasNewTab ||
          wasEmpty ||
          _remainingSeconds <= 0 ||
          _timer == null ||
          !_timer!.isActive) {
        _startCountdown();
      }
    });
  }

  void _startCountdown() {
    _timer?.cancel();
    _remainingSeconds = kInitialCountdownSeconds;
    if (mounted) setState(() {});

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        if (mounted) {
          setState(() {
            _remainingSeconds--;
          });
        }
      } else {
        timer.cancel();
        _onTimeExpired();
      }
    });
  }

  void _onTimeExpired() {
    _timer?.cancel();
    _remainingSeconds = kInitialCountdownSeconds;
    _activeTabs.clear();
    if (!mounted) return;
    if (widget.onExpire != null) {
      widget.onExpire!();
    } else {
      final tabKeys =
          widget.tabController.state.value.tabs.map((t) => t.key).toList();
      for (final key in tabKeys) {
        widget.tabController.closeBy(key);
      }
      try {
        widget.tabController.clear();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_activeTabs.isEmpty && widget.tabController.state.value.tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final isCritical = _remainingSeconds <= 30;
    final isWarning = _remainingSeconds <= 60;

    final badgeColor = isCritical
        ? const Color(0xFFDC2626)
        : (isWarning ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));

    return Tooltip(
      message:
          "⚠️ AVISO: Proyecto público. Su equipo puede ser vulnerado en la red pública de RustDesk.\nSesión limitada a 3 minutos ($minutes:$seconds restantes). Clic para más detalles.",
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showPublicNetworkNoticeDialog(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(isCritical ? 0.28 : 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: badgeColor.withOpacity(isCritical ? 0.9 : 0.6),
                width: isCritical ? 1.6 : 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isWarning ? Icons.warning_amber_rounded : Icons.timer_outlined,
                  size: 13,
                  color: badgeColor,
                ),
                const SizedBox(width: 4),
                Text(
                  "$minutes:$seconds",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isCritical ? "Cierre inminente" : "Red Pública",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner flotante de advertencia al conectarse a una sesión remota.
class RemoteSessionSecurityBanner extends StatefulWidget {
  const RemoteSessionSecurityBanner({Key? key}) : super(key: key);

  @override
  State<RemoteSessionSecurityBanner> createState() =>
      _RemoteSessionSecurityBannerState();
}

class _RemoteSessionSecurityBannerState
    extends State<RemoteSessionSecurityBanner> {
  bool _dismissed = false;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _autoDismissTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) {
        setState(() {
          _dismissed = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B18).withOpacity(0.95),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFF59E0B).withOpacity(0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ADVERTENCIA DE SEGURIDAD • RED PÚBLICA",
                      style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Este es un proyecto público. Tenga en cuenta que su equipo puede ser vulnerado a través de la red pública de RustDesk. La sesión se cerrará automáticamente en 3 minutos.",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: "Cerrar anuncio",
                onPressed: () {
                  setState(() {
                    _dismissed = true;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta informativa fija para la pantalla de inicio (DesktopHomePage)
class PublicNetworkHomeBanner extends StatelessWidget {
  const PublicNetworkHomeBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFEF4444).withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFEF4444),
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Aviso de Red Pública",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF4444),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Proyecto público: Su equipo puede ser vulnerado en la red pública de RustDesk. Sesiones limitadas a 3 minutos.",
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFFFCA5A5),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
