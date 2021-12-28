# Import Libraries
from flask import Flask, render_template, request
from database import *

# Global
app = Flask(__name__)

# Routes
@app.route('/', methods=['GET'])
def home():
    return render_template('index.html')

@app.route('/create/users/<username>/<password>', methods=['GET'])
def create_user(username, password):
    create_entry(users, {'username': username,
                         'password': password})

if __name__ == '__main__':
    app.run()