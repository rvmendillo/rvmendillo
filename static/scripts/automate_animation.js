function automate_animation() {
    var h1_list = document.querySelectorAll("section:not(:first-of-type) .row .column h1");
    for (var i = 0; i < h1_list.length; i++)
        h1_list[i].setAttribute("data-aos", "fade-up");

    var h1_list = document.querySelectorAll("section[id='projects'] .row .column h1");
    for (var i = 0; i < h1_list.length; i++)
        h1_list[i].setAttribute("data-aos", "fade-up");

    var column_list = document.querySelectorAll("section:not(:first-of-type) .row:not([class='row center_y']) .column");
    for (var i = 0; i < column_list.length; i++)
        column_list[i].setAttribute("data-aos", "zoom-in");
    
    var column_list = document.querySelectorAll("section[id='projects'] .multicolumn .column");
    for (var i = 0; i < column_list.length; i++)
        column_list[i].setAttribute("data-aos", "zoom-in");

    var a_list = document.querySelectorAll("section:not(:first-of-type):not([id='projects']) .row .column .button");
    for (var i = 0; i < a_list.length; i++)
        a_list[i].setAttribute("data-aos", "zoom-in");

    AOS.init();
}