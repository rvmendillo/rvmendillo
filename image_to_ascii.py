from app import app
from flask import render_template, request
from os import remove
from rvmendillo_image_to_ascii import ImageToASCII
from json import loads

@app.route('/image_to_ascii', methods=['GET', 'POST'])
def image_to_ascii():
    project = loads(request.args['project'])
    input_type = loads(request.args['input_type'])
    image_path = loads(request.args['image_path'])
    target_width = loads(request.args['target_width'])
    charset = loads(request.args['charset'])
    color_inversion = loads(request.args['color_inversion'])
    output_type = loads(request.args['output_type'])
    if input_type == 'File':
        image_to_ascii_converter = ImageToASCII(image_path, source='local', charset=list(charset))
    else:
        image_to_ascii_converter = ImageToASCII(image_path, source='url', charset=list(charset))
    if output_type == 'Image':
        if color_inversion == 'True':
            ascii_output = image_to_ascii_converter.generate_colored_ascii_image(target_width, inverted=True)
        else:
            ascii_output = image_to_ascii_converter.generate_colored_ascii_image(target_width, inverted=False)
        base64_string = image_to_ascii_converter.convert_image_to_base64(ascii_output)
    else:
        if color_inversion == 'True':
            ascii_output = image_to_ascii_converter.generate_ascii_text(target_width, inverted=True)
        else:
            ascii_output = image_to_ascii_converter.generate_ascii_text(target_width, inverted=False)
    if input_type == 'File':
        remove(image_path)
    if output_type == 'Image':
        return render_template('project.html', name=project['name'],
                                               category=project['category'],
                                               description=project['description'],
                                               github=project['github'],
                                               demo=project['demo'],
                                               path=project['path'],
                                               base64_string=base64_string.decode())
    else:
        return render_template('project.html', name=project['name'],
                                               category=project['category'],
                                               description=project['description'],
                                               github=project['github'],
                                               demo=project['demo'],
                                               path=project['path'],
                                               ascii_output=ascii_output)