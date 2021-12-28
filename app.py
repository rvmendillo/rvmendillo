# Import Libraries
from flask import Flask, render_template, request
from database import *

# Global
app = Flask(__name__)

# Routes
@app.route('/', methods=['GET', 'POST'])
def home():
    return render_template('index.html')

if __name__ == '__main__':
    app.run()