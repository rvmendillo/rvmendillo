from app import app
from flask import render_template, request
from os import remove
from base64 import b64encode
from json import loads
import music21

def to_relative_scale(midi_path):
    score = music21.converter.parse(midi_path)
    key = score.analyze('Krumhansl')
    if key.mode == 'major':
        score = score.transpose(music21.interval.GenericInterval(-3))
    else:
        score = score.transpose(music21.interval.GenericInterval(3))
    score.write('midi', 'static/files/output.mid')

@app.route('/midi_to_relative_scale', methods=['GET', 'POST'])
def midi_to_relative_scale():
    project = loads(request.args['project'])
    midi_path = loads(request.args['midi_path'])
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