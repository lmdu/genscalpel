#!/usr/bin/perl
use strict;
use Tkx;
use Cwd;
use File::Basename;
use File::Find;
use File::Copy;
use Encode;
use Encode::CN;
use LWP::UserAgent;
use ActiveState::Browser;
use SQLiteDB;
Tkx::lappend('::auto_path', 'lib');

# require other needed packages of Tkx
Tkx::package_require('widget::dialog');
Tkx::package_require('img::png');
Tkx::package_require('img::ico');
Tkx::package_require('img::gif');
Tkx::package_require('widget::statusbar');
Tkx::package_require('widget::toolbar');
Tkx::package_require('tooltip');
Tkx::package_require('tkdnd');
Tkx::namespace_import("::tooltip::tooltip");
Tkx::option_add("*TEntry.cursor", "xterm");

my %wgt; # store information of created widget
my %par; # a list of parameters for program

# initialization
$par{msg} = "Welcome to GenScalpel!";
$par{type} = "dna"; #type of sequence get from data file, Protein or DNA sequence
$par{merge} = 0; #merge multiple fasta sequence.

my %file_info; #store information of genbank file
my %feat_info; #store information of features of genban file

my $is_linux = Tkx::tk_windowingsystem() eq 'x11' ? 1 : 0;

# create main windows and configure the parameters
my $mw = Tkx::widget->new(".");
$mw->g_wm_title("GenScalpel v1.0");
$mw->g_wm_geometry("800x600");
if($is_linux){
	Tkx::wm_iconphoto($mw, "-default", Tkx::image_create_photo(-file => 'genscalpel.ico'));
}else{
	$mw->g_wm_iconbitmap(-default => "genscalpel.ico");
}
$mw->g_wm_protocol('WM_DELETE_WINDOW', sub{on_exit()});


# create menu
Tkx::option_add("*tearOff", 0);
my $menu = $mw->new_menu;
$mw->configure(-menu => $menu);
my $m_file = $menu->new_menu;
my $m_edit = $menu->new_menu;
my $m_tool = $menu->new_menu;
my $m_lang = $menu->new_menu;
my $m_help = $menu->new_menu;

#create menu label
$menu->add_cascade(
	-menu => $m_file, 
	-label => "File(F)", 
	-underline => 5
);
$menu->add_cascade(
	-menu => $m_edit, 
	-label => "Edit(E)", 
	-underline => 5
);
$menu->add_cascade(
	-menu => $m_tool, 
	-label => "Tool(T)", 
	-underline => 5
);
$menu->add_cascade(
	-menu => $m_help, 
	-label => "Help(H)", 
	-underline => 5
);

#create menu command for label File
$m_file->add_command(
	-label => "Open File", 
	-command => sub {open_file()}
);
$m_file->add_command(
	-label => "Get NCBI Data",  
	-command => sub {create_dl_win()}
);
$m_file->add_separator;
$m_file->add_command(
	-label => "Save As",
	-command => sub {save_as()}
);
$m_file->add_separator;
$m_file->add_command(
	-label => "Exit", 
	-command => sub {on_exit()}
);

#create menu command for label Edit
$m_edit->add_command(
	-label => "Undo",
	-command => sub{un_do()}
);
$m_edit->add_command(
	-label => "Redo",
	-command => sub{re_do()}
);
$m_edit->add_separator;
$m_edit->add_command(
	-label => "Paste", 
	-command => sub{paste()}
);
$m_edit->add_command(
	-label => "Clear", 
	-command => sub{clear()}
);

#create menu command for label Tool
$m_tool->add_command(
	-label => "Switch to Batch", 
	-command => sub{switch_to_batch()}
);
$m_tool->add_separator;
$m_tool->add_command(
	-label => "Convert to Fasta", 
	-command => sub{convert_to_fasta()}
);
$m_tool->add_command(
	-label => "Search Sequence", 
	-command => sub{create_search_win()}
);
$m_tool->add_separator;
$m_tool->add_command(
	-label => "Highlight Features",
	-command => sub{add_bind_tags()},
);
$m_tool->add_command(
	-label => "Cancel Highlight",
	-command => sub{cancel_bind_tags()},
);

#create menu command for label Help
$m_help->add_command(
	-label => "Help Contents", 
	-command => sub {
		ActiveState::Browser::open("readme.html")
	}
);
$m_help->add_command(
	-label => "GenScalpel Homepage",
	-command => sub{
		ActiveState::Browser::open("http://genscalpel.biosv.com");
	}
);
$m_help->add_command(
	-label => "Online Version",
	-command => sub{
		ActiveState::Browser::open("http://genscalpel.biosv.com/online.php");
	}
);
$m_help->add_separator;
$m_help->add_command(
	-label => "NCBI Homepage", 
	-command => sub {
		ActiveState::Browser::open("http://www.ncbi.nlm.nih.gov")
	}
);
$m_help->add_separator;
$m_help->add_command(
	-label => "About GenScalpel", 
	-command => sub {
		Tkx::tk___messageBox(
			-parent => $mw,
			-title => "About \uGenScalpel",
			-type => "ok",
			-icon => "info",
			-message => "GenScalpel v1.0\n".
						"Copyright 2011 GenScalpel. ".
						"All rights reserved.",
		);
	}
);

