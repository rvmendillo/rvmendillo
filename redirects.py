from app import app
from flask import redirect

@app.route('/resume', methods=['GET'])
def download_resume():
    return redirect("http://www.rvmendillo.com/static/files/Resume.pdf", code=302)