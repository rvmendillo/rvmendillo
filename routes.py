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
    print(type(project))
    print(type(request.files))
    print(project)
    print(request.files)
    print(request.files['midi_file'])
    print(request.files.to_dict())
    print(request.files.to_dict(flat=False))
    print(request.files.to_dict(flat=False)['midi_file'])

    if request.method == 'POST':
        if name == 'midi_to_relative_scale':
            return redirect(url_for(name), project=dumps(project), files=dumps(request.files['midi_file']), code=307)

    return render_template('project.html', name=project['name'],
                                           category=project['category'],
                                           description=project['description'],
                                           github=project['github'],
                                           demo=project['demo'],
                                           path=project['path'])