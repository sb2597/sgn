
/* 

=head1 NAME

CXGN.List - a javascript library to implement the lists on the SGN platform

=head1 DESCRIPTION

There are two important list functions in this library, listed below. All other functions should be considered private and/or deprecated.


* addToListMenu(listMenuDiv, dataDiv)

this function will generate a select of all available lists and allow the content to be added to a list (from a search, etc). The first parameter is the id of the div tag where the menu should be drawn. The second parameter is the div that contains the data to be added. This can be a textfield, a div or span tag, or a multiple select tag.

* pasteListMenu(divName, menuDiv, buttonName)

this will generate an html select box of all the lists, and a "paste" button, to paste into a textarea (typically). The divName is the id of the textarea, the menuDiv is the id where the paste menu should be placed.


Public List object functions

* listSelect(divName, types)

will create an html select with id and name 'divName'. Optionally, a list of types can be specified that will limit the menu to the respective types. 

Usage:
You have to instantiate the list object first:

var lo = new CXGN.List(); var s = lo.listSelect('myseldiv', [ 'trials' ]);


* validate(list_id, type, non_interactive)

* transform(list_id, new_type)


=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

*/

//JSAN.use('jqueryui');

if (!CXGN) CXGN = function () { };

CXGN.List = function () { 
    this.list = [];
};