#create toolbar
$wgt{'toolbar'} = $mw->new_widget__toolbar(
);
$wgt{'toolbar'}->g_grid(
	-padx => 2,
	-sticky => "ew"
);
my $ico_open = $wgt{'toolbar'}->new_ttk__button(
	-text => "open file", 
	-style => "Toolbutton", 
	-compound => "image",
	-width => 0, 
	-command => sub{open_file()}, 
	-image => Tkx::image_create_photo(
		-file => 'icons/addfile.png'
	),
);
$wgt{toolbar}->add($ico_open, -pad => [0,2]);
$ico_open->g_tooltip("Open File");
my $ico_dl = $wgt{'toolbar'}->new_ttk__button(
	-text => "download", 
	-style => "Toolbutton", 
	-compound => "image",
	-width => 0, 
	-command => sub{create_dl_win()}, 
	-image => Tkx::image_create_photo(
		-file => 'icons/down.png'
	),
);
$wgt{toolbar}->add($ico_dl, -pad => [0, 2]);
$ico_dl->g_tooltip("Get NCBI Data");
my $ico_pt = $wgt{'toolbar'}->new_ttk__button(
	-text => "Paste", 
	-style => "Toolbutton", 
	-compound => "image",
	-width => 0, 
	-command => sub{paste();}, 
	-image => Tkx::image_create_photo(
		-file => 'icons/paste.png'
	),
);
$wgt{toolbar}->add($ico_pt, -pad => [0, 2]);
$ico_pt->g_tooltip("Paste");
my $ico_bp = $wgt{'toolbar'}->new_ttk__button(
	-style => "Toolbutton", 
	-compound => "image",
	-width => 0, 
	-command => sub{switch_to_batch()}, 
	-image => Tkx::image_create_photo(
		-file => 'icons/addfiles.png'
	),
);
$wgt{toolbar}->add($ico_bp, -pad => [0, 2]);
$ico_bp->g_tooltip("Switch to Batch");
my $ico_ws = $wgt{'toolbar'}->new_ttk__button(
	-style => "Toolbutton", 
	-compound => "image",
	-width => 0, 
	-command => sub{convert_to_fasta()}, 
	-image => Tkx::image_create_photo(
		-file => 'icons/seq.png'
	),
);
$wgt{toolbar}->add($ico_ws, -pad => [0, 2]);
$ico_ws->g_tooltip("Convert to Fasta");
my $ico_gene = $wgt{'toolbar'}->new_ttk__button(
	-style => "Toolbutton", 
	-compound => "image",
	-width => 0, 
	-command => sub{
		create_search_win();
	}, 
	-image => Tkx::image_create_photo(
		-file => 'icons/gene.png'
	),
);
$wgt{toolbar}->add($ico_gene, -pad => [0, 2]);
$ico_gene->g_tooltip("Search Sequence");
my $ico_light = $wgt{'toolbar'}->new_ttk__button(
	-style => "Toolbutton", 
	-compound => "image",
	-width => 0, 
	-command => sub{add_bind_tags()}, 
	-image => Tkx::image_create_photo(
		-file => 'icons/high_add.png'
	),
);
$wgt{toolbar}->add($ico_light, -pad => [0, 2]);
$ico_light->g_tooltip("Highlight Features");
my $ico_high = $wgt{'toolbar'}->new_ttk__button(
	-style => "Toolbutton", 
	-compound => "image",
	-width => 0, 
	-command => sub{cancel_bind_tags()}, 
	-image => Tkx::image_create_photo(
		-file => 'icons/high_del.png'
	),
);
$wgt{toolbar}->add($ico_high, -pad => [0, 2]);
$ico_high->g_tooltip("Cancel Highlight");
my $ico_help = $wgt{'toolbar'}->new_ttk__button(
	-style => "Toolbutton", 
	-compound => "image",
	-width => 0, 
	-command => sub{ActiveState::Browser::open("readme.html")}, 
	-image => Tkx::image_create_photo(
		-file => 'icons/help.png'
	),
);
$wgt{toolbar}->add($ico_help, -pad => [0, 2]);
$ico_help->g_tooltip("View Help");
my $ico_exit = $wgt{'toolbar'}->new_ttk__button(
	-style => "Toolbutton", 
	-compound => "image",
	-width => 0, 
	-command => sub{on_exit()}, 
	-image => Tkx::image_create_photo(
		-file => 'icons/exit.png'
	),
);
$wgt{toolbar}->add($ico_exit, -pad => [0, 2]);
$ico_exit->g_tooltip("Exit");

#create combobx and button on toolbar
my $feat_frame = $wgt{toolbar}->new_ttk__frame();
$wgt{toolbar}->add($feat_frame, -weight => 1);
$feat_frame->g_grid_columnconfigure(0, -weight => 1);

$wgt{gb_combo} = $feat_frame->new_ttk__combobox(
	-textvariable => \$par{genbank},
	-values => ['No File'],
	-width => 15,
	-state => 'readonly',
);
$wgt{gb_combo}->g_grid(
	-column => 0,
	-row => 0,
	-sticky => "e",
);
$wgt{gb_combo}->current(0);
$wgt{gb_combo}->g_bind("<<ComboboxSelected>>", sub{onchange_gb_combo()});

$wgt{feat_combo} = $feat_frame->new_ttk__combobox(
	-textvariable => \$par{feature},
	-values => ['No Feature'], 
	-width => 15,
	-state => "readonly",
);
$wgt{feat_combo}->current(0);
$wgt{feat_combo}->g_grid(
	-sticky => "e",
	-column => 1,
	-row => 0,
);
$wgt{feat_combo}->g_bind("<<ComboboxSelected>>", sub{onchange_feat_combo()});

$wgt{info_combo} = $feat_frame->new_ttk__combobox(
	-textvariable => \$par{feat_content},
	-values => ['No Key'], 
	-width => 20,
	-state => "readonly",
);
$wgt{info_combo}->current(0);
$wgt{info_combo}->g_grid(
	-sticky => "e",
	-column => 2,
	-row => 0,
);

#$wgt{protein} = $feat_frame->new_ttk__checkbutton(
#	-text => "Protein",
#	-state => "disabled",
#	-offvalue => "dna",
#	-onvalue => "protein",
#	-variable => \$par{type},
#	-command => sub{select_op_seq_type()}
#);
#$wgt{protein}->g_grid(
#	-column => 3,
#	-row => 0,
#	-padx => 5,
#	-sticky => "e",
#);
$feat_frame->new_ttk__button(
	-text => "Get Sequence",
	-width => 0,
	-command => sub{get_total_seq()},
)->g_grid(
	-sticky => "e",
	-row => 0,
	-column => 4,
);
#create main content frame
$wgt{frame}=$mw->new_ttk__frame(
	-borderwidth => 1,
	-relief => "groove",
);
$wgt{frame}->g_grid(-sticky => "wnes");

#create font
Tkx::font_create("TxtFont", -family => 'Bitstream Vera Sans Mono', -size => 10);

#create text widget
$wgt{text} = $wgt{frame}->new_tk__text(
	-padx => 3,
	-pady => 3,
	-width => 0, 
	-height => 0,
	-undo => 1,
	-font => 'TxtFont',
	-relief => "flat",
	-state => "disabled",
);
$wgt{text}->g_grid(
	-column => 0, 
	-row => 0, 
	-sticky => "wens",
);
$wgt{text}->g_bind("<<Modified>>", 
	sub{
		parse_gb_file();
	}
);

#drag file
Tkx::tkdnd__drop___target_register($wgt{text},'*');
Tkx::bind($wgt{text}, '<<Drop:DND_Files>>', [sub{drag_file(shift);}, Tkx::Ev('%D')]);

$wgt{scroll} = $wgt{frame}->new_ttk__scrollbar(
	-command => [$wgt{text}, "yview"], 
	-orient => "vertical",
);
$wgt{scroll}->g_grid(
	-column => 1, 
	-row => 0, 
	-sticky => "ns",
);
$wgt{text}->configure(-yscrollcommand => [$wgt{scroll}, "set"]);
$wgt{frame}->g_grid_columnconfigure(0, -weight => 1);
$wgt{frame}->g_grid_rowconfigure(0, -weight => 1);
$mw->g_grid_rowconfigure(1, -weight => 1);
$mw->g_grid_columnconfigure(0, -weight => 1);

#create statusbar
$wgt{statusbar}=$mw->new_widget__statusbar(-ipad => [1, 2]);
$wgt{statusbar}->g_grid(-sticky => "we");

#create statusbar message label
my $w_msg = $wgt{statusbar}->new_ttk__label(
	-textvariable => \$par{msg},
	-anchor => "w",
);
$wgt{statusbar}->add($w_msg, -weight => 1);


Tkx::MainLoop;

###############################################################
# GUI functions
###############################################################

