from app import app
from flask import redirect

@app.route('/resume', methods=['GET'])
def download_resume():
    return redirect("http://www.rvmendillo.com/static/files/Resume.pdf", code=302)

@app.route('/facebook', methods=['GET'])
def facebook():
    return redirect("http://fb.com/rvmendillo", code=302)

@app.route('/linkedin', methods=['GET'])
def linkedin():
    return redirect("http://linkedin.com/in/rvmendillo", code=302)

@app.route('/github', methods=['GET'])
def github():
    return redirect("http://github.com/rvmendillo", code=302)

@app.route('/email', methods=['GET'])
def email():
    return redirect("mailto:admin@rvmendillo.com", code=302)

@app.route('/call', methods=['GET'])
def call():
    return redirect("tel:+639234711021", code=302)