CXGN.List.prototype = { 
    
    // Return the data as a straight list
    //
    getList: function(list_id) { 	
	var list;
	
	jQuery.ajax( { 
	    url: '/list/contents/'+list_id,
	    async: false,
	    success: function(response) { 
		if (response.error) { 
		    //document.write(response.error);
		}
		else { 
		    list = response;
		}
	    },
	    error: function(response) { 
		alert("An error occurred.");
	    }
	});
	return list;

    },


    // this function also returns some metadata about
    // list, namely its type.
    //
    getListData: function(list_id) { 
	var list;
	
	jQuery.ajax( { 
	    url: '/list/data',
	    async: false,
	    data: { 'list_id': list_id },
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		else { 
		    list = response;
		}
	    }
	});
	
	return list;
    },
 
    getListType: function(list_id) { 
	var type;

	jQuery.ajax( { 
	    url: '/list/type/'+list_id,
	    async: false,
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		else { 
		    type = response.list_type;
		    return type;
		}
	    },
	    error: function () {
		alert('An error occurred. Cannot determine type. ');
	    }
	   
	});
	return type;
    },
	    
    setListType: function(list_id, type) { 
	
	jQuery.ajax( { 
	    url: '/list/type/'+list_id+'/'+type,
	    async: false,
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		else { 
		    //alert('Type of list '+list_id+' set to '+type);
		}
	    } 
	});
    },


    allListTypes: function() { 
	var types;
	jQuery.ajax( { 
	    url: '/list/alltypes',
	    async: false,
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		else { 
		    types = response;
		}
	    }
	});
	return types;
		     
    },
    
    typesHtmlSelect: function(list_id, html_select_id, selected) { 
	var types = this.allListTypes();
	var html = '<select class="form-control" id="'+html_select_id+'" onchange="javascript:changeListType(\''+html_select_id+'\', '+list_id+');" >';
	html += '<option name="null">(none)</option>';
	for (var i=0; i<types.length; i++) { 
	    var selected_html = '';
	    if (types[i][1] == selected) { 
		selected_html = ' selected="selected" ';
	    }
	    html += '<option name="'+types[i][1]+'"'+selected_html+'>'+types[i][1]+'</option>';
	}
	html += '</select>';
	return html;
    },

    newList: function(name) { 
	var oldListId = this.existsList(name);
	var newListId = 0;
	
	if (name == '') { 
	    alert('Please provide a name for the new list.');
	    return 0;
	}

	if (oldListId === null) { 
	    jQuery.ajax( { 
		url: '/list/new',
		async: false,
		data: { 'name': name },
		success: function(response) { 
		    if (response.error) { 
			alert(response.error);
		    }
		    else { 
			newListId=response.list_id;
		    }
		}
	    });
	    return newListId;
	}
	else { 
	    alert('A list with name "'+ name + '" already exists. Please choose another list name.');
	    return 0;
	}
	alert("An error occurred. Cannot create new list right now.");
	return 0;
    },

    availableLists: function(list_type) { 
	var lists = [];
	jQuery.ajax( { 
	    url: '/list/available',
	    data: { 'type': list_type },
	    async: false,
	    success: function(response) { 
		if (response.error) { 
		    //alert(response.error);  //do not alert here
		}
		lists = response;
	    },
	    error: function(response) { 
		alert("An error occurred");
	    }
	});
	return lists;
    },

    publicLists: function(list_type) { 
	var lists = [];
	jQuery.ajax( { 
	    url: '/list/available_public',
	    data: { 'type': list_type },
	    async: false,
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		lists = response;
	    },
	    error: function(response) { 
		alert("An error occurred");
	    }
	});
	return lists;
    },

    //return the newly created list_item_id or 0 if nothing was added
    //(due to duplicates)
    addItem: function(list_id, item) { 
	var exists_item_id = this.existsItem(list_id,item);
	if (exists_item_id ===0 ) { 
	    jQuery.ajax( { 
		async: false,
		url: '/list/item/add',
		data:  { 'list_id': list_id, 'element': item },
		success: function(response) { 
		    if (response.error) { 
			alert(response.error); 
			return 0;
		    }
                }
	    });
	    var new_list_item_id = this.existsItem(list_id,item);
	    return new_list_item_id;
	}
	else { return 0; }
    },

    addBulk: function(list_id, items) { 
	
	var elements = items.join("\t");

	var count;
	jQuery.ajax( { 
	    async: false,
	    method: 'POST',
	    url: '/list/add/bulk',
	    data:  { 'list_id': list_id, 'elements': elements },
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		else { 
		    if (response.duplicates) { 
			alert("The following items are already in the list and were not added: "+response.duplicates.join(", "));
		    }
		    count = response.success;
		}		
	    }
	});
	return count;
    },
    
    removeItem: function(list_id, item_id) {
	jQuery.ajax( {
	    async: false,
	    url: '/list/item/remove',
	    data: { 'list_id': list_id, 'item_id': item_id }
	});
    },
    
    deleteList: function(list_id) { 
	jQuery.ajax( { 
	    url: '/list/delete',
	    async: false,
	    data: { 'list_id': list_id }
	});
    },

    renderLists: function(div) { 
	var lists = this.availableLists();
	var html = '';
	html = html + '<div class="input-group"><input id="add_list_input" type="text" class="form-control" placeholder="Create New List" /><span class="input-group-btn"><button class="btn btn-primary" type="button" id="add_list_button" value="new list">New List</button></span></div><br/>';
	
	if (lists.length===0) { 
	    html = html + "None";
	    jQuery('#'+div+'_div').html(html);
	}

	html += '<table class="table table-hover table-condensed">';
	html += '<thead><tr><th>&nbsp;</th><th>List Name</th><th>Count</th><th>Type</th><th colspan="4">Actions</th></tr></thead><tbody>'; 
	for (var i = 0; i < lists.length; i++) { 
	    html += '<tr><td><input type="checkbox" name="list_select_checkbox" value="'+lists[i][0]+'"/></td>';
	    html += '<td><b>'+lists[i][1]+'</b></td>';
	    html += '<td>'+lists[i][3]+'</td>';
	    html += '<td>'+lists[i][5]+'</td>';
	    html += '<td><a title="View" id="view_list_'+lists[i][1]+'" href="javascript:showListItems(\'list_item_dialog\','+lists[i][0]+')"><span class="glyphicon glyphicon-th-list"></span></a></td>';
	    html += '<td><a title="Delete" id="delete_list_'+lists[i][1]+'" href="javascript:deleteList('+lists[i][0]+')"><span class="glyphicon glyphicon-remove"></span></a></td>';
	    html += '<td><a target="_blank" title="Download" id="download_list_'+lists[i][1]+'" href="/list/download?list_id='+lists[i][0]+'"><span class="glyphicon glyphicon-arrow-down"></span></a></td>';
	    if (lists[i][6] == 0){
		html += '<td><a title="Make Public" id="share_list_'+lists[i][1]+'" href="javascript:togglePublicList('+lists[i][0]+')"><span class="glyphicon glyphicon-share-alt"></span></a></td></tr>';
	    } else if (lists[i][6] == 1){
		html += '<td><a title="Make Private" id="share_list_'+lists[i][1]+'" href="javascript:togglePublicList('+lists[i][0]+')"><span class="glyphicon glyphicon-ban-circle"></span></a></td></tr>';
	    }
	}
	html = html + '</tbody></table>';
	html += '<div id="list_group_select_action"></div>';

	jQuery('#'+div+'_div').html(html);

	jQuery('#add_list_button').click(function() { 
	    var lo = new CXGN.List();
	    
	    var name = jQuery('#add_list_input').val();
	    
	    lo.newList(name);
	    lo.renderLists(div);
	});

	jQuery('#view_public_lists_button').click(function() { 
	    jQuery('#public_list_dialog').modal('show');
	    var lo = new CXGN.List();
	    lo.renderPublicLists('public_list_dialog_div');
	});

	jQuery("input[name='list_select_checkbox']").click(function() {
	    var total=jQuery("input[name='list_select_checkbox']:checked").length;
	    var list_group_select_action_html='';
	    if (total == 0) {
		list_group_select_action_html += '';
	    } else {
		var selected = [];
		$("input:checkbox:checked").each(function() {
		    selected.push($(this).attr('value'));
		});
		console.log(selected);

		list_group_select_action_html = '<hr><div class="row"><div class="col-sm-4">For Selected Lists:</div><div class="col-sm-8">';
		if (total == 1) {
		    list_group_select_action_html += '<a class="btn btn-default btn-sm" style="color:white" href="javascript:deleteSelectedListGroup(['+selected+'])">Delete</a><a class="btn btn-default btn-sm" style="color:white" href="javascript:makePublicSelectedListGroup(\'list_item_dialog\','+selected+')">Make Public</a>';	
		} else if (total > 1) {
		    list_group_select_action_html += '<a class="btn btn-default btn-sm" style="color:white" href="javascript:deleteSelectedListGroup(['+selected+'])">Delete</a><a class="btn btn-default btn-sm" style="color:white" href="javascript:makePublicSelectedListGroup(\'list_item_dialog\','+selected+')">Make Public</a><a class="btn btn-default btn-sm" style="color:white" href="javascript:combineSelectedListGroup(\'list_item_dialog\','+selected+')">Combine</a>';
		}
		list_group_select_action_html += '</div></div>';
	    }
	    jQuery("#list_group_select_action").html(list_group_select_action_html);
	});
    },

    renderPublicLists: function(div) {
	var lists = this.publicLists();
	var html = '';

	html += '<table id="public_list_data_table" class="table table-hover table-condensed">';
	html += '<thead><tr><th>List Name</th><th>Count</th><th>Type</th><th>Actions</th><th>&nbsp;</th><th>&nbsp;</th></tr></thead><tbody>'; 
	for (var i = 0; i < lists.length; i++) { 
	    html += '<tr><td><b>'+lists[i][1]+'</b></td>';
	    html += '<td>'+lists[i][3]+'</td>';
	    html += '<td>'+lists[i][5]+'</td>';
	    html += '<td><a title="View" id="view_public_list_'+lists[i][1]+'" href="javascript:showPublicListItems(\'list_item_dialog\','+lists[i][0]+')"><span class="glyphicon glyphicon-th-list"></span></a></td>';
	    html += '<td><a target="_blank" title="Download" id="download_public_list_'+lists[i][1]+'" href="/list/download?list_id='+lists[i][0]+'"><span class="glyphicon glyphicon-arrow-down"></span></a></td>';
	    html += '<td><a title="Copy to Your Lists" id="copy_public_list_'+lists[i][1]+'" href="javascript:copyPublicList('+lists[i][0]+')"><span class="glyphicon glyphicon-plus"></span></a></td>';
	}
	html = html + '</tbody></table>';

	jQuery('#'+div).html(html);

	jQuery('#public_list_data_table').DataTable({
	    "destroy": true,
	    "columnDefs": [   { "orderable": false, "targets": [3,4,5] }  ]
	});
    },
    
    listNameById: function(list_id) { 
	lists = this.availableLists();
	for (var n=0; n<lists.length; n++) { 
	    if (lists[n][0] == list_id) { return lists[n][1]; }
	}
    },

    publicListNameById: function(list_id) { 
	lists = this.publicLists();
	for (var n=0; n<lists.length; n++) { 
	    if (lists[n][0] == list_id) { return lists[n][1]; }
	}
    },

    renderItems: function(div, list_id) { 
	var list_data = this.getListData(list_id);
	var items = list_data.elements;
	var list_type = list_data.type_name;
	var list_name = this.listNameById(list_id);
	
	var html = '';
	html += '<table class="table"><tr><td>List ID</td><td id="list_id_div">'+list_id+'</td></tr>';
	html += '<tr><td>List name:<br/><input type="button" class="btn btn-primary btn-xs" id="updateNameButton" value="Update" /></td>';
	html += '<td><input class="form-control" type="text" id="updateNameField" size="10" value="'+list_name+'" /></td></tr>';
	html += '<tr><td>Type:<br/><input id="list_item_dialog_validate" type="button" class="btn btn-primary btn-xs" value="Validate" onclick="javascript:validateList('+list_id+',\'type_select\')" /></td><td>'+this.typesHtmlSelect(list_id, 'type_select', list_type)+'</td></tr>';
	html += '<tr><td>Add New Items:<br/><button class="btn btn-primary btn-xs" type="button" id="dialog_add_list_item_button" value="Add">Add</button></td><td><textarea id="dialog_add_list_item" type="text" class="form-control" placeholder="Add Item To List" /></textarea></td></tr></table>';

	html += '<table id="list_item_dialog_datatable" class="table table-condensed table-hover table-bordered"><thead style="display: none;"><tr><th><b>List items</b> ('+items.length+')</th><th>&nbsp;</th></tr></thead><tbody>';

	for(var n=0; n<items.length; n++) { 
	    html = html +'<tr><td>'+ items[n][1] + '</td><td><input id="'+items[n][0]+'" type="button" class="btn btn-default btn-xs" value="Remove" /></td></tr>';
	}
	html += '</tbody></table>';
	
	jQuery('#'+div+'_div').html(html);

	jQuery('#list_item_dialog_datatable').DataTable({
	    destroy: true,
	    scrollY:        '30vh',
            scrollCollapse: true,
            paging:         false,
	});

	for (var n=0; n<items.length; n++) { 
	    var list_item_id = items[n][0];

	    jQuery('#'+items[n][0]).click(
		function() { 
		    var lo = new CXGN.List();
		    var i = lo.availableLists();
		    
		    lo.removeItem(list_id, this.id );
		    lo.renderItems(div, list_id);
		    lo.renderLists('list_dialog');
		});
	}
	
	jQuery('#dialog_add_list_item_button').click(
	    function() { 
                jQuery('#working_modal').modal("show");
		addMultipleItemsToList('dialog_add_list_item', list_id);
		var lo = new CXGN.List();
		lo.renderItems(div, list_id);
		jQuery('#working_modal').modal("hide");
	    }
	);
	
	jQuery('#updateNameButton').click(
	    function() { 
		var lo = new CXGN.List();
		var new_name =  jQuery('#updateNameField').val();
		var list_id = jQuery('#list_id_div').html();
		lo.updateName(list_id, new_name);
		alert("Changed name to "+new_name+" for list id "+list_id);
	    }
	);
    },
    
    renderPublicItems: function(div, list_id) { 
	var list_data = this.getListData(list_id);
	var items = list_data.elements;
	var list_type = list_data.type_name;
	var list_name = this.publicListNameById(list_id);
	
	var html = '';
	html += '<table class="table"><tr><td>List ID</td><td id="list_id_div">'+list_id+'</td></tr>';
	html += '<tr><td>List name:</td>';
	html += '<td>'+list_name+'</td></tr>';
	html += '<tr><td>Type:</td><td>'+list_type+'</td></tr>';
	html += '</table>';
	html += '<table id="public_list_item_dialog_datatable" class="table table-condensed table-hover table-bordered"><thead style="display: none;"><tr><th><b>List items</b> ('+items.length+')</th></tr></thead><tbody>';
	for(var n=0; n<items.length; n++) { 
	    html = html +'<tr><td>'+ items[n][1] + '</td></tr>';
	}
	html += '</tbody></table>';
	
	jQuery('#'+div+'_div').html(html);

	jQuery('#public_list_item_dialog_datatable').DataTable({
	    destroy: true,
	    scrollY:        '30vh',
            scrollCollapse: true,
            paging:         false,
	});
    },

    existsList: function(name) { 
	var list_id = 0;
	jQuery.ajax( { 
	    url: '/list/exists',
	    async: false,
	    data: { 'name': name },
	    success: function(response) { 
		list_id = response.list_id;
	    }
	});
	return list_id;
    },

    existsItem: function(list_id, name) { 
	var list_item_id =0;
	jQuery.ajax( { 
	    url: '/list/exists_item',
	    async: false,
	    data: { 'list_id' : list_id, 'name':name },
	    success: function(response) { 
		list_item_id = response.list_item_id;
	    }
	});
	return list_item_id;
    },
    
    addToList: function(list_id, text) { 
	if (! text) { 
	    return;
	}
	var list = text.split("\n");
	var duplicates = [];
	
	var info = this.addBulk(list_id, list);
	
	return info;
	
    },

    /* listSelect: Creates an html select with lists of requested types.
 
       Parameters: 
         div_name: The div_name where the select should appear
         types: a list of list types that should be listed in the menu
         add_empty_element: text. if present, add an empty element with the
           provided text as description
    */
    
    listSelect: function(div_name, types, empty_element) { 	
	var lists = new Array();

	if (types) {
	    for (var n=0; n<types.length; n++) { 
		var more = this.availableLists(types[n]);
		if (more) { 
		    for (var i=0; i<more.length; i++) { 
			lists.push(more[i]);
		    }
		}
	    }
	}
	else { 
	    lists = this.availableLists();
	}

	var html = '<select class="form-control input-sm" id="'+div_name+'_list_select" name="'+div_name+'_list_select" >';
	if (empty_element) { 
	    html += '<option value="">'+empty_element+'</option>\n';
        } 
	for (var n=0; n<lists.length; n++) {
	    html += '<option value='+lists[n][0]+'>'+lists[n][1]+'</option>';
	}
	html = html + '</select>';
	return html;
    },

    updateName: function(list_id, new_name) { 
	jQuery.ajax( { 
	    url: '/list/name/update',
	    async: false,
	    data: { 'name' : new_name, 'list_id' : list_id },
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		    return;
		}
		else { 
		    alert("The name of the list was changed to "+new_name);
		}
	    },
	    error: function(response) { alert("An error occurred."); }
	});
	this.renderLists('list_dialog');
    },

    validate: function(list_id, type, non_interactive) { 
	var missing = new Array();
	var error = 0;
	jQuery.ajax( { 
	    url: '/list/validate/'+list_id+'/'+type,
	    async: false,
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		else { 
		    missing = response.missing;
		}
	    },
	    error: function(response) { alert("An error occurred while validating the list "+list_id); error=1; }
	});

	if (error === 1 ) { return; }

	if (missing.length==0) { 
	    if (!non_interactive) { alert("This list passed validation."); } 
	    return 1;
	}
	else { 
	    alert("List validation failed. Elements not found: "+ missing.join(","));
	    return 0;
	}
    },

    transform: function(list_id, transform_name) { 
	var transformed = new CXGN.List();
	jQuery.ajax( { 
	    url: '/list/transform/'+list_id+'/'+transform_name,
	    async: false,
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		else { 
		    transformed = response.transform;
		}
	    },
	    error: function(response) { alert("An error occurred while validating the list "+list_id); }
	});
    },

    transform2Ids: function(list_id) { 
	var list_type = this.getListType(list_id);
	var new_type;
	if (list_type == 'traits') { new_type = 'trait_ids'; }
	if (list_type == 'locations') { new_type = 'location_ids'; }
	if (list_type == 'trials') { new_type = 'project_ids'; }
	if (list_type == 'projects') { new_type = 'project_ids'; }
	if (list_type == 'plots') { new_type = 'plot_ids'; }
	if (list_type == 'accessions') { new_type = 'accession_ids'; }
	
	if (! new_type) { 
	    return { 'error' : "cannot convert the list because of unknown type" };
	}

	var transformed = this.transform(list_id, new_type);
	
	return { 'transformed' : transformed };
	    

    }
};

