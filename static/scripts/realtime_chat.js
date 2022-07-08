var socket = io();

function send_message() {
    var username = document.getElementById("chat_username").value;
    var message = document.getElementById("chat_message").value;
    var formatted_message = username + ": " + message;
    socket.send(formatted_message);
}

socket.on("message", (formatted_message) => {
    document.getElementById("chat_history").innerHTML += "<p>" + formatted_message + "</p>";
})