$(window).on("load", function(){
  var url = "";
  setInterval(function() {
    $.ajax({
           url: "/url"
    }).done(function(data) {
      if (url != data) {
        url = data;
        $("#mainframe").attr("src", url);
      }
    });
  }, 1000);
});
