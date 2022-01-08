# Import Libraries
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
projects = database['projects']