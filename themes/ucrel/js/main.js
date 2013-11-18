"use strict";

/* ---------------------------------------------------- */
// Miscellaneous functionality
/* ---------------------------------------------------- */

// Return a count of the number of keys//properties in an object.
function countProperties(object){
  return getKeys(object).length;
}

// Return an array with only unique items, i.e. .uniq
//
// Thanks to http://stackoverflow.com/questions/1960473/unique-values-in-an-array
Array.prototype.getUnique = function(){
   var u = {}, a = [];
   for(var i = 0, l = this.length; i < l; ++i){
      if(u.hasOwnProperty(this[i])) {
         continue;
      }
      a.push(this[i]);
      u[this[i]] = 1;
   }
   return a;
}

// Return a list of keys from an object.
function getKeys( object ){
  var keys = [];

  for(var k in object)
    keys.push(k);

  return keys;
}

/* ---------------------------------------------------- */
// USAS JSON parsing
/* ---------------------------------------------------- */


// Add example tooltip for a given set of examples to a given element
//
// elementName is the name of an element to add the tooltip to
// swEx is a set of single-word examples from the JSON set
// mwEx is a set of multi-word examples from JSON
function addExampleTooltip(elementName, swEx, mwEx){
 
  // Separate positive and negative
  var positive = [];
  var negative = [];

  // Single-word terms
  if(swEx){
    for (var word in swEx) {
      if (swEx.hasOwnProperty(word)) {
        if(swEx[word] != null){
          var assoc = swEx[word]["assoc"];
          if(assoc < 0)
            negative.push(word);
          else
            positive.push(word);
        }
          else
            positive.push(word);
      }
    }
  }

  // Multi-word terms
  if(mwEx){
    for (var word in mwEx) {
      if (mwEx.hasOwnProperty(word)) {
        if(mwEx[word] != null){
          var assoc = mwEx[word]["assoc"];
         
          // Quote if containing spaces
          if(/ /.test(word))
            word = "'" + word + "'";
          

          if(assoc < 0)
            negative.push(word);
          else
            positive.push(word);
        }
          else{

          // Quote if containing spaces
          if(/ /.test(word))
            word = "'" + word + "'";
          
            positive.push(word);
          }
      }
    }
  }

  
  // Hopefully not necessary
  positive = positive.getUnique();
  negative = negative.getUnique();

  // Build string
  var str = '<div style="text-align: center; font-weight: bold;">Examples</div>'
  if(positive.length > 0)
    str += '<span style="color: green; font-weight: bold;">Positive:</span> ' + positive.join(", ") + '<br>';
  if(negative.length > 0)
    str += '<span style="color: red; font-weight: bold;">Negative:</span> ' + negative.join(", ");

  // Apply the tooltip to the element.
  if(positive.length > 0 || negative.length > 0){
    $( elementName ).tooltip({
      content:  str,
      track:    true,
      disabled: false,
      items:    elementName
    });
  }

}


/* Render a single tag as a box within the wizard contents.
 *
 * prefix: The dot-separated section prefix, used as an ID in the 
 *         event
 * name: The name of this tag
 * tag: The JSON tag object itself.
 */
