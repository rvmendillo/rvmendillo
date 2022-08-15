function toggle_input_type() {
    if (document.getElementById("url").checked) {
        document.getElementById("url_section").style.display = "block";
        document.getElementById("file_section").style.display = "none";
    }
    else {
        document.getElementById("url_section").style.display = "none";
        document.getElementById("file_section").style.display = "block";
    }
}