# create save sequence windows
sub create_save_win{
	$par{save} = shift; # get the saving sequence.
	my $outname = shift; #output file name.
	# create window
	my $sw = $mw->new_toplevel;
	$sw->g_wm_title("Save Sequence");
	$sw->g_wm_geometry("650x480");
	$sw->g_wm_attributes(-topmost => 1);
	$sw->g_wm_protocol('WM_DELETE_WINDOW',sub{$par{merge} = 0;$sw->g_destroy;});
	my $sf = $sw->new_ttk__frame(
		-relief => "groove",
	);
	$sf->g_grid(
		-sticky => "wnes",
	);
	my $stext = $sf->new_tk__text(	
		-padx => 3,
		-pady => 3,
		-width => 0, 
		-height => 0,
		-undo => 1,
		-font => 'TxtFont',
		-relief => "flat",
		-state => "disabled",
		-exportselection => 1,
	);
	$stext->g_grid(
		-sticky => "wens",
		-column => 0,
		-row => 0,
	);
	my $scroll = $sf->new_ttk__scrollbar(
		-command => [$stext, "yview"], 
		-orient => "vertical"
	);
	$scroll->g_grid(
		-column => 1, 
		-row => 0, 
		-sticky => "ns",
	);
	$stext->configure(-yscrollcommand => [$scroll, "set"]);
	$sw->g_grid_rowconfigure(0, -weight => 1);
	$sw->g_grid_columnconfigure(0, -weight => 1);
	$sf->g_grid_rowconfigure(0, -weight => 1);
	$sf->g_grid_columnconfigure(0, -weight => 1);
	
	#create statusbar
	my $bn_fm = $sw->new_widget__statusbar(-ipad => [1, 2]);
	$bn_fm->g_grid(-sticky => "we");
	$bn_fm->add($bn_fm->new_ttk__frame(), -weight => 1);
	
	my $editable = 0;
	$par{merge} = 0;
	my $undo_bn;
	my $redo_bn;
	my $merg_bn;
	
	my $edit_bn = $bn_fm->new_ttk__checkbutton(
		-text => "Editable",
		-image => Tkx::image_create_photo(
			-file => "icons/editable.png"
		),
		-compound => "left",
		-width => 0,
		-onvalue => 1,
		-offvalue => 0,
		-variable => \$editable,
		-command => sub{
			if($editable){
				$stext->configure(-state => "normal");
				$redo_bn->configure(-state => "normal");
				$undo_bn->configure(-state => "normal");
				$merg_bn->configure(-state => "normal");
			}else{
				$stext->configure(-state => "disabled");
				$redo_bn->configure(-state => "disabled");
				$undo_bn->configure(-state => "disabled");
				$merg_bn->configure(-state => "disabled");
			}
		}
	);
	$bn_fm->add($edit_bn);
	$merg_bn = $bn_fm->new_ttk__checkbutton(
		-text => "Merge Sequence",
		-image => Tkx::image_create_photo(
			-file => "icons/merge.png"
		),
		-compound => "left",
		-state => "disabled",
		-width => 0,
		-onvalue => 1,
		-offvalue => 0,
		-variable => \$par{merge},
		-command => sub{merge_seq($stext)},
	);
	$bn_fm->add($merg_bn);
	
	$redo_bn = $bn_fm->new_ttk__button(
		-text => "Redo",
		-image => Tkx::image_create_photo(
			-file => "icons/redo.png",
		),
		-compound => "left",
		-state => "disabled",
		-width => 0,
		-command => sub{
			Tkx::event_generate($stext, "<<Redo>>");
		}
	);
	$bn_fm->add($redo_bn);
	$undo_bn = $bn_fm->new_ttk__button(
		-text => "Undo",
		-image => Tkx::image_create_photo(
			-file => "icons/undo.png",
		),
		-compound => "left",
		-state => "disabled",
		-width => 0,
		-command => sub{
			Tkx::event_generate($stext, "<<Undo>>");
		}
	);
	$bn_fm->add($undo_bn);
	my $count_bn = $bn_fm->new_ttk__button(
		-text => "Count Characters",
		-command => sub{
			if($stext->tag_ranges('sel')){
				my $seq = $stext->get('sel.first', 'sel.last');
				$seq =~ s/\s//g;
				my $count = length($seq);
				Tkx::tk___messageBox(
					-parent => $sw,
					-title => "Number of characters",
					-message => "$count characters",
				);
			}else{
				Tkx::tk___messageBox(
					-parent => $sw,
					-title => "Error",
					-icon => "error",
					-message => "Please select characters",
				);
			}
		}
	);
	$bn_fm->add($count_bn);
	
	my $save_bn = $bn_fm->new_ttk__button(
		-text => "save sequence",
		-image => Tkx::image_create_photo(
			-file => "icons/save.png"
		),
		-compound => "left",
		-command => sub{save_seq($stext, $sw, $outname)},
	);
	$bn_fm->add($save_bn);
	
	insert_to_widget($stext, $par{save}); #insert saving sequence into text widget.
}

# create download sequence windows
sub create_dl_win{
    my $sw = $mw->new_toplevel;
	$sw->g_wm_title("Get NCBI Data");
	#$sw->g_wm_geometry("400x180");
	$sw->g_wm_attributes(-topmost => 1);
	my $sc = $sw->new_ttk__frame(-padding => 20);
    $sc->g_grid(-sticky => "wens");
    my $lh = $sc->new_ttk__label(-text => "Please Enter the Accession Number, Version or GI Number:");
    $lh->g_grid(-column => 0, -row => 0, -columnspan => 3, -pady =>"10 20", -sticky=> "w");
	my $acc; # accept the value of accession number
    my $en = $sc->new_ttk__entry(-textvariable => \$acc, -width=>60);
    $en->g_grid(-column => 0, -row => 1, -sticky=>"w");
    my $bn = $sc->new_ttk__button(
		-text => "Download", 
		-width => 0, 
		-command => sub{
			download_gb_file($acc, $sw);
		}
	);
    $bn->g_grid(-column => 1, -row => 1);
	$sw->g_bind("<Return>", sub{download_gb_file($acc, $sw)});
	my $cl = $sc->new_ttk__button(-text => "Clear", -width => 0, -command => sub{$acc="";});
	$cl->g_grid(-column => 2, -row => 1);
    $sc->new_ttk__label(-text=>"Example: NC_000857, NC_000857.1 or 5835876.")->g_grid(-column=>0, -row=>2, -columnspan=>3, -sticky=> "w", -pady=>10);
	$sc->new_ttk__label(
		-text=>"Note: Multiple search terms should be separated by a comma as follows:\nNC_001322,NC_001566,NC_002084"
	)->g_grid(
		-column => 0,
		-row => 3,
		-columnspan => 3,
		-sticky => 'w',
	);
}

# repeat function
sub tkx_repeat{
	my ($ms, $sub) = @_;
	my $repeater;
	$repeater = sub {
		$sub->(@_);
		Tkx::after($ms, $repeater);
	};
	my $repeat_id = Tkx::after($ms, $repeater);
	return $repeat_id;
}

