function allow_tab_key(event, id) {
    if (event.keyCode == 9) {
        event.preventDefault();
        var textarea = document.getElementById(id);
        var selection_start = textarea.selectionStart;
        var selection_end = textarea.selectionEnd;
        textarea.value = textarea.value.substring(0, selection_start) + "\t" + textarea.value.substring(selection_end);
        textarea.selectionStart = textarea.selectionEnd = selection_start + 1;
    }
}