function setUpLists() {  
    jQuery("button[name='lists_link']").click(
	function() { show_lists(); }
    );
}


function show_lists() {     
    jQuery('#list_dialog').modal("show");
    
    var l = new CXGN.List();
    l.renderLists('list_dialog');
}

/* deprecated */
function pasteListMenu (div_name, menu_div, button_name) { 
    var lo = new CXGN.List();

    var html='';

    if (button_name === undefined) { 
	button_name = 'paste';
    }

    html = lo.listSelect(div_name);
    html = html + '<button class="btn btn-info btn-sm" type="button" value="'+button_name+'" onclick="javascript:pasteList(\''+div_name+'\')" >'+button_name+'</button>';
    
    jQuery('#'+menu_div).html(html);
}

function pasteList(div_name) { 
    var lo = new CXGN.List();
    var list_name = jQuery('#'+div_name+'_list_select').val();
    var list_content = lo.getList(list_name);
    
    // textify list
    var list_text = '';
    for (var n=0; n<list_content.length; n++) { 
	list_text = list_text + list_content[n][1]+"\r\n";
    }
    jQuery('#'+div_name).text(list_text);
}

/*
  addToListMenu

  Parameters: 
  * listMenuDiv - the name of the div where the menu will be displayed
  * dataDiv - the div from which the data will be copied (can be a div, textarea, or html select
  * options - optional hash with the following keys:
    - selectText: if the dataDiv is an html select and selectText is true, the text and not the value will be copied into the list
    - listType: the type of lists to display in the menu
    - typesSourceDiv: obtain the type from this source div


*/