function renderSingleTag(prefix, name, tag){

  // Set to blank if not given
  if(!prefix || typeof prefix == 'undefined'){
    prefix = name;
  }else{
    prefix = prefix + '_' + name;
  }
 
  // Add a div with an elucidatory ID
  $( "#wizardInnerSelection" ).append("<div class=\"tagbox\" id=\"tag_" + prefix + "\"></div>");
  var divid = "#wizardInnerSelection #tag_" + prefix;

  // Add examples
  addExampleTooltip(divid, tag["swex"], tag["mwex"]);

  // Then render the template into the middle of the DIV
  var childCount = countProperties(tag["c"] || new Object());
  
  if(childCount > 0){
    // Enable the little hand 
    $( divid ).addClass( "parentBox" ),

    // Render parent tag
    $( divid ).loadTemplate( $( "#parentTemplate" ),
        {
          name: tag["name"],
      description: tag["desc"] || ("" + childCount + " subcategories"),
      childcount: childCount,
      prefix: prefix
        });

    // Load the next item on click
    $( divid ).click( function(){
      renderTags( tag["c"], prefix, tag["name"], tag["desc"])
    });
  }else{
    // Render child tag

    $( divid ).loadTemplate( $( "#leafTemplate" ),
        {
          name: tag["name"],
          description: tag["desc"] || ("" + childCount + " subcategories"),
          prefix: prefix
        });

    // Format button as a button
    $( ".tagButtonWrapper button" ).button();
    $( ".posbutton" ).button({ icons: { primary: "ui-icon-plus" } });
    $( ".negbutton" ).button({ icons: { primary: "ui-icon-minus"} });


    // Check if tag is already selected and disable the buttons if so
    if( $.inArray(prefix, getSelectedPrefixList()) != -1)
      $( divid + " .tagButtonWrapper button" ).button("option", "disabled", true);


    // Set actions to add to the list
    $( divid + " .tagButtonWrapper button.posbutton").click(function(){
      selectTag( prefix, tag["name"], true );
    });
    $( divid + " .tagButtonWrapper button.negbutton").click(function(){
      selectTag( prefix, tag["name"], false );
    });;
  }


}






// tag wizard selection stack (used for back/forward)
var tagSelectionStack = Array();

/** Construct the breadcrumb bar at the top of the tag selection
 * wizard.  Renders to the screen.
 */
function buildBreadcrumbs(){
  // Compute the breadcrumb bar
  $( "#wizardBreadcrumbs" ).html("");
  for(var i=0; i<tagSelectionStack.length; i++){
    $( "#wizardBreadcrumbs" ).append("<li><a class=\"crumb\" id=\"crumb_" + i + "\">" + tagSelectionStack[i].title + "</a></li>");


    // Make the link go back to that item.
    $( "#wizardBreadcrumbs a#crumb_" + i ).bind('mousedown', (tagSelectionStack.length - i), function(e){
      goBack(e.data);
    });

  }
}



/** Move the tag wizard up the stack by the number of items given,
 * and then render all of the tag boxes.
 *
 * howfar: The number of items to go "back" by.
 */
function goBack(howfar){
  if(howfar == undefined)
    howfar = 1;
 
  var last = null;

  tagSelectionStack.pop();  // Currently shown page
  for(var i=0; i<howfar; i++){

    var potentialLast = tagSelectionStack.pop();  // Last page
    if(potentialLast != undefined)
      last = potentialLast;
  }
    
  if(last != undefined){
    renderTags( last.tags, last.prefix, last.title, last.description)
  }
}



/** Render a list of tags.
 * Prefix is optional, and represents the position in the larger set,
 * for computing categories hierarchically
 */
function renderTags(tags, prefix, title, description){
 
  // TODO: clear, show header, back button
  $( "#wizardInnerSelection" ).html("");

  // Build breadcrumbs
  buildBreadcrumbs();

  // Set the title
  $( "#wizardTitle" ).text(title);
  $( "#wizardDescription" ).text(description);

  // If top level, don't allow back button
  if(tagSelectionStack.length == 0){
    $( ".backWizardButton" ).button("option", "disabled", true);
  }else{
    $( ".backWizardButton" ).button("option", "disabled", false);
  }
  tagSelectionStack.push({ tags: tags,
                  prefix: prefix,
                  title: title,
                  description: description
  });


  for(var key in tags){
    if (tags.hasOwnProperty(key)) {
      renderSingleTag( prefix, key, tags[key] );
    }
  }
}



/* ---------------------------------------------------- */
// Tag Wizard functionality
/* ---------------------------------------------------- */

/** Display the root of the wizard.
 */
function beginWizard(){

  // Add each item in the top-level
  renderTags( usasTags, "", "Select a Category", "Hover to see examples.");

}

/** Reset the wizard state and hide it.
 */
function cancelWizard(){
  tagSelectionStack = Array();
  return true;
}


/* ---------------------------------------------------- */
// Final selection tracking 
/* ---------------------------------------------------- */

// Store selections.
// This is the model, and the sortable JQUI item is the view.
var selection = {};


