from app import app
from flask import render_template, request
from os import remove
from rvmendillo_image_to_ascii import ImageToASCII
from json import loads
import requests

@app.route('/image_to_ascii', methods=['GET', 'POST'])
def image_to_ascii():
    project = loads(request.args['project'])
    image_path = loads(request.args['image_path'])
    image_to_ascii_converter = ImageToASCII(image_path, default_font=True)
    inverted_colored_ascii_image = image_to_ascii_converter.generate_colored_ascii_image(300)
    base64_string = image_to_ascii_converter.convert_image_to_base64(inverted_colored_ascii_image)
    remove(image_path)
    return render_template('project.html', name=project['name'],
                                           category=project['category'],
                                           description=project['description'],
                                           github=project['github'],
                                           demo=project['demo'],
                                           path=project['path'],
                                           base64_string=base64_string.decode())