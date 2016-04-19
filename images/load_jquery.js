$(function() {
	var to = false;
	$('#demo_q').keyup(function () {
		if(to) { clearTimeout(to); }
		to = setTimeout(function () {
		var v = $('#demo_q').val();
		$('#jstree_demo_div').jstree(true).search(v);
		}, 250);
	});

	$('#jstree_demo_div').jstree({
		"core" : {
			"multiple" : false,
			"animation" : 0
		},
		"checkbox" : {
			"keep_selected_style" : false
		},
		"types" : {
			"disabled" : {
				"select_node" : false,
				"open_node" :   false,
				"close_node" :  false,
				"create_node" : false,
				"delete_node" : false,
				"check_node" : false,
				"uncheck_node" : false
			}
		},
  		"search": { "fuzzy": false },
		"plugins" : [ "search", "checkbox", "wholerow", "types"]
	});

  $('#jstree_demo_div').on('select_node.jstree', function (e, data) {
    var i, j, r = [];
    for(i = 0, j = data.selected.length; i < j; i++) {
      r.push(data.instance.get_node(data.selected[i]).text);
    }
    document.getElementsByName("TOXTERM")[0].value = r.join(', ');
  });

	$("#tabs").tabs({ 
		fx: [{opacity:'toggle', duration:'normal'},
				{opacity:'toggle', duration:'fast'}],
		active: 2
		}).addClass('ui-tabs-vertical ui-helper-clearfix');
	$(" li.last a").unbind('click').click(function() {
		this.href = this.href;
	});

	window.alert = function(title, message){
   	 $(document.createElement('div'))
      	  .attr({title: title})
      	  .html(message)
      	  .dialog({
			  		dialogClass: 'ui-state-highlight',
            	buttons: {OK: function(){$(this).dialog('close');}},
            	close: function(){$(this).remove();},
            	draggable: true,
            	modal: true,
            	resizable: false,
            	width: 'auto'
      	  });
	};

	$( "input[type=submit], button" )
      .button()
      .click(function( event ) {
        if ( document.getElementsByName("TOXTERM")[0].value === "" ) {
		  alert("Toxicity Missing!", "Please select a toxicity term from the list<BR>above before searching for a gene.");
            event.preventDefault();
        }
      });

	$( ".help_info" ).tooltip(
		{ items: "span, [tooltip-data]",
			tooltipClass: 'help-tooltip-styling',
			show: { delay: 500 },
			content: function() {
				var element = $( this );
				if ( element.is( "[tooltip-data]" ) ) {
					var text = element.attr("tooltip-data");
					return text;
				}
			}
		}
	);

	$( ".evid_info" ).tooltip(
		{ items: "span, [tooltip-data]",
			tooltipClass: 'evid-tooltip-styling',
			show: { delay: 100 },
			content: function() {
				var element = $( this );
				if ( element.is( "[tooltip-data]" ) ) {
					var text = element.attr("tooltip-data");
					return text;
				}
			}
		}
	);

});