// Deselect an item, keeping the sortable selection UI widget
// in order.
function deselectTag(prefix){
  // Remove from the selection itself
  delete selection["" + prefix];

  // Take a "backup" of the order of the sortables
  var order = $( "#taglist").sortable( "toArray" );

  // Clear taglist
  $( "#taglist" ).html("");

  // Re-insert the items
  for(var i=0; i<order.length; i++){
    if(selection[order[i]]){
      addItemToSortable( selection[order[i]] );
    }
  }
}

// Add a tag to the sortable list at the bottom
// Does not add it to the model.
function addItemToSortable(tag){
 
  // TODO: Use a template!
  var label = tag.name;
  if(!tag.positive)
    label += " (negative association)";

  $( "#taglist" ).append( "<li class=\"ui-state-default\" id=\"" + tag.prefix + "\"><span class=\"ui-icon ui-icon-arrowthick-2-n-s\"></span>" + label + "<button class=\"ui-icon ui-icon-close\" id=\"close_" + tag.prefix + "\"></button></li>");


  // Make the buttons buttons.
  $( "#taglist button" ).button();

  // Clicking the button makes the item get removed.
  $( "#taglist button#close_" + tag.prefix ).click(function(){
    deselectTag(tag.prefix);
  });


  // Hover states on the static widgets
  $( "#dialog-link, #icons li, ul#taglist li" ).hover(
      function() {
        $( this ).addClass( "ui-state-hover" );
      },
      function() {
        $( this ).removeClass( "ui-state-hover" );
      }
  );

}

// Add a tag to the internal selection, and
// to the sortable UI list.
function selectTag(prefix, name, positive){

  // Clear wizard
  $( "div#wizardOverlay" ).hide();
  $( "div#wizardContent" ).hide();
  tagSelectionStack = Array();

  // Add to the list
  var tag = {
    prefix:   prefix,
    name:     name,
    positive: positive
  };
  selection["" + prefix] = tag;
  
  // Add to the sortable list
  addItemToSortable(tag);

}


// Take all preselections in preSelections var and
// add them to the page.
function preSelectTags(){
  for(var i=0; i<preSelections.length; i++){
    var t = preSelections[i];
    selectTag(t["prefix"], t["name"], t["positive"]);
  }
}


// Return an Array of prefixes from the selected model
// Returns "real" prefixes, not sortable item IDs,
// unlike getKeys()
function getSelectedPrefixList(){
  var prefixes = Array();

  for(var t in selection){
    prefixes.push(selection[t].prefix);
  }

  return prefixes;
}


/* ---------------------------------------------------- */
// Form processing 
/* ---------------------------------------------------- */

/** Submit all data from the page.
 *
 * Reformats and moves data from the js page state to the
 * HTML boxes, then submits the form using conventional
 * HTML/JS methods (i.e. no fancy JQuery AJAX calls).
 */
function submitAll(){

  if(countProperties(selection) == 0){
    $( "#validationDialog" ).dialog( "open" );
    return false;
  }

  // Set the hiddden field to a JSON string of the selection
  $( "#tagsField" ).val( JSON.stringify({
    order: $( "#taglist" ).sortable( "toArray" ),
    selection: selection 
  }));

  if(timeEnding != undefined)
    $( "#timeField" ).val( (timeEnding.getTime() - (new Date).getTime()) );

  return true;
}



/* ---------------------------------------------------- */
// .Previous work check 
/* ---------------------------------------------------- */

/** The URL used to check worker completion */
var WORKER_CHECK_URL = "/check_worker_id";

/** Perform an AJAX request to check the worker given has
 * worked (or not) on a given word.
 *
 * worker: The name of the worker
 * word: The word being worked on
 */
function checkForPreviousWork(worker, word){
  $.post( WORKER_CHECK_URL,
    { worker: worker, 
      word: word
    },
    function(data, textStatus, jqXHR){
      $( "#previousWorkAlert" ).html( data );
  });
}



/* ---------------------------------------------------- */
// Pullup for page items. 
/* ---------------------------------------------------- */

