# Main Libraries
from app import app
from flask import render_template, request, redirect, url_for
from json import dumps
from secrets import token_hex

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
from mbti_personality_predictor import *
from knapsack_problem import *

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
            midi_path = verify_captcha(save_file_and_get_path)(request.files['midi_file'])
            return redirect(url_for(name, project=dumps(project), midi_path=dumps(midi_path)), code=302)
        elif name == 'mbti_personality_predictor':
            paragraph_to_predict = request.form['paragraph_to_predict']
            return verify_captcha(redirect)(url_for(name, project=dumps(project), paragraph_to_predict=dumps(paragraph_to_predict)), code=302)
        elif name == 'image_to_ascii':
            input_type = request.form['input_type']
            if input_type == 'File':
                image_path = verify_captcha(save_file_and_get_path)(request.files['image_file'])
            else:
                image_path = request.form['image_url']
            target_width = int(request.form['target_width'])
            charset = request.form['charset']
            color_inversion = request.form['color_inversion']
            output_type = request.form['output_type']
            if input_type == 'File':
                return redirect(url_for(name, project=dumps(project), input_type=dumps(input_type), image_path=dumps(image_path), target_width=dumps(target_width), charset=dumps(charset), color_inversion=dumps(color_inversion), output_type=dumps(output_type)), code=302)
            return verify_captcha(redirect)(url_for(name, project=dumps(project), input_type=dumps(input_type), image_path=dumps(image_path), target_width=dumps(target_width), charset=dumps(charset), color_inversion=dumps(color_inversion), output_type=dumps(output_type)), code=302)
        elif name == 'python_compiler':
            python_code = request.form['python_code']
            code_path = verify_captcha(save_text_and_get_path)(python_code, token_hex() + '.py')
            return redirect(url_for(name, project=dumps(project), code_path=dumps(code_path)), code=302)
        elif name == 'knapsack_problem':
            population = request.form['population']
            weight_limit = request.form['weight_limit']
            fitness_limit = request.form['fitness_limit']
            generation_limit = request.form['generation_limit']
            items = [[request.form['item_' + str(x+1) + '_' + str(y+1)] for y in range(3)] for x in range(5)]
            return verify_captcha(redirect)(url_for(name, project=dumps(project), population=dumps(population), weight_limit=dumps(weight_limit), fitness_limit=dumps(fitness_limit), generation_limit=dumps(generation_limit), items=dumps(items)), code=302)

    return render_template('project.html', name=project['name'],
                                           category=project['category'],
                                           description=project['description'],
                                           github=project['github'],
                                           demo=project['demo'],
                                           path=project['path'])
