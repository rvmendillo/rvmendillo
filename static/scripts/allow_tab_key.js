function allow_tab_key(event) {
    if (event.keyCode == 9) {
        event.preventDefault();
        document.getElementById("python_code").value += "\t";
    }
}