$(document).ready(function(){

  /* ------------------ Reasonably gracious pullup ------------------------- */
  // Hide the no js layer
  $( "#noJSHide" ).hide();

  /* ------------------ Set up timer ------------------------- */
  // Progress bar IF there's a time limit	(i.e. AMT tasks)
  var timeStarting = new Date();
  var timerTickRate = 1000;

  if((new Date()).getTime() < timeEnding.getTime()){

    // Say how long the timeout is
    $( "#timelimit" ).text( "" + Math.round((timeEnding.getTime() - timeStarting.getTime()) / 1000 / 60) + " minutes" );
    $( "#timeend"   ).text( "" + timeEnding.toLocaleDateString() + " " + timeEnding.toLocaleTimeString());

    // Start the progress bar off at 0
    $( "#progressbar" ).progressbar({
      value: 0
    });

    // Configure timer to update the bar.
    var timer = false;
    timer = $.timer(function() {

      // Update label
      $( "#timeend" ).text( "" + timeEnding.toLocaleDateString() + " " + timeEnding.toLocaleTimeString());

      var timeElapsed = (timeEnding.getTime() - (new Date).getTime());
      var percentage = 100 - (timeElapsed / (timeEnding.getTime() - timeStarting.getTime()) * 100);

      // Update progress bar
      $( "#progressbar" ).progressbar({value: percentage});

      // Turn bar red if over 80
      if(percentage > 80){
        $( "#progressbar" ).find( ".ui-progressbar-value" ).css({ "background" : "#FF0000" });
      }

      // Show alert if over 100
      if(percentage >= 100){
        $( "#timeoutDialog" ).dialog("open");
        timer.stop();
        $( "#submitButton" ).button("option", "disabled", true);
      }

    });
    timer.set({time: timerTickRate, autostart: true});
  }else{
    $( "#timerbar" ).hide();
  }


  /* ------------------ Set up buttons and UI ------------------------- */
  // Info tabs
  $( "#tabs" ).tabs();

  // Sortable tag list
  $( "#taglist" ).sortable();
  $( "#taglist" ).disableSelection();

  // Button to add a new tag
  $( "#newTagButton" ).button({
    icons: { 
      primary: "ui-icon-plus"
    }
  });

  // Previous work check
  $( "#workerIDButton" ).button({
    icons: {primary: "ui-icon-check" }
  });
  $( "#workerIDButton" ).click( function(){
    if( $( "#workerID" ).val().length > 0 ){
      checkForPreviousWork( $( "#workerID" ).val(), $( "#wordField" ).val() );
    }
    return false;
  });


  // Submission system for form
  $( "#inputForm" ).submit(function( event ){
    return submitAll();
  });

  // Submit button
  $( "#submitButton" ).button({ 
    icons: {primary: "ui-icon-arrowreturnthick-1-e"}
  });

  // Show tools
  $( "#showToolsButton, .showToolsWizardButton" ).button({
    icons: {primary: "ui-icon-wrench"},
  })
  $( "#showToolsButton, .showToolsWizardButton" ).click(function(){
    $( "#toolDialog" ).dialog( "open" );
    return false;
  });

  // Tools dialog
  $( "#toolDialog" ).dialog({
    autoOpen: false,
    modal: false,
    buttons: {
      "hide": function() {
        $( this ).dialog( "close" );
      }
    }
  });

  // Time out dialog
  $( "#timeoutDialog" ).dialog({
    autoOpen: false,
    modal: true,
    dialogClass: "no-close"
  });


  // Time out dialog
  $( "#validationDialog" ).dialog({
    autoOpen: false,
    modal: true
  });


  // Make overlay resizable
  $( "#wizardContent" ).resizable();

  // New tag click
  $( "#newTagButton" ).click(function() {
    // Show overlay
    $( "div#wizardOverlay" ).show();
    $( "div#wizardContent" ).show();

    beginWizard();

    return false;
  });


  // Set back button to pop from the stack
  $( ".backWizardButton" ).button({ 
    disabled: true,
    icons: {primary: "ui-icon-arrowthick-1-w"}
  });
  $( ".backWizardButton" ).click(function(){
    goBack();
    return false;
  });

  // Fire cancel wizard function when clicked
  $( ".cancelWizardButton" ).button({icons: {primary: "ui-icon-close"}});
  $( ".cancelWizardButton" ).click(function(){

    if(cancelWizard()){
      $( "div#wizardOverlay" ).hide();
      $( "div#wizardContent" ).hide();
    }

  });

  // Lastly, read any pre-selected tags and add them to the selection model
  preSelectTags();

});

