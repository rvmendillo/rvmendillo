from app import flask_app
from flask import render_template, request, redirect, url_for
from database import *
from skirt_sloper import *
from midi_to_relative_scale import *
from os import remove
from io import BytesIO
from base64 import b64encode
from rvmendillo_image_to_ascii import ImageToASCII
import requests
import subprocess

@flask_app.route('/', methods=['GET'])
def home():
    project_list = search_all(projects)
    return render_template('index.html', project_list=project_list)

@flask_app.route('/resume', methods=['GET'])
def download_resume():
    return redirect("http://www.rvmendillo.com/static/files/Resume.pdf", code=302)

@flask_app.route('/projects', methods=['GET'])
def go_to_projects():
    project_list = search_all(projects)
    return render_template('index.html', project_list=project_list, forced_link=True)

@flask_app.route('/image_to_ascii', methods=['GET', 'POST'])
def image_to_ascii():
    if request.method == 'POST':
        response = requests.post('https://www.google.com/recaptcha/api/siteverify', data={'secret': '6Lfq6-QdAAAAAI6KgavwJfqdPq-FdQFoogEngYTv',
                                                                                          'response': request.form['g-recaptcha-response']})
        if response.json()['success']:
            image_file = request.files['image_file']
            image_path = 'static/images/' + image_file.filename
            image_file.save(image_path)
            image_to_ascii_converter = ImageToASCII(image_path, default_font=True)
            inverted_colored_ascii_image = image_to_ascii_converter.generate_colored_ascii_image(300)
            base64_string = image_to_ascii_converter.convert_image_to_base64(inverted_colored_ascii_image)
            remove(image_path)
            return render_template('image_to_ascii.html', base64_string=base64_string.decode())
        else:
            return 'reCAPTCHA validation failed.'
    return render_template('image_to_ascii.html')

@flask_app.route('/python', methods=['GET', 'POST'])
def python():
    if request.method == 'POST':
        response = requests.post('https://www.google.com/recaptcha/api/siteverify', data={'secret': '6Lfq6-QdAAAAAI6KgavwJfqdPq-FdQFoogEngYTv',
                                                                                          'response': request.form['g-recaptcha-response']})
        if response.json()['success']:
            python_code = request.form['python_code']
            code_path = 'static/scripts/' + 'python.py'
            with open(code_path, 'w') as python_file:
                python_file.write(python_code)
            command = f'python {code_path}'
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
            output, error = process.communicate()
            remove(code_path)
            return render_template('python.html', output=output, error=error)
        else:
            return 'reCAPTCHA validation failed.'
    return render_template('python.html')

@flask_app.route('/users/new/<username>/<password>', methods=['GET'])
def create_user(username=None, password=None):
    create_entry(users, {'username': username,
                         'password': password})
    return f'Created user {username}.'

@flask_app.route('/projects/new', methods=['GET'])
def create_project():
    create_entry(projects, {'name': request.args['name'],
                            'category': request.args['category']})
#                            'description': request.args['description'],
#                            'image': request.args['image'],
#                            'github': request.args['github'],
#                            'demo': request.args['demo']})
    return f"Created project {request.args['name']}."

@flask_app.route('/project/<name>', methods=['GET', 'POST'])
def view_project_info(name=None):
    project = search_entry(projects, {'path': name})

    if request.method == 'POST':
        if name == 'midi_to_relative_scale':
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

    return render_template('project.html', name=project['name'],
                                           category=project['category'],
                                           description=project['description'],
                                           github=project['github'],
                                           demo=project['demo'],
                                           path=project['path'])