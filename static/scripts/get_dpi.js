function get_dpi() {
    for (var dpi = 56; dpi < 2000; dpi++)
        if (matchMedia("(max-resolution: " + dpi + "dpi)").matches)
        	return dpi;
}