# create search win
sub create_search_win{
	alert_info("Please Add GenBank File!") if $par{genbank} eq 'No File';
	
	my $DB = SQLiteDB->new(-database => 'database.db');
	if ($wgt{search} && Tkx::winfo_exists($wgt{search})) {
		$wgt{search}->display();
		my $ref = $DB->query_column("SELECT accession FROM gs_desc");
		$wgt{s_acc_combo}->configure(-values => $ref);
		$wgt{s_acc_combo}->current(0);
		onchange_s_acc_combo();
		return;
    }
	$wgt{search} = $mw->new_widget__dialog(
		-title => 'Search Sequence',
		-padding => 4,
		-parent => $mw,
        -place => 'over',
        -modal => 'none',
		-synchronous => 0,
        -separator => 0,
    );
	my $frame = $wgt{search}->new_ttk__frame(
		-padding => 12,
	);
	$frame->g_grid_columnconfigure(5, -weight => 1);
	$frame->g_grid_rowconfigure(1, -weight => 1);
	$frame->g_grid(-sticky => 'wnes');
	$wgt{search}->setwidget($frame);
	$wgt{search}->display();
	my $ref = $DB->query_column("SELECT accession FROM gs_desc");
	$frame->new_ttk__label(
		-text => 'Accession: ',
	)->g_grid(
		-column => 0,
		-row => 0,
		-sticky => 'e',
	);
	$wgt{s_acc_combo} = $frame->new_ttk__combobox(
		-textvariable => \$par{search_accession},
		-values => $ref,
		-width => 12,
	);
	$wgt{s_acc_combo}->g_grid(
		-column => 1,
		-row => 0,
		-sticky => 'w',
	);
	$wgt{s_acc_combo}->current(0);
	$wgt{s_acc_combo}->g_bind("<<ComboboxSelected>>", sub{onchange_s_acc_combo()});
	$ref = $DB->query_column("SELECT DISTINCT feat FROM gs_feat,gs_desc WHERE gs_desc.accession='$par{search_accession}' AND gs_desc.ID=gs_feat.GID");
	$frame->new_ttk__label(
		-text => 'Feature: ',
	)->g_grid(
		-column => 2,
		-row => 0,
		-sticky => 'e',
	);
	push @$ref, 'protein';
	$wgt{s_feat_combo} = $frame->new_ttk__combobox(
		-textvariable => \$par{search_feature},
		-values => $ref,
		-width => 14,
	);
	$wgt{s_feat_combo}->g_grid(
		-column => 3,
		-row => 0,
		-sticky => 'w',
	);
	$wgt{s_feat_combo}->current(0);
	$wgt{s_feat_combo}->g_bind("<<ComboboxSelected>>", sub{insert_to_list($par{search_annotation})});
	$frame->new_ttk__label(
		-text => 'Search: ',
	)->g_grid(
		-column => 4,
		-row => 0,
		-sticky => 'e',
	);
	$frame->new_ttk__entry(
		-textvariable => \$par{search_annotation},
		-validate => 'all',
		-validatecommand => [sub{Tkx::after(1000, [\&refresh_annot_list, shift]); return 1;}, Tkx::Ev('%P')],
		-width => 22,
	)->g_grid(
		-column => 5,
		-row => 0,
		-sticky => 'we',
	);
	my $al = $frame->new_ttk__labelframe(
		-text => 'Annotation List:',
		-padding => 3,
	);
	$al->g_grid(
		-column => 0,
		-row => 1,
		-columnspan => 6,
		-sticky => 'wnes',
		-pady => 10,
	);
	$al->g_grid_columnconfigure(0, -weight => 1);
	$al->g_grid_rowconfigure(0, -weight => 1);
	$wgt{list} = $al->new_ttk__treeview(
		-columns => "annot value",
		-show => 'headings',
		-selectmode => 'browse',
	);
	$wgt{list}->g_grid(
		-column => 0,
		-row => 0,
		-sticky => 'wnes',
	);
	$wgt{list}->column("annot", -width => 125, -anchor => "w", -stretch => 1);
    $wgt{list}->column("value", -width => 250, -stretch => 2);
	$wgt{list}->heading("annot", -text => 'Annotation Field');
	$wgt{list}->heading('value', -text => 'Annotation Information');
	
	 my $scrollbar = $al->new_ttk__scrollbar(-orient => 'vertical', -command => [$wgt{list}, 'yview']);
    $scrollbar->g_grid(-column => 1, -row => 0, -sticky => "ns");
    $wgt{list}->configure(-yscrollcommand => [$scrollbar, 'set']);
	
	$frame->new_ttk__button(
		-text => 'Get Sequence',
		-command => sub{search_sequence($wgt{search})},
	)->g_grid(
		-column => 5,
		-row => 2,
		-sticky => 'e',
	);
	
	insert_to_list();
	
}
sub onchange_s_acc_combo{
	my $DB = SQLiteDB->new(-database => 'database.db');
	my $ref = $DB->query_column("SELECT DISTINCT feat FROM gs_feat,gs_desc WHERE gs_desc.accession='$par{search_accession}' AND gs_desc.ID=gs_feat.GID");
	push @$ref, 'protein';
	$wgt{s_feat_combo}->configure(-values => $ref);
	$wgt{s_feat_combo}->current(0);
	insert_to_list($par{search_annotation});
}
sub refresh_annot_list{
	insert_to_list(shift);
}
sub insert_to_list{
	my $key = shift;
	my $gb = $par{search_accession};
	my $feat = $par{search_feature};
	$feat =~ s/'/''/g;
	if($key){
		$key =~ s/^\s+|\s+$//g;
		$key =~ s/\s+/%/g;
		$key =~ s/'/''/g;
	}
	my $sql;
	if($feat eq 'protein'){
		$sql = "SELECT gs_annot.ID, gs_annot.aname, gs_annot.aval FROM gs_annot,gs_desc,gs_feat WHERE gs_desc.accession='$gb' AND gs_feat.feat='CDS' AND gs_desc.ID=gs_feat.GID AND gs_feat.ID=gs_annot.FID";
	}else{
		$sql = "SELECT gs_annot.ID, gs_annot.aname, gs_annot.aval FROM gs_annot,gs_desc,gs_feat WHERE gs_desc.accession='$gb' AND gs_feat.feat='$feat' AND gs_desc.ID=gs_feat.GID AND gs_feat.ID=gs_annot.FID";
	}
	$sql .= " AND (gs_annot.aname LIKE '$key' OR gs_annot.aval LIKE '%$key%')" if $key;
	my $DB = SQLiteDB->new(-database => 'database.db');
	$DB->prepare_execute($sql);
	$wgt{list}->delete($wgt{list}->children(""));
	while( my $rv = $DB->query_next()){
		$wgt{list}->insert("", "end", -id => $rv->[0], -values => [$rv->[1], $rv->[2]]);
	}
}

