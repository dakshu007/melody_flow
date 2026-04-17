import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../providers/app_providers.dart';

class EqualizerScreen extends ConsumerStatefulWidget {
  const EqualizerScreen({super.key});

  @override
  ConsumerState<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends ConsumerState<EqualizerScreen> {
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
                      .map((b) => Expanded(child: _BandSlider(band: b, params: params)))
                      .toList(),
                ),
              ),
              const SizedBox(height: 32),
              Text('Loudness',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 8),
              StreamBuilder<bool>(
                stream: loudness.enabledStream,
                builder: (_, snap) {
                  return SwitchListTile(
                    title: const Text('Enable loudness enhancer'),
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
                        max: 1, // 0 -> 0dB, 1 -> +10dB
                        value: gain.clamp(0, 1),
                        onChanged: (v) => loudness.setTargetGain(v),
                      ),
                      Text('+${(gain * 10).toStringAsFixed(1)} dB'),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BandSlider extends StatefulWidget {
  final AndroidEqualizerBand band;
  final AndroidEqualizerParameters params;
  const _BandSlider({required this.band, required this.params});

  @override
  State<_BandSlider> createState() => _BandSliderState();
}

class _BandSliderState extends State<_BandSlider> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: widget.band.gainStream,
      builder: (_, snap) {
        final gain = snap.data ?? 0.0;
        return Column(
          children: [
            Expanded(
              child: RotatedBox(
                quarterTurns: -1,
                child: Slider(
                  min: widget.params.minDecibels,
                  max: widget.params.maxDecibels,
                  value: gain.clamp(
                      widget.params.minDecibels, widget.params.maxDecibels),
                  onChanged: (v) => widget.band.setGain(v),
                ),
              ),
            ),
            Text('${(widget.band.centerFrequency / 1000).toStringAsFixed(0)}k',
                style: const TextStyle(fontSize: 11)),
            Text('${gain.toStringAsFixed(0)}dB',
                style: const TextStyle(fontSize: 10)),
          ],
        );
      },
    );
  }
}
