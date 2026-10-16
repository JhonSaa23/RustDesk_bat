import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import '../widgets/tabbar_widget.dart';

/// Administrador del tiempo de espera y cola de desconexión en red pública.
class PublicNetworkCooldownManager {
  PublicNetworkCooldownManager._();
  static final PublicNetworkCooldownManager instance =
      PublicNetworkCooldownManager._();

  static const String _kOptionKey = 'public_cooldown_until';
  static const String _kHostOptionKey = 'host_public_cooldown_until';
  static const int kCooldownDurationSeconds = 600; // 10 minutos de espera

  int _inMemoryCooldownUntilMs = 0;
  int _inMemoryHostCooldownUntilMs = 0;

  /// Inicia el temporizador de cola de espera para conexiones salientes (600 segundos = 10 minutos).
  void startCooldown([int seconds = kCooldownDurationSeconds]) {
    final untilMs = DateTime.now().millisecondsSinceEpoch + (seconds * 1000);
    _inMemoryCooldownUntilMs = untilMs;
    try {
      bind.mainSetOption(key: _kOptionKey, value: untilMs.toString());
    } catch (_) {}
  }

  /// Inicia el temporizador de cola de espera del host cuando una máquina es remoteada (600 segundos = 10 minutos).
  void startHostCooldown([int seconds = kCooldownDurationSeconds]) {
    final untilMs = DateTime.now().millisecondsSinceEpoch + (seconds * 1000);
    _inMemoryHostCooldownUntilMs = untilMs;
    try {
      bind.mainSetOption(key: _kHostOptionKey, value: untilMs.toString());
    } catch (_) {}
  }

  /// Limpia la cola de espera.
  void clearCooldown() {
    _inMemoryCooldownUntilMs = 0;
    _inMemoryHostCooldownUntilMs = 0;
    try {
      bind.mainSetOption(key: _kOptionKey, value: '0');
      bind.mainSetOption(key: _kHostOptionKey, value: '0');
    } catch (_) {}
  }

  /// Segundos restantes que debe esperar el usuario antes de poder conectarse (saliente).
  int get remainingSeconds {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    int targetMs = _inMemoryCooldownUntilMs;

    if (targetMs <= 0) {
      try {
        final val = bind.mainGetOptionSync(key: _kOptionKey);
        if (val.isNotEmpty) {
          targetMs = int.tryParse(val) ?? 0;
          _inMemoryCooldownUntilMs = targetMs;
        }
      } catch (_) {}
    }

    final diff = targetMs - nowMs;
    if (diff > 0) {
      return (diff / 1000).ceil();
    }
    return 0;
  }

  /// Segundos restantes antes de que este equipo host pueda aceptar otra conexión entrante.
  int get remainingHostSeconds {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    int targetMs = _inMemoryHostCooldownUntilMs;

    if (targetMs <= 0) {
      try {
        final val = bind.mainGetOptionSync(key: _kHostOptionKey);
        if (val.isNotEmpty) {
          targetMs = int.tryParse(val) ?? 0;
          _inMemoryHostCooldownUntilMs = targetMs;
        }
      } catch (_) {}
    }

    final diff = targetMs - nowMs;
    if (diff > 0) {
      return (diff / 1000).ceil();
    }
    return 0;
  }

  /// Indica si el usuario aún se encuentra en tiempo de espera obligatorio para conectar.
  bool get isUnderCooldown => remainingSeconds > 0;

  /// Indica si esta máquina está en periodo de enfriamiento y debe rechazar conexiones entrantes.
  bool get isHostCooldownActive => remainingHostSeconds > 0;
}

/// Modal que abarca la vista informando sobre la saturación del servidor público y la cola de 5 minutos.
void showPublicNetworkQueueModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const PublicNetworkQueueDialog(),
  );
}

class PublicNetworkQueueDialog extends StatefulWidget {
  const PublicNetworkQueueDialog({Key? key}) : super(key: key);

  @override
  State<PublicNetworkQueueDialog> createState() =>
      _PublicNetworkQueueDialogState();
}

