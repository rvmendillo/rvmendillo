function allow_enter_key(event, id) {
    if (event.keyCode == 13) {
        event.preventDefault();
        var submit_button = document.getElementById(id);
        submit_button.click();
    }
}