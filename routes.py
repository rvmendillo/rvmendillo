# Main Libraries
from app import app
from flask import render_template, request, redirect, url_for
from json import dumps

# Projects
from database import *
from skirt_sloper import *
from midi_to_relative_scale import *
from image_to_ascii import *
from python_compiler import *
from redirects import *
from save_file import *
from captcha import *
from realtime_chat import *

# Routes
@app.route('/', methods=['GET'])
def home():
    project_list = search_all(projects).sort('name')
    return render_template('index.html', project_list=project_list)

@app.route('/projects', methods=['GET'])
def go_to_projects():
    project_list = search_all(projects).sort('name')
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
                input_type = request.form['input_type']
                if input_type == 'File':
                    image_path = save_file_and_get_path(request.files['image_file'])
                else:
                    image_path = request.form['image_url']
                target_width = int(request.form['target_width'])
                color_inversion = request.form['color_inversion']
                output_type = request.form['output_type']
                return redirect(url_for(name, project=dumps(project), input_type=dumps(input_type), image_path=dumps(image_path), target_width=dumps(target_width), color_inversion=dumps(color_inversion), output_type=dumps(output_type)), code=302)
            return 'reCAPTCHA validation failed.'
        elif name == 'python_compiler':
            if verify_captcha():
                code_path = save_text_and_get_path(request.form['python_code'], 'python.py')
                return redirect(url_for(name, project=dumps(project), code_path=dumps(code_path)), code=302)
            return 'reCAPTCHA validation failed.'

    return render_template('project.html', name=project['name'],
                                           category=project['category'],
                                           description=project['description'],
                                           github=project['github'],
                                           demo=project['demo'],
                                           path=project['path'])