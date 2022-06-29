function go_to_projects() {
    location.hash = 'projects';
    window.history.replaceState(null, document.title, "/projects");  
}