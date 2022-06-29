from flask import Flask

app = Flask(__name__)

if __name__ == '__main__':
    app.jinja_env.trim_blocks = True
    import routes
    app.run()