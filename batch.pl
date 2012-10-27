#!/usr/bin/perl
use strict;
use Tkx;
use Cwd;
use File::Basename;
use File::Find;
use Encode;
use Encode::CN;
use POSIX qw(ceil);
use File::Copy;
use SQLiteDB;
Tkx::package_require('img::png');
Tkx::package_require('img::ico');
Tkx::package_require('widget::statusbar');
Tkx::package_require('tooltip');
Tkx::namespace_import("::tooltip::tooltip");
Tkx::lappend('::auto_path', 'lib');
Tkx::package_require('tkdnd');

my %file_info;
my %feat_info;
my %features;
my %genes;
my $is_linux = Tkx::tk_windowingsystem() eq 'x11' ? 1 : 0;


my $mw=Tkx::widget->new('.');
$mw->g_wm_title("Batch Processing");
if($is_linux){
	Tkx::wm_iconphoto($mw, "-default", Tkx::image_create_photo(-file => 'genscalpel.ico'));
}else{
	Tkx::wm_iconbitmap($mw, -default => "genscalpel.ico");
}
#$mw->g_wm_geometry("600x400");
$mw->g_wm_protocol('WM_DELETE_WINDOW', sub{on_exit()});

# global variable
my $opdir = cwd;
my ($lastopendir, $lastoutdir, $lastadddir);
my $opdir_display = cwd; #output directory
my $feature; # get the selected or inputed feature
my $gene; #gene name for search
my $message="Welcome to GenScalpel Batch Program."; # message on statusbar
my @formats=qw/.txt .fa .gb .genbank .fasta/;
my $file_num=0; # number of all added files.
my $processed=0; # number of processed files.
my $progress = 0; #variable of progress bar.
my $merge_seq = 0;
my $merge_file = 0;
my $reparse = 0;

#output directory
my $of=$mw->new_ttk__frame(
	-padding => 12,
	-relief=>"groove",
	-borderwidth => 2,
);
$of->g_grid(
	-sticky=>"we",
);
$of->g_grid_columnconfigure(1, -weight => 1);
$of->new_ttk__label(
	-text=>"Select Output Directory:",
)->g_grid(
	-column => 0,
	-row => 0,
);
$of->new_ttk__entry(
	-textvariable => \$opdir_display,
	-width => 35,
	-state => 'disabled',
)->g_grid(
	-column => 1,
	-row => 0,
	-sticky => "we",
);
$of->new_ttk__button(
	-text => "Browser",
	-command => sub{select_dir()},
)->g_grid(
	-column => 2,
	-row => 0,
);
$of->new_ttk__button(
	-text => "Open",
	-command => sub{open_dir($opdir)},
)->g_grid(
	-column => 3,
	-row => 0,
);

my $bf=$mw->new_ttk__frame(-padding => 5); #batch frame
$bf->g_grid(-sticky => "wnes");

my $sb=$mw->new_widget__statusbar(-ipad => [1, 2]); # status bar
$sb->g_grid(-sticky => "we");

#buttons frame
my $hb = $bf->new_ttk__frame();
$hb->g_grid(
	-column => 0,
	-row => 0,
	-sticky => "wnes",
	-pady => 5,
);

$hb->new_ttk__button(
	-text => "Parse GenBank Files",
	-command => sub{batch_parse_genbank();}
)->g_grid(
	-column => 0,
	-row => 0,
);
$hb->new_ttk__button(
	-text => "Switch to Single",
	-command => sub{switch_to_single()},
)->g_grid(
	-column => 1,
	-row => 0,
);
$hb->new_ttk__button(
	-text => "Convert to Fasta",
	-command => sub{convert_to_fasta($opdir)},
)->g_grid(
	-column => 2,
	-row => 0,
);
$hb->new_ttk__button(
	-text => "Get Protein Sequence",
	-command => sub{get_protein_seq($opdir)},
)->g_grid(
	-column => 3,
	-row => 0,
);

