from flask import Flask
from flask_socketio import SocketIO, send, emit

app = Flask(__name__)
app.jinja_env.trim_blocks = True

import routes

if __name__ == '__main__':
    socketio.run(app, debug=False, host='0.0.0.0', port=5004)