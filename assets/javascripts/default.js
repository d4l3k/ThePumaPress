//= require jquery-2.0.3.min.js
//= require jquery-ui.js
//= require nprogress.js
//= require ui.coverflow.js
//= require strftime-min-1.3.js

function upload(file, callback) {
 
  // file is from a <input> tag or from Drag'n Drop
  // Is the file an image?
 
  if (!file || !file.type.match(/image.*/)) return;
 
  // It is!
  // Let's build a FormData object
 
  var fd = new FormData();
  fd.append("image", file); // Append the file
  fd.append("key", "c55af8f836685598a06bf3410e381826456c369a");
  // Get your own key: http://api.imgur.com/
 
  // Create the XHR (Cross-Domain XHR FTW!!!)
  var xhr = new XMLHttpRequest();
  NProgress.start();
  xhr.open("POST", "http://api.imgur.com/2/upload.json"); // Boooom!
  xhr.upload.onprogress = function(a){
        console.log(a);
  }
  xhr.onload = function() {
        // Big win!
        // The URL of the image is:
        var url = JSON.parse(xhr.responseText).upload.links.imgur_page;
        callback(url,xhr);
        NProgress.done();
   }
   // Ok, I don't handle the errors. An exercice for the reader.
   // And now, we send the formdata
   xhr.send(fd);
 }
