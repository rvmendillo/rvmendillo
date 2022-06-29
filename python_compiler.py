from app import app
from flask import render_template, request
from os import remove
from json import loads
import requests
import subprocess

@app.route('/python_compiler', methods=['GET', 'POST'])
def python_compiler():
    project = loads(request.args['project'])
    code_path = loads(request.args['code_path'])

    command = f'python {code_path}'
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    output, error = process.communicate()
    remove(code_path)
    return render_template('python.html', name=project['name'],
                                          category=project['category'],
                                          description=project['description'],
                                          github=project['github'],
                                          demo=project['demo'],
                                          path=project['path'],
                                          output=output,
                                          error=error)