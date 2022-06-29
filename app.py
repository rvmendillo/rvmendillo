from flask import Flask

app = Flask(__name__)
app.jinja_env.trim_blocks = True
import routes

if __name__ == '__main__':
    app.run()