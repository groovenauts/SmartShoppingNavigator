const INPUT_UPDATE_INTERVAL = 1000;

setInterval(function() {
  updateSrcImg();
}, INPUT_UPDATE_INTERVAL);

$(function() {
  // Adjust iframe fit to src image size
  $('#src_image').on('load', function() {
    $('#preview').css({
      height: $(this).height()
    });
  });
});

function updateSrcImg() {
  console.log(new Date(), 'Get input image');
  var src = "https://storage.googleapis.com/" + document.imageBucket + "/annotated/" + $('#deviceId').val() + "/annotated.jpg"
  $('#src_image').attr('src', src + '?' + new Date().getTime());
}
