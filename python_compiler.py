from app import app
from flask import render_template, request, jsonify
from os import remove
from json import loads
from save_file import *
from base64 import b64encode
import subprocess

@app.route('/python_compiler', methods=['GET', 'POST'])
def python_compiler():
    project = loads(request.args['project'])
    code_path = loads(request.args['code_path'])
    command = f'python {code_path}'
    
    with open(code_path, 'r') as python_file:
        python_code = python_file.read()

    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    output, error = process.communicate()
    remove(code_path)
    return render_template('project.html', name=project['name'],
                                           category=project['category'],
                                           description=project['description'],
                                           github=project['github'],
                                           demo=project['demo'],
                                           path=project['path'],
                                           python_code=b64encode(python_code).decode(),
                                           output=b64encode(output.decode('utf-8')).decode(),
                                           error=b64encode(error.decode('utf-8')).decode())

@app.route('/api/python_compiler', methods=['GET', 'POST'])
def python_compiler_api():
    code_path = save_text_and_get_path(request.json['python_code'], 'python.py')
    command = f'python {code_path}'
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    output, error = process.communicate()
    remove(code_path)
    response = jsonify(output=output.decode('utf-8'))
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response