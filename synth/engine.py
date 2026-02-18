"""Sound synthesis engine for sand-notify.

Generates 16-bit mono AIFF files via numpy + struct.
No dependency on aifc (removed in Python 3.13).
"""

import json
import struct
import numpy as np
from pathlib import Path


def _float_to_extended(f):
    """Convert a float to IEEE 754 extended 80-bit (big-endian).

    Required for the sampleRate field in the AIFF COMM chunk.
    """
    if f == 0:
        return b'\x00' * 10
    sign = 0
    if f < 0:
        sign = 1
        f = -f
    # Exponent and mantissa
    import math
    exp = int(math.floor(math.log2(f)))
    mantissa = f / (2 ** exp)
    # 80-bit format: 1 bit sign, 15 bits exponent (bias 16383), 64 bits mantissa
    biased_exp = exp + 16383
    # Normalized mantissa: implicit bit = 1 in extended
    int_mantissa = int(mantissa * (2 ** 63))
    return struct.pack('>HQ', (sign << 15) | biased_exp, int_mantissa)


def write_aiff(filename, signal, sample_rate=44100):
    """Write a 16-bit mono AIFF file.

    Args:
        filename: Output file path.
        signal: numpy int16 array of samples.
        sample_rate: Sample rate (default 44100).
    """
    num_frames = len(signal)
    num_channels = 1
    bits_per_sample = 16
    audio_data = signal.astype('>i2').tobytes()  # big-endian int16

    # COMM chunk
    comm_data = struct.pack('>hIh', num_channels, num_frames, bits_per_sample)
    comm_data += _float_to_extended(sample_rate)
    comm_chunk = b'COMM' + struct.pack('>I', len(comm_data)) + comm_data

    # SSND chunk
    ssnd_header = struct.pack('>II', 0, 0)  # offset, blockSize
    ssnd_data = ssnd_header + audio_data
    ssnd_chunk = b'SSND' + struct.pack('>I', len(ssnd_data)) + ssnd_data

    # FORM container
    form_data = b'AIFF' + comm_chunk + ssnd_chunk
    form = b'FORM' + struct.pack('>I', len(form_data)) + form_data

    Path(filename).parent.mkdir(parents=True, exist_ok=True)
    with open(filename, 'wb') as f:
        f.write(form)


def generate_tone(freq, duration, decay=5, harmonics=None, volume=0.7, sample_rate=44100):
    """Generate a tone with harmonics and exponential envelope.

    Args:
        freq: Fundamental frequency (Hz).
        duration: Duration in seconds.
        decay: Exponential decay rate.
        harmonics: List of [multiplier, amplitude, decay].
        volume: Normalized volume (0-1).
        sample_rate: Sample rate.

    Returns:
        numpy int16 array.
    """
    if harmonics is None:
        harmonics = []

    t = np.linspace(0, duration, int(sample_rate * duration), endpoint=False)

    # Fundamental
    signal = np.sin(2 * np.pi * freq * t) * np.exp(-decay * t)

    # Harmonics
    for mult, amp, h_decay in harmonics:
        signal += amp * np.sin(2 * np.pi * freq * mult * t) * np.exp(-h_decay * t)

    # Anti-click fade-in (2ms)
    fade_in_samples = int(0.002 * sample_rate)
    if fade_in_samples > 0 and fade_in_samples < len(signal):
        signal[:fade_in_samples] *= np.linspace(0, 1, fade_in_samples)

    # Fade-out (10% of duration)
    fade_out_samples = int(0.1 * len(signal))
    if fade_out_samples > 0:
        signal[-fade_out_samples:] *= np.linspace(1, 0, fade_out_samples)

    # Peak normalization
    peak = np.max(np.abs(signal))
    if peak > 0:
        signal = signal / peak * volume * 32767

    return signal.astype(np.int16)


def generate_sequence(notes, duration, volume=0.7, sample_rate=44100):
    """Generate a multi-note sequence with time offsets.

    Args:
        notes: List of dicts with freq, start, decay, amp, harmonics.
        duration: Total duration in seconds.
        volume: Normalized volume (0-1).
        sample_rate: Sample rate.

    Returns:
        numpy int16 array.
    """
    total_samples = int(sample_rate * duration)
    signal = np.zeros(total_samples, dtype=np.float64)

    for note in notes:
        start_sample = int(note['start'] * sample_rate)
        note_duration = duration - note['start']
        if note_duration <= 0:
            continue

        note_samples = int(note_duration * sample_rate)
        t = np.linspace(0, note_duration, note_samples, endpoint=False)

        # Fundamental
        tone = note['amp'] * np.sin(2 * np.pi * note['freq'] * t) * np.exp(-note['decay'] * t)

        # Harmonics
        for mult, amp, h_decay in note.get('harmonics', []):
            tone += note['amp'] * amp * np.sin(2 * np.pi * note['freq'] * mult * t) * np.exp(-h_decay * t)

        # Anti-click fade-in (2ms)
        fade_in_samples = int(0.002 * sample_rate)
        if fade_in_samples > 0 and fade_in_samples < len(tone):
            tone[:fade_in_samples] *= np.linspace(0, 1, fade_in_samples)

        # Insert into signal
        end_sample = min(start_sample + note_samples, total_samples)
        actual_len = end_sample - start_sample
        signal[start_sample:end_sample] += tone[:actual_len]

    # Global fade-out (10% of duration)
    fade_out_samples = int(0.1 * total_samples)
    if fade_out_samples > 0:
        signal[-fade_out_samples:] *= np.linspace(1, 0, fade_out_samples)

    # Peak normalization
    peak = np.max(np.abs(signal))
    if peak > 0:
        signal = signal / peak * volume * 32767

    return signal.astype(np.int16)


def load_presets(path=None):
    """Load presets from a JSON file.

    Args:
        path: Path to presets.json. If None, uses the default file.

    Returns:
        dict of presets.
    """
    if path is None:
        path = Path(__file__).parent / 'presets.json'
    with open(path) as f:
        return json.load(f)


def render_preset(name, preset):
    """Render a preset to an audio signal.

    Args:
        name: Preset name (for error messages).
        preset: Preset dict.

    Returns:
        numpy int16 array.
    """
    if preset['type'] == 'tone':
        return generate_tone(
            freq=preset['freq'],
            duration=preset['duration'],
            decay=preset.get('decay', 5),
            harmonics=preset.get('harmonics', []),
            volume=preset.get('volume', 0.7),
        )
    elif preset['type'] == 'sequence':
        return generate_sequence(
            notes=preset['notes'],
            duration=preset['duration'],
            volume=preset.get('volume', 0.7),
        )
    else:
        raise ValueError(f"Unknown preset type: {preset['type']} (preset '{name}')")
