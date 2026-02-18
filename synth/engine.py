"""Moteur de synthèse sonore pour sand-notify.

Génère des sons AIFF 16-bit mono via numpy + struct.
Pas de dépendance à aifc (retiré en Python 3.13).
"""

import json
import struct
import numpy as np
from pathlib import Path


def _float_to_extended(f):
    """Convertit un float en IEEE 754 extended 80-bit (big-endian).

    Nécessaire pour le champ sampleRate du chunk COMM en AIFF.
    """
    if f == 0:
        return b'\x00' * 10
    sign = 0
    if f < 0:
        sign = 1
        f = -f
    # Exposant et mantisse
    import math
    exp = int(math.floor(math.log2(f)))
    mantissa = f / (2 ** exp)
    # Format 80-bit : 1 bit sign, 15 bits exponent (bias 16383), 64 bits mantissa
    biased_exp = exp + 16383
    # Mantisse normalisée : bit implicite = 1 en extended
    int_mantissa = int(mantissa * (2 ** 63))
    return struct.pack('>HQ', (sign << 15) | biased_exp, int_mantissa)


def write_aiff(filename, signal, sample_rate=44100):
    """Écrit un fichier AIFF 16-bit mono.

    Args:
        filename: Chemin du fichier de sortie.
        signal: numpy array int16 des échantillons.
        sample_rate: Fréquence d'échantillonnage (défaut 44100).
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
    """Génère un ton avec harmoniques et enveloppe exponentielle.

    Args:
        freq: Fréquence fondamentale (Hz).
        duration: Durée en secondes.
        decay: Taux de decay exponentiel.
        harmonics: Liste de [multiplicateur, amplitude, decay].
        volume: Volume normalisé (0-1).
        sample_rate: Fréquence d'échantillonnage.

    Returns:
        numpy array int16.
    """
    if harmonics is None:
        harmonics = []

    t = np.linspace(0, duration, int(sample_rate * duration), endpoint=False)

    # Fondamentale
    signal = np.sin(2 * np.pi * freq * t) * np.exp(-decay * t)

    # Harmoniques
    for mult, amp, h_decay in harmonics:
        signal += amp * np.sin(2 * np.pi * freq * mult * t) * np.exp(-h_decay * t)

    # Fade-in anti-click (2ms)
    fade_in_samples = int(0.002 * sample_rate)
    if fade_in_samples > 0 and fade_in_samples < len(signal):
        signal[:fade_in_samples] *= np.linspace(0, 1, fade_in_samples)

    # Fade-out (10% de la durée)
    fade_out_samples = int(0.1 * len(signal))
    if fade_out_samples > 0:
        signal[-fade_out_samples:] *= np.linspace(1, 0, fade_out_samples)

    # Normalisation peak
    peak = np.max(np.abs(signal))
    if peak > 0:
        signal = signal / peak * volume * 32767

    return signal.astype(np.int16)


def generate_sequence(notes, duration, volume=0.7, sample_rate=44100):
    """Génère une séquence multi-notes avec offsets temporels.

    Args:
        notes: Liste de dicts avec freq, start, decay, amp, harmonics.
        duration: Durée totale en secondes.
        volume: Volume normalisé (0-1).
        sample_rate: Fréquence d'échantillonnage.

    Returns:
        numpy array int16.
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

        # Fondamentale
        tone = note['amp'] * np.sin(2 * np.pi * note['freq'] * t) * np.exp(-note['decay'] * t)

        # Harmoniques
        for mult, amp, h_decay in note.get('harmonics', []):
            tone += note['amp'] * amp * np.sin(2 * np.pi * note['freq'] * mult * t) * np.exp(-h_decay * t)

        # Fade-in anti-click (2ms)
        fade_in_samples = int(0.002 * sample_rate)
        if fade_in_samples > 0 and fade_in_samples < len(tone):
            tone[:fade_in_samples] *= np.linspace(0, 1, fade_in_samples)

        # Insérer dans le signal
        end_sample = min(start_sample + note_samples, total_samples)
        actual_len = end_sample - start_sample
        signal[start_sample:end_sample] += tone[:actual_len]

    # Fade-out global (10% de la durée)
    fade_out_samples = int(0.1 * total_samples)
    if fade_out_samples > 0:
        signal[-fade_out_samples:] *= np.linspace(1, 0, fade_out_samples)

    # Normalisation peak
    peak = np.max(np.abs(signal))
    if peak > 0:
        signal = signal / peak * volume * 32767

    return signal.astype(np.int16)


def load_presets(path=None):
    """Charge les presets depuis un fichier JSON.

    Args:
        path: Chemin vers presets.json. Si None, utilise le fichier par défaut.

    Returns:
        dict des presets.
    """
    if path is None:
        path = Path(__file__).parent / 'presets.json'
    with open(path) as f:
        return json.load(f)


def render_preset(name, preset):
    """Rend un preset en signal audio.

    Args:
        name: Nom du preset (pour les messages d'erreur).
        preset: Dict du preset.

    Returns:
        numpy array int16.
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
        raise ValueError(f"Type de preset inconnu : {preset['type']} (preset '{name}')")
