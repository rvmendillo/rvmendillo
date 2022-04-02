# Import Libraries
from flask import Flask, render_template, request, redirect
from database import *
from skirt_sloper import *
from os import remove
from rvmendillo_image_to_ascii import ImageToASCII
import requests

# Global
app = Flask(__name__)
app.jinja_env.trim_blocks = True

# Routes
@app.route('/', methods=['GET'])
def home():
    project_list = search_all(projects)
    return render_template('index.html', project_list=project_list)

@app.route('/resume', methods=['GET'])
def download_resume():
    return redirect("http://www.rvmendillo.com/static/files/Resume.pdf", code=302)

@app.route('/image_to_ascii', methods=['GET', 'POST'])
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

@app.route('/skirt_sloper', methods=['GET', 'POST'])
def skirt_sloper():
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
            return render_template('skirt_sloper.html', base64_string=base64_string.decode())
        else:
            return 'reCAPTCHA validation failed.'
    return render_template('skirt_sloper.html')

@app.route('/users/new/<username>/<password>', methods=['GET'])
def create_user(username=None, password=None):
    create_entry(users, {'username': username,
                         'password': password})
    return f'Created user {username}.'

@app.route('/projects/new', methods=['GET'])
def create_project():
    create_entry(projects, {'name': request.args['name'],
                            'category': request.args['category']})
#                            'description': request.args['description'],
#                            'image': request.args['image'],
#                            'github': request.args['github'],
#                            'demo': request.args['demo']})
    return f"Created project {request.args['name']}."

@app.route('/project/<name>', methods=['GET'])
def view_project_info(name=None):
    project = search_entry(projects, {'path': name})
    return render_template('project.html', name=project['name'],
                                           category=project['category'],
                                           description=project['description'],
                                           github=project['github'],
                                           demo=project['demo'])

if __name__ == '__main__':
    app.run()