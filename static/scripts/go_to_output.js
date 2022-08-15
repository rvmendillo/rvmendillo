function go_to_output() {
    location.hash = "output";
    window.history.replaceState(null, document.title, "/");  
}