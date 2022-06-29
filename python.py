from app import app
from flask import render_template, request
import requests
import subprocess
from os import remove

@app.route('/python', methods=['GET', 'POST'])
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