# batch processing frame
my $fl = $bf->new_ttk__labelframe(
	-text => "File(s) List:", 
	-padding => 5
); # files list
$fl->g_grid(
	-column => 0, 
	-row => 1,
	-sticky=>"wnes",
);
my $file_list= $fl->new_ttk__treeview(
	-columns => "name size state", 
	-height => 0,
	-show => 'headings',
);
$file_list->g_grid(-column => 0, -row => 0, -sticky=>"wnes");
my $column_width = ceil($file_list->g_winfo_width/3);
foreach (qw(name size state)){
	$file_list->column($_, -width => $column_width, -anchor => "center");
}
$file_list->heading("name", -text => "File Name");
$file_list->heading("size", -text => "Size");
$file_list->heading("state", -text => "Status");


my $tree_scrollbar = $fl->new_ttk__scrollbar(-orient => 'vertical', -command => [$file_list, 'yview']);
$tree_scrollbar->g_grid(-column => 1, -row => 0, -sticky => "ns");
$file_list->configure(-yscrollcommand => [$tree_scrollbar, 'set']);

Tkx::tkdnd__drop___target_register($file_list,'*');
Tkx::bind($file_list, '<<Drop:DND_Files>>', [sub{drag_file(shift)}, Tkx::Ev('%D')]);

my $fn = $fl->new_ttk__frame(); #frame of buttons
$fn->g_grid(
	-column=>0,
	-row=>1,
	-sticky=>"we",
);
# add file button
my $img_file=$fn->new_ttk__button(
	-image => Tkx::image_create_photo(-file => 'icons/file.png'),
	-style => "Toolbutton",
	-width => 0,
	-command => sub{add_files()},
);
$img_file->g_grid(-column=>0,-row=>0);
Tkx::tooltip($img_file, "Add Files");
# add folder button
my $img_folder=$fn->new_ttk__button(
	-image => Tkx::image_create_photo(-file => 'icons/folder.png'),
	-style => "Toolbutton",
	-width => 0,
	-command => sub{add_folder()},
);
$img_folder->g_grid(-column=>1,-row=>0);
Tkx::tooltip($img_folder, "Add Folder");
#delete file button
my $img_del=$fn->new_ttk__button(
	-image => Tkx::image_create_photo(-file => 'icons/delete.png'),
	-style => "Toolbutton",
	-width => 0,
	-command => sub{delete_files()},
);
$img_del->g_grid(-column=>2,-row=>0);
Tkx::tooltip($img_del, "Delete");
#delete all files button
my $img_clear=$fn->new_ttk__button(
	-image => Tkx::image_create_photo(-file => 'icons/clear.png'),
	-style => "Toolbutton",
	-width => 0,
	-command => sub{clear_files()},
);
$img_clear->g_grid(-column=>3,-row=>0);
Tkx::tooltip($img_clear, "Clear");

my $ft = $bf->new_ttk__frame(); # frame of tools
$ft->g_grid(
	-column=>1,
	-row=>0,
	-rowspan => 2,
	-sticky => "wnes",
	-padx => "10 0",
);


my $fc = $ft->new_ttk__labelframe( #frame of convert tool
	-text => "Output",
	-padding => 12,
);
$fc->g_grid(-sticky=>"wnes");
$fc->new_ttk__checkbutton(
	-text => "Merge Sequence",
	-variable => \$merge_seq,
	-offvalue => 0,
	-onvalue => 1,
)->g_grid(-sticky => "wnes");
$fc->new_ttk__checkbutton(
	-text => "Merge File",
	-variable => \$merge_file,
	-offvalue => 0,
	-onvalue => 1,
)->g_grid(-sticky => "wnes");

my $ff = $ft->new_ttk__labelframe( #frame of features
	-text => "Features",
	-padding => 12,
);
$ff->g_grid(-sticky=>"wnes");
$ff->new_ttk__label(
	-text => "Features:",
	-anchor => "w",
)->g_grid(-sticky=>"we");
my $combo_f = $ff->new_ttk__combobox(
	-textvariable => \$feature,
	-values => ["No Features"],
	-width => 15,
);
$combo_f->g_grid(-sticky => "we");
$combo_f->current(0);
#$ff->new_ttk__label(
#	-text => "Note: select a feature or input a feature.",
#	-wraplength => 140,
#	-foreground=>'gray',
#)->g_grid();
$ff->new_ttk__button(
	-text => "Get Sequence",
	-command => sub{get_bat_seq($opdir,$feature)},
)->g_grid(
	-sticky=>"wnes",
	-pady => "5 0",
);

