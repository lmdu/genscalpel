package SQLiteDB;
require Exporter;
@ISA = qw (Exporter);
use strict;
use DBI;
sub new{
	my $type = shift;
	my %parm = @_;
	my $this = {};
	$this->{'db'} = $parm{'-database'};
	bless $this;
	my $rv = $this->connect_to_db();
	return $rv if $rv;
	return $this;
}
# connect to sqlite database.
sub connect_to_db{
	my $self = shift;
	my $db_file = $self->{db};
	$self->{dbh} = DBI->connect("dbi:SQLite:dbname=$db_file",'','', {AutoCommit => 0});
	return $self->{dbh}->errstr unless $self->{dbh};
	$self->{dbh}->{LongTruncOk} = 'True';
	$self->{dbh}->{LongReadLen} = 1000;
	$self->{sth} = $self->{dbh}->prepare("PRAGMA synchronous = OFF");
	$self->{sth}->execute;
	return 0; # return 0 if connected.
}
#disconnect to sqlite database.
sub disconnect_to_db{
	my $self = shift;
	$self->{dbh}->commit;
	$self->{dbh}->disconnect;
}
sub add_hash_to_db{
	my $self = shift;
	my ($field_values, $table) = @_;
	my @fields = sort keys %$field_values;
	my @values = @{$field_values}{@fields};
	my $sql=sprintf "insert into %s (%s) values (%s)", $table,join(',', @fields), join(',', ("?")x@fields);
	$self->{sth} = $self->{dbh}->prepare($sql);
	$self->{sth}->execute(@values);
	return $self->{dbh}->last_insert_id(undef, undef, $table, 'ID');
}
sub delete_db_list{
	my $self = shift;
	foreach (qw/gs_desc gs_feat gs_annot/){
		$self->prepare_execute("DELETE FROM $_");
	}
}
sub query_row{
	my ($self, $sql) = @_;
	my @row = $self->{dbh}->selectrow_array($sql);
	return @row;
}
sub query_row_hash{
	my ($self, $sql) = @_;
	my $ref = $self->{dbh}->selectrow_hashref($sql);
	return $ref;
}
sub query_column{
	my ($self, $sql) = @_;
	my $ref = $self->{dbh}->selectcol_arrayref($sql);
	return $ref;
}
sub prepare_execute{
	my ($self, $sql) = @_;
	$self->{sth} = $self->{dbh}->prepare($sql);
	$self->{sth}->execute();
}
sub query_next{
	my ($self) = @_;
	return $self->{sth}->fetchrow_arrayref();
}
sub query_array_row{
	my ($self, $sql) = @_;
	my $ref = $self->{dbh}->selectall_arrayref($sql);
	return $ref;
}
sub get_tables{
	my $self = shift;
	my @tables = $self->{dbh}->tables(undef,undef,undef,"TABLE");
	map { s/"main"."(\w+)"/\1/ } @tables;
	return @tables;
}
sub DESTROY{
	my $self = shift;
	$self->disconnect_to_db();
}