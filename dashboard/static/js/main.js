const SRC_IMG_URL = "https://storage.googleapis.com/gcp-iost-images/annotated/picamera01/annotated.jpg";
const SRC_IMG_INTERVAL = 100000;

setTimeout(function() {
  $('#src_image').attr('src', SRC_IMG_URL);
}, SRC_IMG_INTERVAL);

$(function() {
  $('select').change(function(e) {
    disableForm();
    $.ajax({
      url: '/setting',
      type: 'POST',
      data: $('form').serialize(),
      timeout: 1000 * 60,
    }).done(function(data) {
      console.log(new Date(), 'Submission was successful.');
      console.log(data);
    }).fail(function(data) {
      console.log(new Date(), 'An error occurred.');
      console.log(data);
    }).always(function(data) {
      enableForm();
    });
    e.preventDefault();
  });
});

function disableForm() {
  $('select').prop('disabled', true);
}
function enableForm() {
  $('select').prop('disabled', false);
}