function addToListMenu(listMenuDiv, dataDiv, options) { 
    var lo = new CXGN.List();

    var html;
    var selectText;
    var listType;
    var typeSourceDiv; 
    var type; 

    if (options) { 
	if (options.selectText) { 
	    selectText = options.selectText;
	}
	if (options.typeSourceDiv) { 
	    var sourcetype = getData(options.typeSourceDiv, selectText);
	    if (sourcetype) { 
		type = sourcetype.replace(/(\n|\r)+$/, '');
	    }
	}
	if (options.listType) { 
	    type = options.listType;
	}
    }
    html = '<div class="row"><div class="col-sm-6" style="margin-right:0px; padding-right:0px;"><input class="form-control input-sm" type="text" id="'+dataDiv+'_new_list_name" placeholder="New list..." />';
    html += '</div><div class="col-sm-6" style="margin-left:0px; padding-left:0px; margin-right:0px; padding-right:0px;"><input type="hidden" id="'+dataDiv+'_list_type" value="'+type+'" />';
    html += '<input class="btn btn-primary btn-sm" id="'+dataDiv+'_add_to_new_list" type="button" value="add to new list" /></div></div><br />';

    html += '<div class="row"><div class="col-sm-6" style="margin-right:0px; padding-right:0px;">'+lo.listSelect(dataDiv, [ type ]);

    html += '</div><div class="col-sm-6" style="margin-left:0px; padding-left:0px; margin-right:0px; padding-right:0px;"><input class="btn btn-primary btn-sm" id="'+dataDiv+'_button" type="button" value="add to list" /></div></div>';
   
    jQuery('#'+listMenuDiv).html(html);

    var list_id = 0;

    jQuery('#'+dataDiv+'_add_to_new_list').click(
	function() { 
	    var lo = new CXGN.List();
	    var new_name = jQuery('#'+dataDiv+'_new_list_name').val();
	    var type = jQuery('#'+dataDiv+'_list_type').val();
	    	    
	    var data = getData(dataDiv, selectText);
	    
	    list_id = lo.newList(new_name);
	    if (list_id > 0) { 
		var elementsAdded = lo.addToList(list_id, data);
		if (type) { lo.setListType(list_id, type); }
		alert("Added "+elementsAdded+" list elements to list "+new_name+" and set type to "+type);
	    }
	}
    );
	
    jQuery('#'+dataDiv+'_button').click( 
	function() { 
	    var data = getData(dataDiv, selectText);
	    list_id = jQuery('#'+dataDiv+'_list_select').val();
	    var lo = new CXGN.List();
	    var elementsAdded = lo.addToList(list_id, data);

	    alert("Added "+elementsAdded+" list elements");
	    return list_id;
	}
    );
    

   
}

