from flask import Flask
from flask_socketio import SocketIO

app = Flask(__name__)
app.jinja_env.trim_blocks = True
socketio = SocketIO(app, cors_allowed_origins='http://0.0.0.0:5004')

import routes

if __name__ == '__main__':
    socketio.run(app, debug=False, host='0.0.0.0', port=5004)