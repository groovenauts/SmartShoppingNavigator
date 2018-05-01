const INPUT_UPDATE_INTERVAL = 1000;
const OUTPUT_UPDATE_INTERVAL = 1000;
var displayLastUpdatedAt = null;

setInterval(function() {
  updateSrcImg();
}, INPUT_UPDATE_INTERVAL);

setInterval(function() {
  updateResult();
}, OUTPUT_UPDATE_INTERVAL);

$(function() {
  $('select').change(function(e) {
    disableForm();
    let data = new FormData();
    data.append('deviceId', $('#deviceId').val());
    data.append('season', $('#season').val());
    data.append('period', $('#period').val());
    $.ajax({
      url: '/setting',
      type: 'POST',
      data: data,
      cache : false,
      processData: false,
      contentType: false,
    }).done(function(data, textStatus) {
      console.log(new Date(), 'Submission was successful.');
      updateSrcImg();
      refreshResult();
    }).fail(function(xhr, textStatus, errorThrown) {
      console.error(new Date(), 'An error occurred.', textStatus);
    }).always(function() {
      enableForm();
    });
    e.preventDefault();
  });

  // Adjust iframe fit to src image size
  $('#src_image').on('load', function() {
    $('#preview').css({
      height: $(this).height()
    });
  });
  updateResult();
});

function updateSrcImg() {
  console.log(new Date(), 'Get input image');
  var src = "https://storage.googleapis.com/gcp-iost-images/annotated/" + $('#deviceId').val() + "/annotated.jpg"
  $('#src_image').attr('src', src + '?' + new Date().getTime());
}

function updateResult() {
  console.log(new Date(), 'Get device info');
  $.ajax({
    url: '/device',
    data: {deviceId: $('#deviceId').val()},
    dataType: 'json',
    cache: false,
  }).done(function(data, textStatus) {
    if (data == null) {
      refreshResult();
    } else {
      if (displayLastUpdatedAt == null || displayLastUpdatedAt < data.unixtime) {
        refreshResult();
        displayLastUpdatedAt = data.unixtime;
      }
    }
  }).fail(function(jqXHR, textStatus, errorThrown) {
    console.error(new Date(), 'An error occurred.', textStatus);
  });
}

function refreshResult() {
  console.log(new Date(), 'Get result image');
  $.ajax({
    url: '/displayByDevice',
    data: {deviceId: $('#deviceId').val()},
    dataType: 'html',
    cache: false,
  }).done(function(data, textStatus) {
    if (data) {
      console.log(new Date(), 'Set result image');
      $('#acquisition_date').text(moment().format('YYYY-MM-DD HH:mm:ss'));
      let doc = document.getElementById('preview').contentWindow.document;
      if (doc) {
        doc.open();
        doc.write(data);
        doc.close();
      }
    }
  }).fail(function(jqXHR, textStatus, errorThrown) {
    console.error(new Date(), 'An error occurred.', textStatus);
  });
}

function disableForm() {
  $('select').prop('disabled', true);
}
function enableForm() {
  $('select').prop('disabled', false);
}
