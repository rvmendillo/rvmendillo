# Import Libraries
import pymongo

# Functions
def configure_database(username, password, project, database):
    client = pymongo.MongoClient(f'mongodb+srv://{username}:{password}@{project}.romwh.mongodb.net/{database}?retryWrites=true&w=majority')
    return client

# Global
client = configure_database('admin', 'password', 'rvmendillo', 'rvmendillo')
db = client.test