my $fg=$ft->new_ttk__labelframe( #frame of gene
	-text => "Annotation",
	-padding => 12,
);
$fg->g_grid(-sticky=>"wnes");
$fg->new_ttk__label(
	-text => "Field name:",
	-anchor => "w",
)->g_grid(-sticky => "we");
my $combo_g = $fg->new_ttk__combobox(
	-textvariable => \$gene,
	-values => ["No Annotations"],
	-width => 15,
);
$combo_g->g_grid(-sticky=>"we");
$combo_g->current(0);
$combo_g->g_bind("<<ComboboxSelected>>", sub{on_change_combobox()});
my $annot_panel = $fg->new_ttk__frame();
$annot_panel->g_grid(-sticky => "wnes");
my $annot_list = $annot_panel->new_tk__listbox(
	-selectmode => "multiple",
);
$annot_list->g_grid(
	-sticky => "wnes",
	-column => 0,
	-row => 0,
);
my $annot_vsb = $annot_panel->new_ttk__scrollbar(
	-command => [$annot_list, "yview"],
	-orient => "vertical",
);
$annot_vsb->g_grid(
	-column => 1,
	-row => 0,
	-sticky => "ns",
);
my $annot_hsb = $annot_panel->new_ttk__scrollbar(
	-command => [$annot_list, "xview"],
	-orient => "horizontal",
);
$annot_hsb->g_grid(
	-column => 0,
	-row => 1,
	-sticky => "we",
);
$annot_list->configure(
	-yscrollcommand => [$annot_vsb, "set"],
	-xscrollcommand => [$annot_hsb, "set"],
);


$fg->new_ttk__button(
	-text => "Get Sequence",
	-command => sub{get_bat_gene($opdir,$gene)},
)->g_grid(-sticky=>"wnes",-pady=>"5 0");

#status bar
$sb->add($sb->new_ttk__label(-textvariable => \$message,), -weight => 1);
$sb->add($sb->new_ttk__progressbar(
	-orient => 'horizontal', 
	-length => 80,
	-maximum => 1,
	-variable => \$progress,
	-mode => 'determinate'),
);


# weight
$mw->g_grid_columnconfigure(0, -weight => 1);
$mw->g_grid_rowconfigure(1, -weight => 1);
$bf->g_grid_rowconfigure(1, -weight => 1);
$bf->g_grid_columnconfigure(0, -weight => 3);
$bf->g_grid_columnconfigure(1, -weight => 1);
$fl->g_grid_rowconfigure(0, -weight => 1);
$fl->g_grid_columnconfigure(0, -weight => 1);
$ft->g_grid_rowconfigure(2, -weight => 1);
$ft->g_grid_columnconfigure(0, -weight => 1);
$fg->g_grid_rowconfigure(2, -weight => 1);
$fg->g_grid_columnconfigure(0, -weight => 1);
$ff->g_grid_columnconfigure(0, -weight => 1);
$annot_panel->g_grid_rowconfigure(0, -weight => 1);
$annot_panel->g_grid_columnconfigure(0, -weight => 1);


Tkx::MainLoop;

##########################################################
# all functions here
##########################################################
sub on_exit(){
	unlink 'database.db' if -e 'database.db';
	$mw->g_destroy;
}

