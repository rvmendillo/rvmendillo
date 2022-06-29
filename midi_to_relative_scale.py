from app import app
from flask import render_template, request
from os import remove
from base64 import b64encode
import music21

def to_relative_scale(midi_path):
    score = music21.converter.parse(midi_path)
    key = score.analyze('Krumhansl')
    if key.mode == 'major':
        score = score.transpose(music21.interval.GenericInterval(-3))
    else:
        score = score.transpose(music21.interval.GenericInterval(3))
    score.write('midi', 'static/files/output.mid')

midi_file = request.files['midi_file']
midi_path = 'static/files/' + midi_file.filename
midi_file.save(midi_path)
to_relative_scale(midi_path)
with open('static/files/output.mid', 'rb') as midi_file:
    temporary_file = midi_file.read()
remove(midi_path)
base64_string = b64encode(temporary_file)
return render_template('project.html', name=project['name'],
                                        category=project['category'],
                                        description=project['description'],
                                        github=project['github'],
                                        demo=project['demo'],
                                        path=project['path'],
                                        base64_string=base64_string.decode())