function getData(id, selectText) { 
    var divType = jQuery("#"+id).get(0).tagName;
    var data; 
    
    if (divType == 'DIV' || divType =='SPAN' || divType === undefined) { 
	data = jQuery('#'+id).html();
    }
    if (divType == 'SELECT' && selectText) {
	if (jQuery.browser.msie) {
	    // Note: MS IE unfortunately removes all whitespace
            // in the jQuery().text() call. Program it out...
	    //
	    var selectbox = document.getElementById(id);
	    var datalist = new Array();
	    for (var n=0; n<selectbox.length; n++) { 
		if (selectbox.options[n].selected) { 
		    var x=selectbox.options[n].text;
		    datalist.push(x);
		}
	    }
	    data = datalist.join("\n");
	    //alert("data:"+data);
	    
	}
	else { 
	    data = jQuery('#'+id+" option:selected").text();
	}

    }
    if (divType == 'SELECT' && ! selectText) { 
	var return_data = jQuery('#'+id).val();

	if (return_data instanceof Array) { 
	    data = return_data.join("\n");
        }
	else { 
	    data = return_data;
	}
    }
    if (divType == 'TEXTAREA') { 
	data = jQuery('textarea#'+id).val();
    }
    return data;
}
  

/* deprecated */         
function addTextToListMenu(div) { 
    var lo = new CXGN.List();
    var html = lo.listSelect(div);
    html = html + '<input id="'+div+'_button" type="button" value="add to list" />';
    
    document.write(html);
    
    jQuery('#'+div+'_button').click( 
	function() { 
	    var text = jQuery('textarea#div').val();
	    var list_id = jQuery('#'+div+'_list_select').val();
	    lo.addToList(list_id, text);
	    lo.renderLists('list_dialog');
	}
    );
}

