const INPUT_URL = "https://storage.googleapis.com/gcp-iost-images/annotated/picamera01/annotated.jpg";
const INPUT_INTERVAL = 10000;
const OUTPUT_INTERVAL = 10000;

setTimeout(function() {
  $('#src_image').attr('src', INPUT_URL);
}, INPUT_INTERVAL);

setTimeout(function() {
  $.ajax({
    url: '/displayByDevice',
    data: {deivceId: "picamera01"},
    dataType: 'html',
  }).done(function(data, textStatus) {
    console.log(data);
    if (data) {
      $('.content-footer').text(moment().format('YYYY-MM-DD HH:mm:ss'));
      let doc = document.getElementById('preview').contentWindow.document;
      if (doc) {
        doc.open();
        doc.write(data);
        doc.close();
      }
    }
  }).fail(function(jqXHR, textStatus, errorThrown) {
    console.log(new Date(), 'An error occurred.', textStatus);
  });
}, OUTPUT_INTERVAL);

$(function() {
  $('select').change(function(e) {
    disableForm();
    $.ajax({
      url: '/setting',
      type: 'POST',
      data: $('form').serialize(),
    }).done(function(data, textStatus) {
      console.log(new Date(), 'Submission was successful.');
      console.log(data);
    }).fail(function(xhr, textStatus, errorThrown) {
      console.log(new Date(), 'An error occurred.', textStatus);
    }).always(function() {
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
