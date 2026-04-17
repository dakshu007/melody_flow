import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../data/presets/eq_presets.dart';
import '../../providers/app_providers.dart';

class EqualizerScreen extends ConsumerStatefulWidget {
  const EqualizerScreen({super.key});

  @override
  ConsumerState<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends ConsumerState<EqualizerScreen> {
  String _selectedPreset = 'Custom';

  Future<void> _applyPreset(EqPreset preset, AndroidEqualizerParameters params) async {
    for (int i = 0; i < params.bands.length && i < preset.gains.length; i++) {
      await params.bands[i].setGain(preset.gains[i].toDouble());
    }
    setState(() => _selectedPreset = preset.name);
  }

  @override
  Widget build(BuildContext context) {
    final eq = ref.read(audioHandlerProvider).equalizer;
    final loudness = ref.read(audioHandlerProvider).loudnessEnhancer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          StreamBuilder<bool>(
            stream: eq.enabledStream,
            builder: (_, snap) => Switch(
              value: snap.data ?? false,
              onChanged: (v) => eq.setEnabled(v),
            ),
          ),
        ],
      ),
      body: FutureBuilder<AndroidEqualizerParameters>(
        future: eq.parameters,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final params = snap.data!;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Preset chips
              Text('Presets',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: eqPresets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final p = eqPresets[i];
                    return ChoiceChip(
                      label: Text(p.name),
                      selected: _selectedPreset == p.name,
                      onSelected: (_) => _applyPreset(p, params),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              Text('Bands',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: params.bands
                      .map((b) => Expanded(
                          child: _BandSlider(
                            band: b,
                            params: params,
                            onManualChange: () =>
                                setState(() => _selectedPreset = 'Custom'),
                          )))
                      .toList(),
                ),
              ),
              const SizedBox(height: 32),
              Text('Loudness enhancer',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 8),
              StreamBuilder<bool>(
                stream: loudness.enabledStream,
                builder: (_, snap) {
                  return SwitchListTile(
                    title: const Text('Enable'),
                    value: snap.data ?? false,
                    onChanged: (v) => loudness.setEnabled(v),
                  );
                },
              ),
              StreamBuilder<double>(
                stream: loudness.targetGainStream,
                builder: (_, snap) {
                  final gain = snap.data ?? 0.0;
                  return Column(
                    children: [
                      Slider(
                        min: 0,
                        max: 1,
                        value: gain.clamp(0, 1),
                        onChanged: (v) => loudness.setTargetGain(v),
                      ),
                      Text('+${(gain * 10).toStringAsFixed(1)} dB'),
                    ],
                  );
                },
              ),
              const SizedBox(height: 40),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reset to flat'),
                  onPressed: () => _applyPreset(eqPresets[0], params),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final AndroidEqualizerBand band;
  final AndroidEqualizerParameters params;
  final VoidCallback onManualChange;
  const _BandSlider({
    required this.band,
    required this.params,
    required this.onManualChange,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: band.gainStream,
      builder: (_, snap) {
        final gain = snap.data ?? 0.0;
        return Column(
          children: [
            Expanded(
              child: RotatedBox(
                quarterTurns: -1,
                child: Slider(
                  min: params.minDecibels,
                  max: params.maxDecibels,
                  value: gain.clamp(params.minDecibels, params.maxDecibels),
                  onChanged: (v) {
                    band.setGain(v);
                    onManualChange();
                  },
                ),
              ),
            ),
            Text('${(band.centerFrequency / 1000).toStringAsFixed(0)}k',
                style: const TextStyle(fontSize: 11)),
            Text('${gain.toStringAsFixed(0)}dB',
                style: const TextStyle(fontSize: 10)),
          ],
        );
      },
    );
  }
}
