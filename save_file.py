def save_file_and_get_path(file, filename=file.filename):
    file_path = 'static/files/' + filename
    file.save(file_path)
    return file_path

def save_text_and_get_path(text, filename):
    text_path = 'static/scripts/' + filename
    with open(text_path, 'w') as text_file:
        text_file.write(text)
    return text_path