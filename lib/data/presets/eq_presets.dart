/// 10 built-in equalizer presets. Each has 5 band gains in dB.
/// Band frequencies (typical): 60Hz, 230Hz, 910Hz, 3600Hz, 14000Hz
class EqPreset {
  final String name;
  final List<double> gains;
  const EqPreset(this.name, this.gains);
}

const eqPresets = <EqPreset>[
  EqPreset('Flat',          [ 0,  0,  0,  0,  0]),
  EqPreset('Bass Boost',    [ 8,  5,  0, -1, -1]),
  EqPreset('Treble Boost',  [-1, -1,  0,  5,  8]),
  EqPreset('Pop',           [-1,  2,  4,  2, -1]),
  EqPreset('Rock',          [ 5,  3, -2,  3,  5]),
  EqPreset('Jazz',          [ 3,  2, -1,  2,  3]),
  EqPreset('Classical',     [ 4,  3, -2,  3,  4]),
  EqPreset('Hip-Hop',       [ 5,  4,  1,  3,  2]),
  EqPreset('Vocal',         [-2,  0,  4,  2, -1]),
  EqPreset('Electronic',    [ 4,  3,  0,  3,  5]),
];
