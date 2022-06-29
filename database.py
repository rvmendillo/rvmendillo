# Import Libraries
from app import app
import pymongo

# Functions
def configure_database(username, password, project, cluster):
    client = pymongo.MongoClient(f'mongodb+srv://{username}:{password}@{project}.romwh.mongodb.net/{cluster}?retryWrites=true&w=majority')
    return client

def create_entry(table, entry):
    table.insert_one(entry)

def search_entry(table, query):
    entry = table.find_one(query)
    return entry

def search_all(table):
    entries = table.find()
    return entries

# Global
client = configure_database('admin', 'pass', 'rvmendillo', 'rvmendillo')
database = client['rvmendillo']
users = database['users']
projects = database['projects'].sort('name')

# Routes
@app.route('/users/new/<username>/<password>', methods=['GET'])
def create_user(username=None, password=None):
    create_entry(users, {'username': username,
                         'password': password})
    return f'Created user {username}.'

@app.route('/projects/new', methods=['GET'])
def create_project():
    create_entry(projects, {'name': request.args['name'],
                            'category': request.args['category']})
#                            'description': request.args['description'],
#                            'image': request.args['image'],
#                            'github': request.args['github'],
#                            'demo': request.args['demo']})
    return f"Created project {request.args['name']}."