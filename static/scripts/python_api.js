function run_code() {
    document.getElementById("python_output").innerHTML = "Compiling...";
    var data = JSON.stringify({"python_code": document.getElementById("python_code").innerHTML});
    var xhr = new XMLHttpRequest();
    xhr.withCredentials = true;
    xhr.addEventListener("readystatechange", function() {
        if(this.readyState === 4)
            document.getElementById("python_output").innerHTML = JSON.parse(this.responseText)['output'];
    });
    xhr.open("POST", "https://rvmendillo.com/api/python_compiler");
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.send(data);
}