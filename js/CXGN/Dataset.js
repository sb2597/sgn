
if (!CXGN) CXGN = function () { };

CXGN.Dataset = function () {
    this.dataset = [];
};


CXGN.Dataset.prototype = {
    
    // return info on all available datasets
    getDatasets: function() { 
	var datasets;
	jQuery.ajax( { 
	    'url' : '/ajax/dataset/by_user',
	    'async': false,
	    'success': function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		else { 
		    datasets = response.datasets;
		}
	    },
            'error': function(response) { 
		alert('An error occurred. Please try again.');
	    }
	});	
	return datasets;
    },

    getDataset: function(id) { 
	var dataset;
	jQuery.ajax( { 
	    'url' : '/ajax/dataset/get/'+id,
	    'async': false,
	    'success': function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		else { 
		    dataset = response.dataset;
		}
	    },
	    'error': function(response) { 
		alert('An error occurred. The specified dataset may not exist. Please try again.');
	    }
	});
	return dataset;
	
    },

    deleteDataset: function(id) { 
	
    },

    renderDatasets: function(div) {
	var datasets = this.getDatasets();
	var html = '';

	if (!datasets || datasets.length===0) {
	    html = html + "None";
	    jQuery('#'+div+'_div').html(html);
	    return;
	}

	html += '<table class="table table-hover table-condensed">';
	html += '<thead><tr><th>Dataset Name</th><th>Description</th><th colspan="4">Actions</th></tr></thead><tbody><tr>';
	for (var i = 0; i < datasets.length; i++) {
	    html += '<td><b>'+datasets[i][1]+'</b></td>';
	    html += '<td>'+datasets[i][2]+'</td>';
	    html += '<td><a title="View" id="view_dataset_'+datasets[i][1]+'" href="javascript:showDatasetItems(\'dataset_item_dialog\','+datasets[i][0]+')"><span class="glyphicon glyphicon-th-list"></span></a></td>';
	    html += '<td><a title="Delete" id="delete_dataset_'+datasets[i][1]+'" href="javascript:deleteDataset('+datasets[i][0]+')"><span class="glyphicon glyphicon-remove"></span></a></td></tr>';
	}
	html = html + '</tbody></table>';
	html += '<div id="list_group_select_action"></div>';

	jQuery('#'+div+'_div').html(html);
    },

    renderItems: function(div, dataset_id) { 
	var dataset = this.getDataset(dataset_id);

	var html = '';
	for(var key in dataset.categories) {
	    if (dataset.categories.hasOwnProperty(key)) { 
		if (dataset.categories[key]===null || dataset.categories[key].length===0) { 
		    // do nothing?
		}
		else { 
		    html += '<b>'+key+'</b>'+JSON.stringify(dataset.categories[key])+"<br />";
		}
	    }
	}
	jQuery('#'+div+'_div').html(html);
    }
}


function setUpDatasets() {
    jQuery("button[name='datasets_link']").click(
	function() { show_datasets(); }
    );
}

function show_datasets() {
    jQuery('#dataset_dialog').modal("show");
    var l = new CXGN.Dataset();
    l.renderDatasets('dataset_dialog');
}

function deleteDataset(dataset_id) { 
    var reply = confirm("Are you sure you want to delete the dataset with id "+dataset_id+"? Please note that deletion cannot be undone.");

    if (reply) { 
	jQuery.ajax( { 
	    'url' : '/ajax/dataset/delete/'+dataset_id,
	    'success': function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		else { 
		    alert('Successfully deleted dataset with id '+dataset_id);
		}
	    },
	    'error': function(response) { 
		alert('A processing error occurred.');
	    }
	})
    }

}

function showDatasetItems(div, dataset_id) { 

    working_modal_show();

    var d = new CXGN.Dataset();    
    d.renderItems(div, dataset_id);
    jQuery('#'+div).modal("show");
    
    working_modal_hide();
}
