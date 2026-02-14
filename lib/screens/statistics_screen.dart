import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/sticker_button.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _selectedYear = DateTime.now().year;
  final Set<String> _selectedButtonIds = {};
  Map<String, Map<String, int>> _allData = {};
  bool _isLoading = true;

  static const _chartColors = [
    Colors.purpleAccent,
    Colors.cyanAccent,
    Colors.orangeAccent,
    Colors.greenAccent,
    Colors.pinkAccent,
    Colors.amberAccent,
    Colors.tealAccent,
    Colors.redAccent,
    Colors.lightBlueAccent,
    Colors.limeAccent,
  ];

  static const _months = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final provider = context.read<AppProvider>();
    _allData = await provider.getAllButtonsMonthlyPresses(_selectedYear);

    // Select all buttons by default if none selected
    if (_selectedButtonIds.isEmpty) {
      _selectedButtonIds.addAll(_allData.keys);
    }

    setState(() => _isLoading = false);
  }

  void _changeYear(int delta) {
    setState(() {
      _selectedYear += delta;
    });
    _loadData();
  }

  Color _getColor(int index) => _chartColors[index % _chartColors.length];

  void _showButtonSettings(StickerButton button) {
    final provider = context.read<AppProvider>();
    double currentSize = button.size;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                button.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total: ${provider.totalCounts[button.id] ?? 0} veces',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
              const SizedBox(height: 24),
              // Size slider
              Row(
                children: [
                  const Icon(Icons.photo_size_select_small,
                      color: Colors.white38, size: 18),
                  const SizedBox(width: 8),
                  const Text('Tamaño:',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.purpleAccent,
                        inactiveTrackColor:
                            Colors.purpleAccent.withOpacity(0.15),
                        thumbColor: Colors.purpleAccent,
                        overlayColor: Colors.purpleAccent.withOpacity(0.2),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: currentSize,
                        min: 60,
                        max: 180,
                        divisions: 24,
                        label: '${currentSize.round()}px',
                        onChanged: (val) {
                          setModalState(() => currentSize = val);
                        },
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${currentSize.round()}px',
                      style: const TextStyle(
                        color: Colors.purpleAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDelete(button);
                      },
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 18),
                      label: const Text('Eliminar',
                          style: TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.redAccent.withOpacity(0.4)),
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
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Guardar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
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
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Eliminar botón',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Seguro que quieres eliminar "${button.name}"?\nSe perderán todas las estadísticas asociadas.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _selectedButtonIds.remove(button.id);
              await context.read<AppProvider>().deleteButton(button.id);
              await _loadData();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final buttons = provider.buttons;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Estadísticas',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent))
          : buttons.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Year selector
                      _buildYearSelector(),
                      const SizedBox(height: 20),

                      // Button filter chips
                      _buildButtonFilters(buttons, provider),
                      const SizedBox(height: 24),

                      // Chart
                      _buildChart(buttons),
                      const SizedBox(height: 24),

                      // Monthly breakdown
                      _buildMonthlyBreakdown(buttons),
                      const SizedBox(height: 24),

                      // Per-button summary cards
                      _buildButtonSummaries(buttons, provider),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded, size: 80, color: Colors.grey.shade700),
          const SizedBox(height: 16),
          Text(
            'Sin datos aún',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega botones y empieza a usarlos',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => _changeYear(-1),
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70),
          ),
          const SizedBox(width: 16),
          Text(
            '$_selectedYear',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _selectedYear < DateTime.now().year
                ? () => _changeYear(1)
                : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: _selectedYear < DateTime.now().year
                  ? Colors.white70
                  : Colors.white24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonFilters(List<StickerButton> buttons, AppProvider provider) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: buttons.asMap().entries.map((entry) {
        final i = entry.key;
        final button = entry.value;
        final isSelected = _selectedButtonIds.contains(button.id);
        final color = _getColor(i);

        return FilterChip(
          selected: isSelected,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (provider.getImagePath(button.id).isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(provider.getImagePath(button.id)),
                    width: 20,
                    height: 20,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                button.name,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1A1A2E),
          selectedColor: color,
          checkmarkColor: Colors.black,
          side: BorderSide(
            color: isSelected ? color : Colors.white24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedButtonIds.add(button.id);
              } else {
                _selectedButtonIds.remove(button.id);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildChart(List<StickerButton> buttons) {
    final selectedButtons = buttons
        .where((b) => _selectedButtonIds.contains(b.id))
        .toList();

    if (selectedButtons.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            'Selecciona al menos un botón',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    double maxY = 0;
    for (final button in selectedButtons) {
      final data = _allData[button.id];
      if (data != null) {
        for (final v in data.values) {
          if (v > maxY) maxY = v.toDouble();
        }
      }
    }
    maxY = maxY == 0 ? 10 : maxY * 1.2;

    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(8, 24, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final buttonIndex = rodIndex;
                if (buttonIndex >= selectedButtons.length) return null;
                final button = selectedButtons[buttonIndex];
                return BarTooltipItem(
                  '${button.name}\n${rod.toY.toInt()}',
                  TextStyle(
                    color: _getColor(
                        buttons.indexWhere((b) => b.id == button.id)),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < 12) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _months[idx],
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withOpacity(0.05),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(12, (monthIdx) {
            final monthKey = (monthIdx + 1).toString().padLeft(2, '0');

            return BarChartGroupData(
              x: monthIdx,
              barRods: selectedButtons.asMap().entries.map((entry) {
                final button = entry.value;
                final data = _allData[button.id];
                final value = data?[monthKey]?.toDouble() ?? 0;
                final colorIdx =
                    buttons.indexWhere((b) => b.id == button.id);

                return BarChartRodData(
                  toY: value,
                  color: _getColor(colorIdx),
                  width: selectedButtons.length > 3
                      ? 4
                      : selectedButtons.length > 1
                          ? 6
                          : 12,
                  borderRadius: BorderRadius.circular(3),
                );
              }).toList(),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildMonthlyBreakdown(List<StickerButton> buttons) {
    final selectedButtons =
        buttons.where((b) => _selectedButtonIds.contains(b.id)).toList();

    if (selectedButtons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Desglose Mensual',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(12, (monthIdx) {
          final monthKey = (monthIdx + 1).toString().padLeft(2, '0');
          int totalForMonth = 0;

          for (final b in selectedButtons) {
            totalForMonth += _allData[b.id]?[monthKey] ?? 0;
          }

          if (totalForMonth == 0) return const SizedBox.shrink();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _months[monthIdx],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Total: $totalForMonth',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...selectedButtons.map((button) {
                  final count = _allData[button.id]?[monthKey] ?? 0;
                  final colorIdx =
                      buttons.indexWhere((b) => b.id == button.id);
                  final ratio =
                      totalForMonth > 0 ? count / totalForMonth : 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getColor(colorIdx),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Text(
                            button.name,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              backgroundColor: Colors.white.withOpacity(0.05),
                              color: _getColor(colorIdx),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 30,
                          child: Text(
                            '$count',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: _getColor(colorIdx),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildButtonSummaries(List<StickerButton> buttons, AppProvider provider) {
    final selectedButtons =
        buttons.where((b) => _selectedButtonIds.contains(b.id)).toList();

    if (selectedButtons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumen por Botón',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...selectedButtons.map((button) {
          final data = _allData[button.id] ?? {};
          final colorIdx = buttons.indexWhere((b) => b.id == button.id);
          final yearTotal = data.values.fold<int>(0, (a, b) => a + b);
          final maxMonth = data.entries
              .where((e) => e.value > 0)
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getColor(colorIdx).withOpacity(0.15),
                  const Color(0xFF1A1A2E),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getColor(colorIdx).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(provider.getImagePath(button.id)),
                        width: 50,
                        height: 50,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            button.name,
                            style: TextStyle(
                              color: _getColor(colorIdx),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total $_selectedYear: $yearTotal',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          if (maxMonth.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Mes pico: ${_months[int.parse(maxMonth.first.key) - 1]} (${maxMonth.first.value})',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$yearTotal',
                          style: TextStyle(
                            color: _getColor(colorIdx),
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                        ),
                        Text(
                          'este año',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showButtonSettings(button),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.settings_rounded,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
