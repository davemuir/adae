$(document).on('ready page:load', function() {

    // Make sure the add answer button is showing
    $("#add-hashtag-button").css("display", "inline-block");

    var hashtagBoxCounter = 4;
    var MAX_BOX_COUNT = 6;

     $("#add-hashtag-button").click(function() {
       // add another hashtag text box when clicked under existing text box.
       var newBoxNumber = hashtagBoxCounter + 1;

       if (newBoxNumber <= MAX_BOX_COUNT) {
         var newHtml = '<input type="text" name="hashtag_box_' + newBoxNumber +'" id="hashtag-box-' + newBoxNumber +'" class="hashtag-box" >';

         $(".hashtag-input-box").append(newHtml);
         hashtagBoxCounter++;
       } else {
         $("#add-hashtag-button").css("display", "none");
       }
     });

	 $('#new_review').on('ajax:beforeSend', function(){
	    $('input[type=submit]').val('Saving....').attr('disabled','disabled');
	  });

	  $('#new_review').on('ajax:complete', function(){
	    $('input[type=submit]').val('Create Review').removeAttr('disabled');
	  });

 });

 