###############################################################
# functions to finish tasks
###############################################################
sub on_exit(){
	unlink 'database.db' if -e 'database.db';
	$mw->g_destroy;
}
sub paste{
	my $content = eval {Tkx::clipboard('get')};
	return unless $content;
	my $flag = ($content =~ /LOCUS/) && ($content =~ /ACCESSION/)
			   && ($content =~ /ORIGIN/);
	alert_info("The format is not a GenBank flat file! Please copy right content.") unless $flag;
	clear();
	$wgt{text}->configure(-state => "normal");
	Tkx::event_generate($wgt{text}, "<<Paste>>");
	$wgt{text}->configure(-state => "disabled");
	$wgt{text}->edit_modified(1);
}
sub clear{
	$wgt{text}->configure(-state => "normal");
	$wgt{text}->delete("1.0", "end");
	$wgt{text}->configure(-state => "disabled");
	$wgt{text}->edit_modified(1);
}
sub un_do{
	$wgt{text}->configure(-state=>"normal");
	Tkx::event_generate($wgt{text}, "<<Undo>>");
	$wgt{text}->configure(-state=>"disabled");
	$wgt{text}->edit_modified(1);
}
sub re_do{
	$wgt{text}->configure(-state=>"normal");
	Tkx::event_generate($wgt{text}, "<<Redo>>");
	$wgt{text}->configure(-state=>"disabled");
	$wgt{text}->edit_modified(1);
}
sub save_as{
	my $text = get_from_text();
	alert_info("There is no genbank file.") if $text=~/^\s+$/;
	my $file = Tkx::tk___getSaveFile(
		-parent => $mw,
		-initialdir => \$par{lastsavedir},
		-defaultextension => '.txt',
		-initialfile => $file_info{acc},
		-filetype => [["TXT FILE",'.txt'],["GenBank FILE", '.gb']],
	);
	return unless $file;
	$par{lastsavedir} = dirname($file);
	$file = encode("gb2312", $file);
	open SAVE, ">", $file;
	print SAVE $text;
	close SAVE;
}
sub choose_file{
    my $file = Tkx::tk___getOpenFile(
		-parent => $mw,
		-initialdir => $par{lastopendir},
	);
	$file = encode("gb2312", $file);
	$par{lastopendir} = dirname($file);
    return $file if $file;
}
sub status_msg{
	$par{msg} = shift;
	Tkx::update();
}
sub insert_to_widget{
	my ($widget, $content) = @_;
	$widget->configure(-state => "normal");
	$widget->delete("1.0", "end");
	$widget->insert("end", $content);
	$widget->configure(-state => "disabled");
}
sub insert_to_text{
    my $text = shift;
	$par{format} = get_file_format($text);
	if ($par{format} eq "unknown"){
		my $mes = "Load file fail, Please check file content!";
		Tkx::tk___messageBox(-parent => $mw, -type => "ok", -message => $mes, -icon => "error", -title => "ERROR");
		return;
	}
	$wgt{text}->configure(-state => "normal");
    $wgt{text}->delete("1.0", "end");
    $wgt{text}->insert("end", $text);
	$wgt{text}->configure(-state => "disabled");
	$wgt{text}->edit_modified(1);
	
    Tkx::update();
}
sub add_bind_geneid{
	my $count;
	my $start = $wgt{text}->search('-count' => \$count, '-regex', '-all', 'GeneID:\d+|GI:\d+|protein_id="[^"]+?"', '1.0');
	my @start_list = Tkx::SplitList($start);
	my @count_list = Tkx::SplitList($count);
	my @location;
	while((my $s = shift @start_list) && (my $e = shift @count_list)){
		push @location, ($s, "$s + $e chars");
	}
	$wgt{text}->tag('add', 'GID', @location);
	$wgt{text}->tag_configure('GID', -foreground => 'red');
	$wgt{text}->tag_bind('GID', "<Enter>", sub {$wgt{text}->configure(-cursor => "hand2");});
    $wgt{text}->tag_bind('GID', "<Leave>", sub {$wgt{text}->configure(-cursor => "xterm");});
	$wgt{text}->tag_bind('GID', '<ButtonRelease-1>', sub {get_seq_from_tag('GID')});
}
sub add_bind_feature{
	my $count;
	my $start = $wgt{text}->search('-count' => \$count, '-regex', '-all', '^\s+[\w\-\'*]+\s+.*?\.\..*$', '1.0');
	my @start_list = Tkx::SplitList($start);
	my @count_list = Tkx::SplitList($count);
	my @location;
	while((my $s = shift @start_list) && (my $e = shift @count_list)){
		push @location, ($s, "$s + $e chars");
	}
	$wgt{text}->tag('add', 'highlight', @location);
	$wgt{text}->tag_configure('highlight', -foreground => 'blue', -spacing1 => 5, -spacing3=> 5);
	$wgt{text}->tag_bind('highlight', "<Enter>", sub {$wgt{text}->configure(-cursor => "hand2");});
    $wgt{text}->tag_bind('highlight', "<Leave>", sub {$wgt{text}->configure(-cursor => "xterm");});
	$wgt{text}->tag_bind('highlight', '<ButtonRelease-1>', sub {get_seq_from_tag('highlight')});
}
sub add_bind_tags{
	return if $par{genbank} eq 'No File';
	add_bind_feature();
	add_bind_geneid();
}
sub cancel_bind_tags{
	return if $par{genbank} eq 'No File';
	$wgt{text}->tag_delete('highlight','GID');
}
sub get_seq_from_tag{
	my $tag = shift;
	my $line = $wgt{text}->tag_prevrange($tag, "current");
	chomp(my $selected = $wgt{text}->get(Tkx::SplitList($line)));
	$selected =~ s/^\s+|\s+$//g;
	my $DB = SQLiteDB->new(-database => 'database.db');
	if($selected =~ /^protein_id="(.*)"/){
		my $pid = $1;
		my ($id) = $DB->query_row("SELECT FID FROM gs_annot WHERE aname='protein_id' AND aval='$pid'");
		my ($seq) = $DB->query_row("SELECT aval FROM gs_annot WHERE aname='translation' AND FID=$id");
		return unless $seq;
		$seq = ">$selected ".length($seq)." bp\n".format_to_fasta($seq);
		create_save_win($seq, $pid);
		return;
	}
	if($selected =~ /^GI:|^GeneID:/){
		my ($l, $r) = split /:/, $selected;
		my ($loci, $sequence) = $DB->query_row("SELECT gs_feat.loci,gs_desc.sequence FROM gs_desc,gs_feat,gs_annot WHERE aname='$l' AND aval='$r' AND gs_feat.ID=gs_annot.FID AND gs_feat.GID=gs_desc.ID");
		
		my $seq;
		foreach my $site (split /,/, $loci){
			my ($start, $end) = split /-/, $site;
			$seq .= get_seq_fragment($sequence, $start, $end);
		}
		if(!$seq){
			($seq) = $DB->query_row("SELECT sequence FROM gs_desc WHERE gi='$r'");
		}
		return unless $seq;
		$seq = ">$selected ".length($seq)." bp\n".format_to_fasta($seq);
		create_save_win($seq, $r);
		return;
	}
	
	my ($feat, $loci);
	if($selected =~ /^([\w-'*]+)\s+<?(\d+)\.\.>?(\d+)$/){
		($feat, $loci) = ($1, "$2-$3");
	}elsif($selected =~ /^([\w-'*]+)\s+(\d+)[.^](\d+)$/){
		($feat, $loci) = ($1, "$2-$3");
	}elsif($selected =~ /^([\w-'*]+)\s+complement\((\d+)\.\.(\d+)\)$/){
		($feat, $loci) = ($1, "$2-$3");
	}elsif($selected =~ /^([\w-'*]+)[^join]+join/){
		$feat = $1;
		while($selected =~ /(\d+)\.\.(\d+)/g){
			if($loci){
				$loci .= ",$1-$2";
			}else{
				$loci .= "$1-$2";
			}
		}
	}elsif($selected =~ /^([\w-'*]+)\s+[^:]+:(\d+)\.\.(\d+)/){
		($feat, $loci)= ($1, "$2-$3");
	}
	my $seq;
	$feat =~ s/'/''/;
	my ($sequence) = $DB->query_row("SELECT gs_desc.sequence FROM gs_desc,gs_feat WHERE gs_feat.feat='$feat' AND gs_feat.loci='$loci' AND gs_desc.ID=gs_feat.GID");
	foreach my $site (split /,/, $loci){
		my ($start, $end) = split /-/, $site;
		$seq .= get_seq_fragment($sequence, $start, $end);
	}
	
	if($seq){
		$selected =~ s/\s+/ /;
	}else{
		return;
	}
	
	$seq = ">$selected ". length($seq) ." bp\n".format_to_fasta($seq);
	create_save_win($seq, $selected);
}
sub get_from_text{
	my $w = shift;
	return $w->get("1.0", "end") if $w;
	return $wgt{text}->get("1.0", "end");
}
sub alert_info{
    my ($mes, $parent) = @_;
	if($parent){
		Tkx::tk___messageBox(-parent => $parent, -type => "ok", -message => $mes, -icon => "error", -title => "ERROR");
	}else{
		Tkx::tk___messageBox(-parent => $mw, -type => "ok", -message => $mes, -icon => "error", -title => "ERROR");
	}
    Tkx::MainLoop;
}
sub get_file_format{
	my $c = shift;
	$c =~ s/^\s+//;
	my $format = "unknown";
	if($c=~/^LOCUS/){
		$format = "NCBI";
	}
	return $format;
}
sub read_file{
    my $file = shift;
    open my $FILE, $file
        or alert_info("Can not open file: $!");
    my $content = do{local $/; <$FILE>};
	close $FILE;
    return $content;
}
sub open_file{
    my $fn = choose_file();
	return unless $fn;
    my $fc = read_file($fn);
    insert_to_text($fc);
}
sub drag_file{
	my $fn = shift;
	return unless $fn;
	$fn = encode("gb2312", $fn);
	insert_to_text(read_file($fn));
}
sub load_file{
    my ($acc, $p) = shift;
	$acc=~s/\s//g;
	alert_info("Accession number can not be Empty!", $p) unless $acc;
	my $base_url='http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=';
	my $fetch_url=$base_url.$acc.'&rettype=gb';
	my $content=get($fetch_url);
	if($content=~/Nothing has been found/){
		alert_info("Accession $acc does not Exit.", $p);
	}elsif(!$content){
		alert_info("Can't Connect to NCBI.", $p);
	}
    insert_to_text($content);
	$p->g_destroy;
}
sub parse_gb_file{
	copy('db/database.db', '.') unless -e 'database.db';
	my $file = get_from_text();
	if($file =~ /^\s*$/){
		$wgt{gb_combo}->configure(-values => ['No File']);
		$wgt{gb_combo}->current(0);
		$wgt{feat_combo}->configure(-values => ['No Feature']);
		$wgt{feat_combo}->current(0);
		$wgt{info_combo}->configure(-values => ['No Keys']);
		$wgt{info_combo}->current(0);
		return;
	}
	my @gbs = split /\/\//, $file;
	undef $file;
	my $DB = SQLiteDB->new(-database => 'database.db');
	$DB->delete_db_list();
	while(my $gb = shift @gbs){
		next if $gb =~ /^\s*$/;
		my $hash = ();
		my ($head, $middle, $foot) = split /FEATURES|ORIGIN/, $gb;
		undef $gb;
		
		#parase genbank file information from head
		if($head =~ /^\s*LOCUS\s+\S+\s+(\d+)/xm){
			$hash->{seqlen} = $1;
		}
		if($head =~ /^\s*ACCESSION\s+(\S+)/xm){
			$hash->{accession} = $1;
		}
		if($head =~ /^\s*DEFINITION\s+(.*)\.?$/xm){
			$hash->{definition} = $1;
		}
		if($head =~ /^\s*VERSION\s+(\S+)\s+GI:(\d+)/xm){
			($hash->{version}, $hash->{gi}) = ($1, $2);
		}
		if($head =~ /^\s*SOURCE\s+(.*)/xm){
			$hash->{source} = $1;
		}
		undef $head;
		#end parase head
		
		#parase genbank sequence from foot
		$foot =~ s/\d//g;
		$foot =~ s/\s//g;
		$hash->{sequence} = $foot;
		undef $foot;
		my $gid = $DB->add_hash_to_db($hash, 'gs_desc');
		$hash = ();
		
		#parase genbank features from middle
		my @lines = split /\n/, $middle;
		undef $middle;
		
		my $fid; #last inseted feature id
		while($_ = shift @lines){
		
			s/^\s+|\s+$//g;
			
			next unless $_;
			
			#parase feature name and loci
			
			if(/^([\w\-'*]+)\s+(\d+)$/){
				($hash->{feat}, $hash->{loci}) = ($1, $2);
			}elsif(/^([\w\-'*]+)\s+<?(\d+)\.\.>?(\d+)$/){
				($hash->{feat}, $hash->{loci}) = ($1, "$2-$3");
			}elsif(/^([\w\-'*]+)\s+(\d+)[.^](\d+)$/){
				($hash->{feat}, $hash->{loci}) = ($1, "$2-$3");
			}elsif(/^([\w\-'*]+)\s+complement\((\d+)\.\.(\d+)\)$/){
				($hash->{feat}, $hash->{loci}) = ($1, "$2-$3");
			}elsif(/^([\w\-'*]+)[^join]+join/){
				$hash->{feat} = $1;
				while(/(\d+)\.\.(\d+)/g){
					if($hash->{loci}){
						$hash->{loci} .= ",$1-$2";
					}else{
						$hash->{loci} .= "$1-$2";
					}
				}
			}elsif(/^([\w\-'*]+)\s+[^:]+:(\d+)\.\.(\d+)/){
				($hash->{feat}, $hash->{loci}) = ($1, "$2-$3");
			}
			
			if($hash->{feat} && $hash->{loci}){
				$hash->{GID} = $gid;
				$fid = $DB->add_hash_to_db($hash, 'gs_feat');
				$hash = ();
			}
			#parse annotation information for each feature
			next unless $fid;
			
			while($_ = shift @lines){
			
				s/^\s+|\s+$//g;
				
				if(/^\/db_xref="([^"]+):([^"]+)"$/){
					($hash->{aname}, $hash->{aval}) = ($1, $2);
				}elsif(/^\/([^=]+)="([^"]+)"$/){
					($hash->{aname}, $hash->{aval}) = ($1, $2);
				}elsif(/^\/([^=]+)="([^"]+)$/){
					($hash->{aname}, $hash->{aval}) = ($1, $2);
					while($_ = shift @lines){
						
						s/^\s+|\s+$//g;
						
						if(/^\//){
							unshift @lines, $_;
							last;
						}elsif(/^.*"$/){
							s/"//;
							last if $_ eq '';
							if(/^[A-Z]+$/){
								$hash->{aval} .= $_;
							}else{
								$hash->{aval} .= ' '.$_;
							}
							last;
						}else{
							if(/^[A-Z]+$/){
								$hash->{aval} .= $_;
							}else{
								$hash->{aval} .= ' '.$_;
							}
						}
					}	
				}elsif(/^\/([^=]+)=([^=]+)$/){
					($hash->{aname}, $hash->{aval}) = ($1, $2);
				}else{
					unshift @lines, $_;
					last;
				}
				
				if($hash->{aname} && $hash->{aval}){
					$hash->{FID} = $fid;
					$DB->add_hash_to_db($hash, 'gs_annot');
					$hash = ();
				}
				
			}
			$fid = 0;
		}
		
	}
	
	#refresh combobox from database
	my $ref = $DB->query_column("SELECT DISTINCT accession FROM gs_desc");
	$wgt{gb_combo}->configure(-values => $ref);
	$wgt{gb_combo}->current(0);
	$ref = $DB->query_column("SELECT DISTINCT gs_feat.feat FROM gs_feat,gs_desc WHERE gs_feat.GID=gs_desc.ID AND gs_desc.accession='$par{genbank}'");
	push @$ref, 'protein';
	$wgt{feat_combo}->configure(-values => $ref);
	$wgt{feat_combo}->current(0);
	my $feat = $par{feature};
	$feat =~ s/'/''/g;
	foreach ('gene', 'locus_tag', 'product'){
		$ref = $DB->query_array_row("select gs_feat.feat,gs_feat.loci,gs_annot.aval from gs_feat,gs_annot,gs_desc where gs_desc.ID=gs_feat.GID and gs_desc.accession='$par{genbank}' and gs_feat.ID=gs_annot.FID and gs_feat.feat='$feat' and gs_annot.aname='$_'");
		next unless @$ref;
		last if @$ref;
	}
	if(!@$ref){
		$ref = $DB->query_array_row("select gs_feat.feat,gs_feat.loci from gs_feat,gs_desc where gs_desc.ID=gs_feat.GID and gs_desc.accession='$par{genbank}' and gs_feat.feat='$feat'");
	}
	my $keys = [];
	while(my $row = shift @$ref){
		if($row->[2]){
			push @$keys, $row->[2]." | ". $row->[1];
		}else{
			push @$keys, $row->[0]." | ". $row->[1];
		}
	}
	push @$keys, 'unlimited' if(@$keys > 1);
	$wgt{info_combo}->configure(-values => $keys);
	$wgt{info_combo}->current(0);
}

sub onchange_gb_combo{
	my $DB = SQLiteDB->new(-database => 'database.db');
	my $ref = $DB->query_column("SELECT DISTINCT feat FROM gs_feat,gs_desc WHERE gs_feat.GID=gs_desc.ID AND gs_desc.accession='$par{genbank}'");
	push @$ref, 'protein';
	$wgt{feat_combo}->configure(-values => $ref);
	$wgt{feat_combo}->current(0);
	onchange_feat_combo();
}
sub onchange_feat_combo{
	my $DB = SQLiteDB->new(-database => 'database.db');
	my $ref;
	my $feat = $par{feature};
	$feat =~ s/'/''/g;
	# protein sequence
	if($feat eq 'protein'){
		$ref = $DB->query_array_row("select gs_annot.aval from gs_feat,gs_annot,gs_desc where gs_desc.ID=gs_feat.GID and gs_desc.accession='$par{genbank}' and gs_feat.ID=gs_annot.FID and gs_feat.feat='CDS' and gs_annot.aname='protein_id' ORDER BY gs_annot.ID");
		if(@$ref){
			push @$ref, 'unlimited';
		}else{
			push @$ref, 'No Protein';
		}
		$wgt{info_combo}->configure(-values => $ref);
		$wgt{info_combo}->current(0);
		return;
	}
	
	# gene sequence
	foreach ('gene', 'locus_tag', 'product'){
		$ref = $DB->query_array_row("select gs_feat.feat,gs_feat.loci,gs_annot.aval from gs_feat,gs_annot,gs_desc where gs_desc.ID=gs_feat.GID and gs_desc.accession='$par{genbank}' and gs_feat.ID=gs_annot.FID and gs_feat.feat='$feat' and gs_annot.aname='$_'");
		next unless @$ref;
		last if @$ref;
	}
	if(!@$ref){
		$ref = $DB->query_array_row("select gs_feat.feat,gs_feat.loci from gs_feat,gs_desc where gs_desc.ID=gs_feat.GID and gs_desc.accession='$par{genbank}' and gs_feat.feat='$feat'");
	}
	my $keys = [];
	while(my $row = shift @$ref){
		if($row->[2]){
			push @$keys, $row->[2]." | ". $row->[1];
		}else{
			push @$keys, $row->[0]." | ". $row->[1];
		}
	}
	push @$keys, 'unlimited' if(@$keys > 1);
	$wgt{info_combo}->configure(-values => $keys);
	$wgt{info_combo}->current(0);
}


#sort funciton
sub anon{
	return 0 if $a eq $b;
	my ($sa, $na) = (split /\|/, $a)[0,1];
	my ($sb, $nb) = (split /\|/, $b)[0,1];
	my $cmp = $sa cmp $sb;
	return $cmp if $cmp;
	return $na <=> $nb;
}


# intercept short string from a long sequence.
sub get_seq_fragment{
	my ($sequence, $start, $end) = @_;
	my $len = $end - $start + 1;
	$len = 1 if $len <= 0;
	my $seq = substr($sequence, $start-1, $len);
	return $seq;
}
sub format_to_fasta{
	my $seq = shift;
	my $len = 70;
	while($len < length($seq)){
		substr($seq, $len, 0) = "\n";
		$len += 70;
		$len++;
	}
	return $seq;
}

sub get_dna_seq{
	my ($gb, $feat, $keys) = ($par{genbank}, $par{feature}, $par{feat_content});
	my $DB = SQLiteDB->new(-database => 'database.db');
	my ($sequence) = $DB->query_row("SELECT sequence FROM gs_desc WHERE accession='$gb'");
	my $out_seq;
	my $seq;
	if($keys eq 'unlimited'){
		my $fts = $wgt{info_combo}->cget('-values');
		pop @$fts;
		while(my $ft = shift @$fts){
			my ($id, $loci) = split /\s+\|\s+/, $ft;
			my @loci = split /,/, $loci;
			if(@loci == 1){
				my ($start, $end) = split /-/, shift @loci;
				$seq = get_seq_fragment($sequence, $start ,$end);
				my $len = length($seq);
				$seq = format_to_fasta($seq);
				$seq = $id eq $feat ? '>'.$gb." $id $loci $len bp\n".$seq : '>'.$gb." $feat $id $loci $len bp\n".$seq;
			}else{
				while($_ = shift @loci){
					my ($start, $end) = split /-/, $_;
					$seq .= get_seq_fragment($sequence, $start ,$end);
				}
				my $len = length($seq);
				$seq = format_to_fasta($seq);
				$seq = $id eq $feat ? '>'.$gb." $id $loci $len bp\n".$seq : '>'.$gb." $feat $id $loci $len bp\n".$seq;
			}
			$out_seq .= $seq."\n";
			$seq = '';
		}
		return $out_seq;
	}else{
		my ($id, $loci) = split /\s+\|\s+/, $keys;
		my @loci = split /,/, $loci;
		if(@loci == 1){
			my ($start, $end) = split /-/, shift @loci;
			$seq = get_seq_fragment($sequence, $start ,$end);
			my $len = length($seq);
			$seq = format_to_fasta($seq);
			$seq = $id eq $feat ? '>'.$gb." $id $loci $len bp\n".$seq : '>'.$gb." $feat $id $loci $len bp\n".$seq;
		}else{
			while(@loci){
				my ($start, $end) = split /-/, shift @loci;
				$seq .= get_seq_fragment($sequence, $start ,$end);
			}
			my $len = length($seq);
			$seq = format_to_fasta($seq);
			
			$seq = $id eq $feat ? '>'.$gb." $id $loci $len bp\n".$seq : '>'.$gb." $feat $id $loci $len bp\n".$seq;
		}
		return $seq;
	}
}
sub get_protein_seq{
	my $keys = $par{feat_content};
	my $DB = SQLiteDB->new(-database => 'database.db');
	my $seq;
	if($keys eq 'unlimited'){
		my $ids = $wgt{info_combo}->cget('-values');
		pop @$ids;
		my $ref = $DB->query_column("SELECT gs_annot.aval FROM gs_annot,gs_feat,gs_desc WHERE gs_desc.accession='$par{genbank}' AND gs_desc.ID=gs_feat.GID AND gs_feat.feat='CDS' AND gs_feat.ID=gs_annot.FID AND gs_annot.aname='translation' ORDER BY gs_annot.ID");
		while((my $id = shift @$ids) && (my $p = shift @$ref)){
			$seq .= ">$par{genbank} $id\n".format_to_fasta($p)."\n";
		}
	}else{
		my ($id) = $DB->query_row("SELECT gs_annot.FID FROM gs_annot WHERE gs_annot.aval='$keys'");
		($seq) = $DB->query_row("SELECT gs_annot.aval FROM gs_annot WHERE gs_annot.aname='translation' AND gs_annot.FID=$id");
		$seq = ">$par{genbank} $keys\n". format_to_fasta($seq);
	}
	return $seq;
}

sub get_total_seq{
	alert_info("Please Add GenBank File!") if $par{genbank} eq 'No File';
	my $content;
	if($par{feature} eq 'protein'){
		$content = get_protein_seq();
		
	}else{
		$content = get_dna_seq();
	}
	return unless $content;
	create_save_win($content);
}
sub merge_seq{
	my $widget = shift;
	my $seq = $widget->get("1.0", "end");
	if(!$par{merge}){
		$seq = $par{save};
	}else{
		my $records = 0;
		while($seq =~ />.*/g){
			$records ++;
		}
		return if $records < 2;
		
		$par{save} = $seq;
		
		$seq =~ s/>.*//gxm;
		$seq =~ s/\s//g;
		my $len = length($seq);
		$seq = format_to_fasta($seq);
		$seq = ">$par{genbank} $par{feature} $len bp\n" . $seq;
	}
	$widget->delete("1.0", "end");
	$widget->insert("end", $seq);
}
sub save_seq{
	my ($widget, $parent, $name) = @_;
	$name = $par{genbank}.'_'.$par{feature}.'_'.$par{feat_content} unless $name;
	$name =~ s/[|\/:*?]/ /g;
	$name =~ s/\s+/ /g;
    my $save_file = Tkx::tk___getSaveFile(
		-initialdir => \$par{lastsaveseqdir},
		-parent => $parent, 
		-defaultextension => ".txt", 
		-initialfile => $name, 
		-filetypes => [['TXT FILE', '.txt'], ['FASTA FILE', '.fa']],
	);
	return unless $save_file;
	$par{lastsaveseqdir} = dirname($save_file);
	$save_file = encode("gb2312", $save_file);
    open OP, ">", $save_file
		or alert_info("Can not open file $save_file:$!", $parent);
	chomp (my $content = get_from_text($widget));
    print OP $content;
	close OP;
	$parent->g_destroy;
}

# download Genbank sequence file
sub download_gb_file{
	my ($acc, $p) = @_;
	$acc=~s/\s//g;
	alert_info("Accession number can not be Empty!", $p) unless $acc;
	my $base_url='http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=';
	my $fetch_url=$base_url.$acc.'&rettype=gb&retmode=txt';
	my $ua = LWP::UserAgent->new;
	$ua->timeout(30);
	$ua->show_progress('TRUE');
	my $response = $ua->get($fetch_url);
	my $content;
	if($response->is_success){
		$content = $response->decoded_content;
	}else{
		alert_info($response->status_line, $p);
	}
	if($content=~/Nothing has been found/){
		alert_info("Accession $acc does not Exist.", $p);
	}
    insert_to_text($content);
	$p->g_destroy;
}

# convert genbank to fasta
sub convert_to_fasta{
	if($par{genbank} eq 'No File'){
		alert_info("Please Add GenBank File!");
		return;
	}
	my $DB = SQLiteDB->new(-database => 'database.db');
	my $ref = $DB->query_row_hash("SELECT * FROM gs_desc WHERE accession='$par{genbank}'");
	my $seq = ">gi|$ref->{gi}|ref|$ref->{version}| $ref->{definition}\n";
	$seq .= format_to_fasta($ref->{sequence});
	create_save_win($seq, $par{genbank});
}

#search gene by geneID or Gene name

sub search_sequence{
	my $widget = shift;
	my $id = $wgt{list}->selection();
	alert_info("Pleas select an annotation!", $widget) unless $id;
	my ($acc, $feat) = ($par{search_accession}, $par{search_feature});
	$feat=~s/'/''/g;
	my $DB = SQLiteDB->new(-database => 'database.db');
	if($feat eq 'protein'){
		my ($fid) = $DB->query_row("SELECT FID FROM gs_annot WHERE ID=$id");
		my ($seq) = $DB->query_row("SELECT aval FROM gs_annot WHERE FID=$fid AND aname='translation'");
		my ($protein_id) = $DB->query_row("SELECT aval FROM gs_annot WHERE FID=$fid AND aname='protein_id'");
		$seq = ">$par{search_accession} $protein_id\n" . format_to_fasta($seq);
		create_save_win($seq, 'protein_' . $protein_id);
		return;
	}
	
	my ($sequence) = $DB->query_row("SELECT sequence FROM gs_desc WHERE accession='$acc'");
	my ($loci) = $DB->query_row("SELECT gs_feat.loci from gs_feat, gs_annot, gs_desc WHERE gs_desc.accession='$acc' AND gs_desc.ID=gs_feat.GID AND gs_feat.feat='$feat' AND gs_feat.ID=gs_annot.FID AND gs_annot.ID=$id");
	my @loci = split /,/, $loci;
	my $seq;
	if(@loci == 1){
		my ($start, $end) = split /-/, shift @loci;
		$seq = get_seq_fragment($sequence, $start ,$end);
		my $len = length($seq);
		$seq = format_to_fasta($seq);
		$seq = '>'.$acc." $feat $loci $len bp\n".$seq;
	}else{
		while($_ = shift @loci){
		my ($start, $end) = split /-/, shift @loci;
			$seq .= get_seq_fragment($sequence, $start ,$end);
		}
		my $len = length($seq);
		$seq = format_to_fasta($seq);
		$seq = '>'.$acc." $feat $loci $len bp\n".$seq;
	}
	create_save_win($seq, $feat.'_'.$loci);
}
sub switch_to_batch{
	if($is_linux){
		exec("./batch &") if -e "batch";
	}else{
		exec("batch.exe") if -e "batch.exe";
	}
}