/* deprecated */
function addSelectToListMenu(div) { 
    var lo = new CXGN.List();
    var html = lo.listSelect(div);
    html = html + '<input id="'+div+'_button" type="button" value="add to list" />';
    
    document.write(html);
    
    jQuery('#'+div+'_button').click( 
	function() { 
	    var selected_items = jQuery('#'+div).val();
	    var list_id = jQuery('#'+div+'_list_select').val();
            addArrayToList(selected_items, list_id);
	    lo.renderLists('list_dialog');
	}
    );
}


/* deprecated */
// add the text in a div to a list
function addDivToList(div_name) { 
    var list_id = jQuery('#'+div_name+'_list_select').val();
    var lo = new CXGN.List();
    var list = jQuery('#'+div_name).val();
    var items = list.split("\n");

    for(var n=0; n<items.length; n++) { 
	var added = lo.addItem(list_id, items[n]);
	if (added > 0) { }
    }
}

/* deprecated */
function addTextToList(div, list_id) { 
    var lo = new CXGN.List();
    var item = jQuery('#'+div).val();
    var id = lo.addItem(list_id, item);
    if (id == 0) { 
	alert('Item "'+item+'" was not added because it already exists');
    }
    lo.renderLists('list_dialog');
}

/* deprecated */
function addMultipleItemsToList(div, list_id) { 
    var lo = new CXGN.List();
    var content = jQuery('#'+div).val();
    if (content == '') { 
	alert("No items - Please enter items to add to the list.");
return;
    }
//    var items = content.split("\n");
    
  //  var duplicates = new Array();
    var items = content.split("\n");
    lo.addBulk(list_id, items);
   // for (var n=0; n<items.length; n++) { 
//	var id = lo.addItem(list_id, items[n]);
//	if (id == 0) { 
//	    duplicates.push(items[n]);
//	}
  //  }
    //if (duplicates.length >0) { 
//	alert("The following items were not added because they are already in the list: "+ duplicates.join(", "));
  //  }
lo.renderLists('list_dialog');
}