class _PublicNetworkQueueDialogState extends State<PublicNetworkQueueDialog> {
  Timer? _ticker;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = PublicNetworkCooldownManager.instance.remainingSeconds;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final rem = PublicNetworkCooldownManager.instance.remainingSeconds;
      if (mounted) {
        setState(() {
          _remaining = rem;
        });
      }
      if (rem <= 0) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _remaining <= 0;
    const totalSeconds = PublicNetworkCooldownManager.kCooldownDurationSeconds;
    final elapsed = totalSeconds - _remaining;
    final progress = (elapsed / totalSeconds).clamp(0.0, 1.0);

    final minutes = (_remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining % 60).toString().padLeft(2, '0');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF16181F),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDone
                ? const Color(0xFF10B981).withOpacity(0.6)
                : const Color(0xFFF59E0B).withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDone
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B))
                  .withOpacity(0.14),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ícono de estado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDone
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B))
                    .withOpacity(0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDone
                    ? Icons.check_circle_outline_rounded
                    : Icons.hourglass_top_rounded,
                color:
                    isDone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                size: 44,
              ),
            ),
            const SizedBox(height: 18),

            // Título
            Text(
              isDone
                  ? "¡COLA FINALIZADA!"
                  : "SERVIDOR PÚBLICO SATURADO",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color:
                    isDone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              isDone
                  ? "Ya puedes volver a conectarte"
                  : "En cola de espera para reconexión",
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),

            // Tarjeta de contador regresivo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDone
                      ? const Color(0xFF10B981).withOpacity(0.3)
                      : const Color(0xFFF59E0B).withOpacity(0.25),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    isDone ? "00:00" : "$minutes:$seconds",
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: isDone
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isDone
                        ? "Tiempo de espera cumplido"
                        : "Tiempo de espera restante",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: isDone ? 1.0 : progress,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDone
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Explicación de saturación del servidor público
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.09),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.25),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    color: Color(0xFFEF4444),
                    size: 22,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Saturación de Red y Cola de Espera",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFCA5A5),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Al ser un servidor público, la red se satura debido a la alta concurrencia de conexiones simultáneas. Para evitar caídas y desconexiones abruptas, has entrado en una cola de espera. Debes esperar 10 minutos para volver a conectarte.",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Botón de acción
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDone
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                  foregroundColor:
                      isDone ? Colors.white : const Color(0xFF1A1A1A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  isDone ? "¡Listo! Conectar ahora" : "Entendido (Esperar en cola)",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo modal con el anuncio de advertencia sobre la red pública y el límite de 2 minutos.
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
                    ? "Sesión Finalizada (Límite de 2 Minutos)"
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
                    ? "La sesión remota se ha cerrado automáticamente porque se alcanzaron los 2 minutos máximos establecidos.\n\nAl ser un servidor público, has entrado en una cola de espera de 10 minutos antes de poder volver a conectarte."
                    : "Este es un proyecto público. Tenga en cuenta que su equipo puede ser vulnerado a través de la red pública de RustDesk.\n\nPor motivos de seguridad, cada sesión remota cuenta con un temporizador estricto de 2 minutos y se cerrará automáticamente al finalizar el tiempo. Al terminar, deberás esperar 10 minutos en cola para volver a entrar.",
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
  static const int kInitialCountdownSeconds = 120; // 2 minutos
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

      // Reiniciar contador de 2 minutos cada vez que entra una sesión o se reconecta
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
    PublicNetworkCooldownManager.instance.startCooldown(600); // Activar cola de espera de 10 min
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
          "⚠️ AVISO: Proyecto público. Su equipo puede ser vulnerado en la red pública de RustDesk.\nSesión limitada a 2 minutos ($minutes:$seconds restantes). Clic para más detalles.",
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
                      "Este es un proyecto público. Tenga en cuenta que su equipo puede ser vulnerado a través de la red pública de RustDesk. La sesión se cerrará automáticamente en 2 minutos.",
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
                  "Proyecto público: Su equipo puede ser vulnerado en la red pública de RustDesk. Sesiones limitadas a 2 minutos con 10 minutos de espera entre reconexiones.",
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
