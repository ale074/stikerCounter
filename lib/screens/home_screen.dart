import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/sticker_button.dart';
import 'add_button_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final Map<String, AnimationController> _animControllers = {};
  final Map<String, Animation<double>> _animations = {};
  final GlobalKey _canvasKey = GlobalKey();
  String? _draggingId;

  @override
  void dispose() {
    for (final controller in _animControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  AnimationController _getController(String buttonId) {
    if (!_animControllers.containsKey(buttonId)) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 150),
        vsync: this,
      );
      _animControllers[buttonId] = controller;
      _animations[buttonId] = Tween<double>(begin: 1.0, end: 0.85).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }
    return _animControllers[buttonId]!;
  }

  void _onButtonPress(String buttonId) async {
    final controller = _getController(buttonId);
    await controller.forward();
    await controller.reverse();

    if (!mounted) return;
    await context.read<AppProvider>().pressButton(buttonId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✓ Registrado!'),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _navigateToAdd() async {
    final provider = context.read<AppProvider>();
    if (provider.buttons.length >= provider.buttonLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Límite alcanzado (${provider.buttonLimit} botones). Cambia el límite en Ajustes.',
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddButtonScreen()),
    );
  }

  void _showButtonOptions(StickerButton button) {
    final provider = context.read<AppProvider>();
    double currentSize = button.size;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                button.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total: ${provider.totalCounts[button.id] ?? 0} veces',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.photo_size_select_large, size: 20),
                  const SizedBox(width: 12),
                  const Text('Tamaño:', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Slider(
                      value: currentSize,
                      min: 60,
                      max: 180,
                      divisions: 12,
                      label: '${currentSize.round()}',
                      onChanged: (val) {
                        setModalState(() => currentSize = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDelete(button);
                      },
                      icon:
                          const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Eliminar',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        provider.updateButtonSize(button.id, currentSize);
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Guardar'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(StickerButton button) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar botón'),
        content: Text(
            '¿Seguro que quieres eliminar "${button.name}"? Se perderán todas las estadísticas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AppProvider>().deleteButton(button.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Size _getCanvasSize() {
    final renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size ?? Size.zero;
  }

  /// Assigns default positions to buttons that don't have one yet (-1).
  void _assignDefaultPositions(List<StickerButton> buttons) {
    final canvasSize = _getCanvasSize();
    if (canvasSize == Size.zero) return;

    final provider = context.read<AppProvider>();
    const padding = 20.0;
    double currentX = padding;
    double currentY = padding;
    double rowMaxHeight = 0;

    for (final button in buttons) {
      if (button.posX < 0 || button.posY < 0) {
        // Find a spot that doesn't overlap too much
        final bSize = button.size + 30; // account for label
        if (currentX + bSize > canvasSize.width - padding) {
          currentX = padding;
          currentY += rowMaxHeight + 20;
          rowMaxHeight = 0;
        }
        provider.updateButtonPosition(button.id, currentX, currentY);
        currentX += bSize + 10;
        if (bSize > rowMaxHeight) rowMaxHeight = bSize;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Sticker Counter',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white70),
            tooltip: 'Estadísticas',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatisticsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white70),
            tooltip: 'Ajustes',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAdd,
        backgroundColor: Colors.purpleAccent,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent),
            );
          }

          if (provider.buttons.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_rounded,
                      size: 80, color: Colors.grey.shade700),
                  const SizedBox(height: 16),
                  Text(
                    'No hay botones aún',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toca + para agregar tu primer sticker',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Counter summary bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.shade900.withOpacity(0.5),
                        Colors.blue.shade900.withOpacity(0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.purple.shade800.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        'Botones',
                        '${provider.buttons.length}/${provider.buttonLimit}',
                        Icons.grid_view_rounded,
                      ),
                      Container(
                          height: 30, width: 1, color: Colors.white24),
                      _buildSummaryItem(
                        'Hoy',
                        '${provider.todayCounts.values.fold<int>(0, (a, b) => a + b)}',
                        Icons.today_rounded,
                      ),
                      Container(
                          height: 30, width: 1, color: Colors.white24),
                      _buildSummaryItem(
                        'Total',
                        '${provider.totalCounts.values.fold<int>(0, (a, b) => a + b)}',
                        Icons.functions_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              // Free-form sticker canvas
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Assign default positions after layout
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _assignDefaultPositions(provider.buttons);
                    });

                    return Stack(
                      key: _canvasKey,
                      clipBehavior: Clip.none,
                      children: [
                        // Stickers
                        ...provider.buttons
                            .map((b) => _buildDraggableSticker(
                                b, provider, constraints)),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.purpleAccent.shade100, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDraggableSticker(
      StickerButton button, AppProvider provider, BoxConstraints constraints) {
    _getController(button.id);
    final animation = _animations[button.id]!;
    final isDragging = _draggingId == button.id;

    // Clamp position within bounds
    final maxX = constraints.maxWidth - button.size;
    final maxY = constraints.maxHeight - button.size - 30;
    final posX = button.posX.clamp(0.0, maxX > 0 ? maxX : 0.0);
    final posY = button.posY.clamp(0.0, maxY > 0 ? maxY : 0.0);

    return Positioned(
      left: posX,
      top: posY,
      child: _StickerAnimatedWrapper(
        animation: animation,
        isDragging: isDragging,
        child: GestureDetector(
          onTap: () => _onButtonPress(button.id),
          onLongPress: () => _showButtonOptions(button),
          onPanStart: (_) {
            setState(() => _draggingId = button.id);
          },
          onPanUpdate: (details) {
            final newX = (button.posX + details.delta.dx)
                .clamp(0.0, maxX > 0 ? maxX : 0.0);
            final newY = (button.posY + details.delta.dy)
                .clamp(0.0, maxY > 0 ? maxY : 0.0);
            provider.updateButtonPositionLocal(button.id, newX, newY);
          },
          onPanEnd: (_) {
            setState(() => _draggingId = null);
            // Persist final position to DB
            final b =
                provider.buttons.firstWhere((b) => b.id == button.id);
            provider.updateButtonPosition(b.id, b.posX, b.posY);
          },
          child: SizedBox(
            width: button.size,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Sticker image — no border, no container
                SizedBox(
                  width: button.size,
                  height: button.size,
                  child: Image.file(
                    File(provider.getImagePath(button.id)),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.broken_image,
                      color: Colors.grey.shade600,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                // Name label
                Text(
                  button.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 1),
                // Count badge
                Text(
                  '${provider.todayCounts[button.id] ?? 0} hoy · ${provider.totalCounts[button.id] ?? 0}',
                  style: TextStyle(
                    color: Colors.purpleAccent.shade100.withOpacity(0.7),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a sticker with scale animation and drag elevation.
class _StickerAnimatedWrapper extends StatelessWidget {
  final Animation<double> animation;
  final bool isDragging;
  final Widget child;

  const _StickerAnimatedWrapper({
    required this.animation,
    required this.isDragging,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: Matrix4.identity()
        ..scale(isDragging ? 1.12 : 1.0),
      transformAlignment: Alignment.center,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isDragging ? 0.85 : 1.0,
        child: _AnimBuilder(
          listenable: animation,
          builder: (context, child) {
            return Transform.scale(
              scale: animation.value,
              child: child,
            );
          },
          child: child,
        ),
      ),
    );
  }
}

class _AnimBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const _AnimBuilder({
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