/* deprecated */
function addArrayToList(items, list_id) { 
var lo = new CXGN.List();
   var duplicates = new Array();
    for (var n=0; n<items.length; n++) { 
	var id = lo.addItem(list_id, items[n]);
	if (id == 0) { 
	    duplicates.push(items[n]);
	}
    }
    if (duplicates.length >0) { 
	alert("The following items were not added because they are already in the list: "+ duplicates.join(", "));
    }
}

function deleteList(list_id) { 
    var lo = new CXGN.List();
    var list_name = lo.listNameById(list_id);
    if (confirm('Delete list "'+list_name+'"? (ID='+list_id+'). This cannot be undone.')) { 
	lo.deleteList(list_id);
	lo.renderLists('list_dialog');
	alert('Deleted list '+list_name);
    }
}

function togglePublicList(list_id) { 
    $.ajax({
	"url": "/list/public/toggle",
	"type": "POST",
	"data": {'list_id': list_id},
	success: function(r) {
	    var lo = new CXGN.List();
	    if (r.error) {
		alert(r.error);
	    } else if (r.r == 1) {
		alert("List set to Private");
	    } else if (r.r == 0) {
		alert("List set to Public");
	    }
	    lo.renderLists('list_dialog');
	},
	error: function() {
	    alert("Error Setting List to Public! List May Not Exist.");
	}
    });
    var lo = new CXGN.List();
    lo.renderLists('list_dialog');
}

