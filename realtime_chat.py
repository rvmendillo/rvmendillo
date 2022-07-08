from app import socketio
from flask_socketio import send, emit

@socketio.on('message')
def handle_message(formatted_message):
    send(formatted_message, broadcast=True)