sub check_paras{
	alert_info("Please add files!") unless $file_num;
	alert_info("Please select output directory!") if $opdir=~/^\s+$/ || $opdir eq "";
	alert_info("Please parse genbank file!");
}
sub alert_info{
    my $mes = shift;
    Tkx::tk___messageBox(-type => "ok", -message => $mes, -icon => "error", -title => "ERROR");
    Tkx::MainLoop;
}
sub run_status{
	my $mes = shift;
	$message = $mes if $mes;
	Tkx::update();
}
sub select_dir{
	my $dir = Tkx::tk___chooseDirectory(
		-initialdir => \$lastoutdir,
	);
	return unless $dir;
	$opdir = encode("gb2312", decode("gb2312", $dir));
	$opdir_display = decode("gb2312", $opdir);
}
sub open_dir{
	my $dir = shift;
	return unless $dir;
	my $_ = $^O;
	if(/win/i){
		system('start'.' "" '.'"'.$opdir.'"');
	}elsif(/linux/i){
		system("nautilus \"$dir\"");
	}elsif(/mac/i){
		system("open \"$dir\"");
	}else{
		alert_info("Can not open directory:$dir");
	}
}
sub count_file_size{
    my $file = shift;
	my $s = -s $file;
	return unless $s;
	$s = sprintf("%dKB", ceil($s/1024));
	return $s;
}
sub insert_to_tree{
	my $file = shift;
	$file = encode("gb2312", $file);
	return unless get_file_format($file);
	return if $file_list->exists($file);
    my $values = get_file_info($file);
    $file_list->insert("", "end", -id => $file, -values => $values);
    $file_list->see($file);
	$file_num++; #number of files add
	$file = decode("gb2312", $file);
	run_status("Add file $file");
}
sub get_file_info{
	my $file = shift;
	my $info = [];
	$info->[0] = basename($file, @formats);
	$info->[1] = count_file_size($file);
	$info->[2] = 'wating';
	return $info;
}
sub get_first_item{
	my $id = $file_list->insert('',0);
	my $next_id = $file_list->next($id);
	$file_list->delete($id);
	return $next_id;
}
sub get_file_format{
	my $file = shift;
	my $flag = 0;
	open FILE, $file;
	while(<FILE>){
		if(/^\s+$/){
			next;
		}
		s/^\s+//;
		if(/^LOCUS/){
			$flag = 1;
		}
		last;
	}
	close FILE;
	return $flag;
}
sub drag_file{
	my $filestr = shift;
	my @files = Tkx::SplitList($filestr);
	while(my $file = shift @files){
		insert_to_tree($file);
	}
}
sub add_files{
    my $filestr = Tkx::tk___getOpenFile(
		-multiple => 1,
		-initialdir => \$lastopendir,
	);
    return unless $filestr;
	my @files = Tkx::SplitList($filestr);
	$lastopendir = dirname($files[0]);
	while(@files){
		my $file = shift @files;
		insert_to_tree($file);
	}
	$reparse = 0;
}
sub add_folder{
	my $folder = Tkx::tk___chooseDirectory(
		-initialdir => \$lastadddir,
	);
    return unless $folder;
	$folder = encode("gb2312", decode("gb2312", $folder));
    sub find_file{
		my $file = $File::Find::name;
        return if -d $file;
		$file = decode("gb2312", $file);
        insert_to_tree($file);
    }
    find(\&find_file, $folder);
    $reparse = 0;
}
sub delete_files{
	my $id = $file_list->selection();
	return unless $id;
	$file_list->delete($id);
	my @ids = Tkx::SplitList($id);
	$file_num -= scalar(@ids);
	if($file_num == 0){
		$combo_f->configure(-values => ["No Features"]);
		$combo_f->current(0);
		$combo_g->configure(-values => ["No Annotations"]);
		$combo_g->current(0);
		$annot_list->delete(0, "end");
	}
	$reparse = 0;
}
sub clear_files{
	return unless $file_num;
	my $ids = $file_list->children("");
    $file_list->delete($ids);
	$file_num = 0;
	$combo_f->configure(-values => ["No Features"]);
	$combo_f->current(0);
	$combo_g->configure(-values => ["No Annotations"]);
	$combo_g->current(0);
	$annot_list->delete(0, "end");
	$reparse = 0;
	run_status("Files: $file_num  Processed: $processed");
}
# read file to memory
sub read_file{
	my $file = shift;
	open FILE, $file;
	my $con=do{local $/; <FILE>};
	close FILE;
	return \$con;
}
# format directory path
sub add_path_line{
	my $path = shift;
	unless($path =~ /.*(\/|\\)$/){
		$path .= '/';
	}
	return $path;
}
# convert genbank file to fasta file

