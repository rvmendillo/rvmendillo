# Import Libraries
from flask import Flask, render_template, request, redirect
from database import *
from skirt_sloper import *
from os import remove
from io import BytesIO
from base64 import b64encode
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
            waist = Dimension(float(request.form['waist']))
            waist_ease = Dimension(float(request.form['waist_ease']))
            hip = Dimension(float(request.form['hip']))
            hip_height = Dimension(float(request.form['hip_height']))
            hip_ease = Dimension(float(request.form['hip_ease']))
            length = Dimension(float(request.form['length']))
            setattr(waist, 'back', waist.fourth - 0.75 + waist_ease.fourth)
            setattr(waist, 'front', waist.fourth + 0.75 + waist_ease.fourth)
            setattr(hip, 'back', hip.fourth - 0.5 + hip_ease.fourth)
            setattr(hip, 'front', hip.fourth + 0.5 + hip_ease.fourth)
            back_dart = Dart(float(request.form['back_dart']), hip_height.full * 0.75)
            front_dart = Dart(float(request.form['front_dart']), hip_height.full * 0.5)
            side_seam_balance = ((hip.half+hip_ease.half) - (waist.half+waist_ease.half) - (front_dart.depth+back_dart.depth)) / 2
            setattr(hip, 'total', hip.back + hip.front)
            
            plt.figure(figsize=(hip.total*cm, (length.full+1.5)*cm))

            # Back
            line(0, -1.5, 0, -(1.5+length.full)) # 1
            line(0, -1.5, hip.back, -1.5) # 3
            line(0, -(1.5+hip_height.full), hip.total, -(1.5+hip_height.full)) # 4
            line(0, -(1.5+length.full), hip.total, -(1.5+length.full)) # 4
            line(hip.back, -(1.5+hip_height.full), hip.back, 0) # 6
            line(hip.back, -(1.5+hip_height.full), hip.back, -(1.5+length.full)) # 6
            line(hip.back-side_seam_balance, 0, hip.total, 0) # 7
            line((hip.twelfth*2+back_dart.depth)/2, -1.5, (hip.twelfth*2+back_dart.depth)/2, -(1.5+hip_height.full)) # 10
            curve([hip.twelfth/2, -1.5], [hip.back-side_seam_balance, 0]) # 12
            line((hip.twelfth*2+back_dart.depth)/2, -(1.5+back_dart.length), hip.twelfth, -1.5) # 14
            line((hip.twelfth*2+back_dart.depth)/2, -(1.5+back_dart.length), hip.twelfth+back_dart.depth, -1.5) # 14

            # Front
            line(hip.total, -(1.5+length.full), hip.total, -(1.5-0.8)) # 2
            line(hip.total, -(1.5-0.8), hip.total-hip.front, -(1.5-0.8)) # 3
            line(hip.total, -(1.5-0.8), hip.total-hip.twelfth, -(1.5-0.8)) # 4
            line(hip.total-hip.twelfth, -(1.5-0.8), hip.total-hip.twelfth-front_dart.depth, -(1.5-0.8)) # 5
            line(((hip.total-hip.twelfth)+(hip.total-hip.twelfth-front_dart.depth))/2, -(1.5-0.8), ((hip.total-hip.twelfth)+(hip.total-hip.twelfth-front_dart.depth))/2, -(1.5+hip_height.full)) # 6
            curve([((hip.total)+(hip.total-hip.twelfth))/2, -(1.5-0.8)], [hip.back+side_seam_balance, 0], rotate=True) # 8
            line(((hip.total-hip.twelfth)+(hip.total-hip.twelfth-front_dart.depth))/2, -(1.5+front_dart.length), hip.total-hip.twelfth, -(1.5-0.8)) # 10
            line(((hip.total-hip.twelfth)+(hip.total-hip.twelfth-front_dart.depth))/2, -(1.5+front_dart.length), hip.total-hip.twelfth-front_dart.depth, -(1.5-0.8)) # 10

            # Trace
            curve([hip.back, -(1.5+back_dart.length), ((-(1.5+back_dart.length))+((-(1.5+back_dart.length))/2))/2], [hip.back-side_seam_balance, 0]) # 1
            curve([hip.back, -(1.5+back_dart.length), ((-(1.5+back_dart.length))+((-(1.5+back_dart.length))/2))/2], [hip.back+side_seam_balance, 0], rotate=True) # 2

            plt.subplots_adjust(top=1, bottom=0, right=1, left=0, hspace=0, wspace=0)
            plt.margins(0, 0)
            plt.yticks(np.arange(-(length.full+1.5)*cm, 0, 1.0))
            plt.xticks(np.arange(0, (hip.total+1)*cm, 1.0))

            temporary_file = BytesIO()
            plt.savefig(temporary_file, format='pdf', dpi=request.form['dpi'], bbox_inches='tight', pad_inches=0)
            base64_string = b64encode(temporary_file.getvalue())
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