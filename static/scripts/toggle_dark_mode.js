if (localStorage.dark_mode == null)
	localStorage.dark_mode = false;
else if (localStorage.dark_mode)
    document.body.classList.toggle('dark_mode');

function toggle_dark_mode() {
    document.body.classList.toggle('dark_mode');
    localStorage.dark_mode = !localStorage.dark_mode;
}