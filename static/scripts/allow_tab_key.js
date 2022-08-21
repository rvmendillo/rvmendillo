function allow_tab_key(event) {
    if (event.keyCode == 9) {
        e.preventDefault();
        document.getElementById("python_code").value += "\t";
    }
}