function copyPublicList(list_id) { 
    $.ajax({
	"url": "/list/public/copy",
	"type": "POST",
	"data": {'list_id': list_id},
	success: function(r) {
	    if (r.error) {
		alert(r.error);
	    } else if (r.success == 'true') {
		alert("Public List Copied to Your Lists.");
	    }
	},
	error: function() {
	    alert("Error Copying Public List! List May Not Exist.");
	}
    });
    var lo = new CXGN.List();
    lo.renderLists('list_dialog');
}
	
function deleteItemLink(list_item_id) { 
    var lo = new CXGN.List();
    lo.deleteItem(list_item_id);
    lo.renderLists('list_dialog');
}
	
function showListItems(div, list_id) { 
    var l = new CXGN.List();
    jQuery('#'+div).modal("show");
    l.renderItems(div, list_id);
}

function showPublicListItems(div, list_id) { 
    var l = new CXGN.List();
    jQuery('#'+div).modal("show");
    l.renderPublicItems(div, list_id);
}

function addNewList(div_id) { 
    var lo = new CXGN.List();
    var name = jQuery('#'+div_id).val();
    
    if (name == '') { 
	alert("Please specify a name for the list.");
	return;
    }
    
    var list_id = lo.existsList(name);
    if (list_id > 0) {
	alert('The list '+name+' already exists. Please choose another name.');
	return;
    }
    lo.newList(name);
    lo.renderLists('list_item_dialog');
}

function changeListType(html_select_id, list_id) { 
    var type = jQuery('#'+html_select_id).val();
    var l = new CXGN.List();
    l.setListType(list_id, type);
    l.renderLists('list_dialog');
}

/* 
   validateList - check if all the elements in a list are of the correct type

   Parameters: 
   * list_id: the id of the list
   * html_select_id: the id of the html select containing the type list
   
*/

function validateList(list_id, html_select_id) { 
    var lo = new CXGN.List();
    var type = jQuery('#'+html_select_id).val();
    lo.validate(list_id, type);
}

function deleteSelectedListGroup(list_ids) {
    var arrayLength = list_ids.length;
    if (confirm('Delete the selected lists? This cannot be undone.')) {
	for (var i=0; i<arrayLength; i++) {
	    var lo = new CXGN.List();
	    lo.deleteList(list_ids[i]);
	}
	lo.renderLists('list_dialog');
    }
}