sub get_out_path{
	my($name, $outdir) = @_;
	if($merge_file){
		return "$outdir/$name"
	}
}
sub convert_to_fasta{
	check_paras();
	my $out_dir = add_path_line(shift);
	my $DB = SQLiteDB->new(-database => 'database.db');
	$DB->prepare_execute("SELECT * FROM gs_desc");
	my $OP_HANDLE;
	my $flag = 1; #recreate merge file
	while(my $row = $DB->query_next()){
		if($merge_file){
			if($flag){
				open $OP_HANDLE, ">", $out_dir."GS_Merge_Fasta.fa";
				$flag = 0;
			}
			open $OP_HANDLE, ">>", $out_dir."GS_Merge_Fasta.fa";
		}else{
			open $OP_HANDLE, ">", $out_dir.$row->[2].'.fa';
		}
		print {$OP_HANDLE} ">gi|$row->[4]|ref|$row->[3]| $row->[1]\n";
		print {$OP_HANDLE} format_to_fasta($row->[6]), "\n";
		close $OP_HANDLE;
	}
	run_status("Task complete!");
}
sub get_protein_seq{
	check_paras();
	my $out_dir = add_path_line(shift);
	my $DB = SQLiteDB->new(-database => 'database.db');
	my $ACCESSIONS = $DB->query_column("SELECT accession FROM gs_desc");
	if($merge_file && -e $out_dir."GS_Merge_Protein.fa"){
		unlink $out_dir."GS_Merge_Protein.fa";
	}
	while(my $acc = shift @$ACCESSIONS){
		my $sql = "SELECT gs_annot.aval FROM gs_desc,gs_annot,gs_feat WHERE gs_annot.FID=gs_feat.ID AND gs_desc.accession='$acc' AND gs_feat.GID = gs_desc.ID AND gs_feat.feat='CDS' AND (gs_annot.aname='protein_id' OR gs_annot.aname='translation')";
		$DB->prepare_execute($sql);
		my $OP_HANDLE;
		if($merge_file){
			open $OP_HANDLE, ">>", $out_dir."GS_Merge_Protein.fa";
		}else{
			open $OP_HANDLE, ">", $out_dir.$acc.'_Protein.fa';
		}
		my $protein;
		while(my $row = $DB->query_next()){
			my $pid = $row->[0];
			$row = $DB->query_next();
			my $pseq = $row->[0];
			if($merge_seq){
				$protein .= $pseq;
			}else{
				$protein .= ">$acc $pid ". length($pseq). "\n". format_to_fasta($pseq). "\n";
			}
		}
		if($merge_seq){
			$protein = ">$acc Protein ". length($protein). "\n". format_to_fasta($protein). "\n";
		}
		print {$OP_HANDLE} $protein;
		close $OP_HANDLE;
	}
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

sub refresh_status{
	my $id = get_first_item();
	if($file_list->set($id, 'state') ne 'complete'){
		return;
	}
	my $ids = $file_list->children("");
	foreach(Tkx::SplitList($ids)){
		$file_list->set($_, 'state', 'wating');
	}
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
sub switch_to_single{
	if($is_linux){
		exec("./GenScalpel &") if -e "GenScalpel";
	}else{
		exec("GenScalpel.exe") if -e "GenScalpel.exe";
	}
}

sub batch_parse_genbank{
	return if $file_num==0;
	copy('db/database.db', '.') unless -e 'database.db';
	my $DB = SQLiteDB->new(-database => 'database.db');
	$DB->delete_db_list();
	my $file = get_first_item();
	$processed = 0;
	run_status("Files: $file_num  Parsed: $processed");
	do{
		$file_list->set($file, 'state', 'parsing');
		$file_list->see($file);
		local $/='//';
		open INPUTFILE, $file;
		while(my $content = <INPUTFILE>){
			next if $content =~ /^\s*$/;
			my $hash = ();
			my ($head, $middle, $foot) = split /FEATURES|ORIGIN/, $content;
			undef $content;
			
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
			$foot =~ s/\///g;
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
			$processed++;
			$progress = $processed/$file_num;
			run_status("Files: $file_num  Parsed: $processed");
		}
		close INPUTFILE;
		$file_list->set($file, 'state', 'parsed');
	}while($file = $file_list->next($file));
	$reparse = 1;
	config_combobox($DB);
}

sub config_combobox{
	my $DB = shift;
	my $feats = $DB->query_column("SELECT DISTINCT(feat) FROM gs_feat");
	$combo_f->configure(-values => $feats);
	$combo_f->current(0);
	my $annots = $DB->query_column("SELECT DISTINCT(aname) FROM gs_annot");
	$combo_g->configure(-values => $annots);
	$combo_g->current(0);
	my $aval = $DB->query_column("SELECT DISTINCT(aval) FROM gs_annot WHERE aname='$annots->[0]'");
	$annot_list->delete(0, "end");
	while(my $a = shift @$aval){
		$annot_list->insert("end", $a);
	}
	Tkx::update();
}
sub on_change_combobox{
	$gene =~ s/^\s+|\s+$//g;
	return unless $gene;
	return if $gene eq "No Annotations";
	my $DB = SQLiteDB->new(-database => 'database.db');
	my $aval = $DB->query_column("SELECT DISTINCT(aval) FROM gs_annot WHERE aname='$gene'");
	$annot_list->delete(0, "end");
	while(my $a = shift @$aval){
		$annot_list->insert("end", $a);
	}
	Tkx::update();
}
sub get_bat_seq{
	check_paras();
	my ($out_dir, $feat) = @_;
	return if $feat eq "No Features";
	$out_dir = add_path_line($out_dir);
	my $DB = SQLiteDB->new(-database => 'database.db');
	my $sql = "SELECT gs_desc.accession,gs_desc.sequence,gs_feat.loci FROM gs_feat,gs_desc WHERE gs_desc.ID=gs_feat.GID AND gs_feat.feat='$feat'";
	$DB->prepare_execute($sql);
	my $OP_HANDLE;
	if($merge_file && -e $out_dir."GS_Merge_Feature_$feat.fa"){
		unlink $out_dir."GS_Merge_Feature_$feat.fa";	
	}
	my $content;
	my $prev_acc;
	while(my $row = $DB->query_next()){
		if($prev_acc && $row->[0] ne $prev_acc){
			if($merge_file){
				open $OP_HANDLE, ">>", $out_dir."GS_Merge_Feature_$feat.fa";
			}else{
				open $OP_HANDLE, ">>", $out_dir."$row->[0]_$feat.fa";
			}
			if($merge_seq){
				$content = ">$prev_acc $feat ".length($content)."bp\n".format_to_fasta($content)."\n";
			}
			print {$OP_HANDLE} $content;
			close $OP_HANDLE;
			$content = '';
		}
		my @loci =  split(",", $row->[2]);
		my $seq;
		while(my $locus = shift @loci){
			my ($start, $end) = split("-", $locus);
			$end = $start unless $end;
			$seq .= substr($row->[1], $start-1, $end - $start + 1);
		}
		if($merge_seq){
			$content .= $seq;
		}else{
			$content .= ">$row->[0] $feat $row->[2] ".length($seq)."bp\n".format_to_fasta($seq)."\n";
		}
		$prev_acc = $row->[0];
	}
}
sub get_bat_gene{
	check_paras();
	my ($out_dir, $annot) = @_;
	$out_dir = add_path_line($out_dir);
	my $avals = $annot_list->curselection();
	return if $avals eq '';
	my $DB = SQLiteDB->new(-database => 'database.db');
	my @avals = split(/\s+/, $avals);
	my $OP_HANDLE;
	if($merge_file && -e $out_dir."GS_Merge_$annot.fa"){
		unlink $out_dir."GS_Merge_$annot.fa";
	}
	while(my $a = shift @avals){
		$a = $annot_list->get($a);
		my $sql = "SELECT DISTINCT gs_desc.accession, gs_desc.sequence,gs_feat.loci FROM gs_desc,gs_feat,gs_annot WHERE gs_annot.aname='$annot' AND gs_annot.aval='$a' AND gs_desc.ID=gs_feat.GID AND gs_feat.ID=gs_annot.FID";
		$DB->prepare_execute($sql);
		while(my $row = $DB->query_next()){
			if($merge_file){
				open $OP_HANDLE, ">>", $out_dir."GS_Merge_$annot.fa";
			}else{
				open $OP_HANDLE, ">", $out_dir."$row->[0]_$annot"."_"."$a.fa";
			}
			my @loci = split(',', $row->[2]);
			my $seq;
			while(my $locus = shift @loci){
				my ($start, $end) = split('-', $locus);
				$end = $start unless $end;
				$seq .= substr($row->[1], $start - 1, $end - $start + 1);
			}
			print {$OP_HANDLE} ">$row->[0] $annot $a $row->[2] ", length($seq), "bp\n", format_to_fasta($seq), "\n";
			close $OP_HANDLE;
		}
	}
}