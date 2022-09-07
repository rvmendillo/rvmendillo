from flask import Flask
from flask_socketio import SocketIO
from flask_compress import Compress
from flask_cors import CORS

app = Flask(__name__)
app.jinja_env.trim_blocks = True
CORS(app, supports_credentials=True)
compress = Compress()
compress.init_app(app)
socketio = SocketIO(app)

import routes

if __name__ == '__main__':
    socketio.run(app, debug=False, host='0.0.0.0', port=5004)