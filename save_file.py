def save_file_and_get_path(file):
    file_path = 'static/files/' + file.filename
    file.save(file_path)
    return file_path