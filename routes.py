# Main Libraries
from app import app
from flask import render_template, request, redirect, url_for
from json import dumps

# Projects
from database import *
from skirt_sloper import *
from midi_to_relative_scale import *
from image_to_ascii import *
from python import *
from redirects import *
from save_file import *
from captcha import *

# Routes
@app.route('/', methods=['GET'])
def home():
    project_list = search_all(projects)
    return render_template('index.html', project_list=project_list)

@app.route('/projects', methods=['GET'])
def go_to_projects():
    project_list = search_all(projects)
    return render_template('index.html', project_list=project_list, forced_link=True)

@app.route('/project/<name>', methods=['GET', 'POST'])
def view_project_info(name=None):
    project = search_entry(projects, {'path': name})
    try:
        project.pop('_id')
    except:
        return 'This project does not exist.'

    if request.method == 'POST':
        if name == 'midi_to_relative_scale':
            midi_path = save_file_and_get_path(request.files['midi_file'])
            return redirect(url_for(name, project=dumps(project), midi_path=dumps(midi_path)), code=302)
        elif name == 'skirt_sloper':
            if verify_captcha():
                return redirect(url_for(name, project=dumps(project)), code=302)
            return 'reCAPTCHA validation failed.'
        elif name == 'image_to_ascii':
            if verify_captcha():
                image_path = save_file_and_get_path(request.files['image_file'])
                return redirect(url_for(name, project=dumps(project), image_path=dumps(image_path)), code=302)
            return 'reCAPTCHA validation failed.'

    return render_template('project.html', name=project['name'],
                                           category=project['category'],
                                           description=project['description'],
                                           github=project['github'],
                                           demo=project['demo'],
                                           path=project['path'])