import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../providers/music_provider.dart';
import '../widgets/zmr_snackbar.dart';

class SleepTimerSheet extends ConsumerStatefulWidget {
  const SleepTimerSheet({super.key});

  @override
  ConsumerState<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends ConsumerState<SleepTimerSheet> {
  double _sliderValue = 30; // Minutes
  final _hourController = TextEditingController();
  final _minController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updateInputsFromSlider(30);
  }

  void _updateInputsFromSlider(double val) {
    if (_sliderValue != val) _sliderValue = val;
    final h = (val / 60).floor();
    final m = (val % 60).round();
    
    // Only update controllers if the value is different from parsed input
    final currentH = int.tryParse(_hourController.text) ?? 0;
    final currentM = int.tryParse(_minController.text) ?? 0;
    
    if (h != currentH || m != currentM) {
      _hourController.text = h > 0 ? h.toString() : '';
      _minController.text = m.toString();
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTimer = ref.watch(sleepTimerProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        left: 24,
        right: 24,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(50),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Iconsax.moon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Sleep Timer',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (activeTimer != null)
                TextButton(
                  onPressed: () {
                    ref.read(sleepTimerProvider.notifier).cancelTimer();
                    ZmrSnackbar.show(context, 'Timer cancelled');
                  },
                  child: Text('Cancel', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (activeTimer != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(40)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Time remaining: ',
                    style: GoogleFonts.outfit(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  Text(
                    '${activeTimer.inHours}:${(activeTimer.inMinutes % 60).toString().padLeft(2, '0')}:${(activeTimer.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          Text(
            '${_sliderValue.round()} Minutes',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _sliderValue,
            min: 1,
            max: 180,
            divisions: 12, // 15 min steps
            onChanged: (val) {
              setState(() {
                _sliderValue = val;
                _updateInputsFromSlider(val);
              });
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hourController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.outfit(),
                  decoration: InputDecoration(
                    labelText: 'Hours',
                    hintText: '0',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    prefixIcon: const Icon(Iconsax.clock, size: 20),
                  ),
                  onChanged: (val) {
                    final h = int.tryParse(val) ?? 0;
                    final m = int.tryParse(_minController.text) ?? 0;
                    setState(() => _sliderValue = (h * 60 + m).toDouble().clamp(1, 180));
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _minController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.outfit(),
                  decoration: InputDecoration(
                    labelText: 'Minutes',
                    hintText: '30',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    prefixIcon: const Icon(Iconsax.timer_1, size: 20),
                  ),
                  onChanged: (val) {
                    final h = int.tryParse(_hourController.text) ?? 0;
                    final m = int.tryParse(val) ?? 0;
                    setState(() => _sliderValue = (h * 60 + m).toDouble().clamp(1, 180));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                final h = int.tryParse(_hourController.text) ?? 0;
                final m = int.tryParse(_minController.text) ?? 0;
                final totalMins = h * 60 + m;
                if (totalMins > 0) {
                  ref.read(sleepTimerProvider.notifier).setTimer(Duration(minutes: totalMins));
                  Navigator.pop(context);
                  ZmrSnackbar.show(context, 'Music will stop in $totalMins minutes');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                'Set Timer',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
