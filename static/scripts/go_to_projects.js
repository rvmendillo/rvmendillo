function go_to_projects() {
    $(document.body).animate({
        'scrollTop': $('#projects').offset().top
    }, 5000);
    window.history.replaceState(null, document.title, "/projects");  
}