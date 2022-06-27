import music21

def to_relative_scale(midi_path):
    score = music21.converter.parse(midi_path)
    key = score.analyze('Krumhansl')
    if key.mode == 'major':
        score = score.transpose(music21.interval.GenericInterval(-3))
    else:
        score = score.transpose(music21.interval.GenericInterval(3))
    score.write('midi', 'static/files/output.mid')