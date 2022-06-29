from flask import Flask

flask_app = Flask(__name__)
flask_app.jinja_env.trim_blocks = True
import routes

if __name__ == '__main__':
    flask_app.run()