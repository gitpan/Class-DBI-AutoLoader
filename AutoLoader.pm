package Class::DBI::AutoLoader;

use strict;
use warnings;
use DBI;

our $VERSION = '0.08';

sub import {
	my $self = shift;
	my $args = { @_ };
	
	my $dbh = DBI->connect($args->{dsn},$args->{username},$args->{password})
		or die "Couldn't establish connection to database via $args->{dsn}: $DBI::errstr";
	
	# Fetch the driver
	my ($driver) = $args->{dsn} =~ m|^dbi:(.*?):.*$|;
	
	# Generate the classes
	foreach my $table ($dbh->tables) {
		generateClass($table,$driver,$args);
	}
	$dbh->disconnect;
}

sub table2class {
	my ($table) = @_;
	
	$table = ucfirst($table);
	$table = join('', map { ucfirst($_) } split(/[^a-zA-Z0-9]/, $table));
	
	return $table;
}

sub generateClass {
	my($table,$driver,$args) = @_;
	my $package = $args->{namespace} . '::' . table2class($table);
	
	my $class = "package $package;";
	$class   .= "use strict;";
	$class   .= "use vars '\@ISA';";
	$class   .= "\@ISA = ('Class::DBI::$driver');";
	$class   .= "require Class::DBI::$driver;";
	foreach my $add_pkg (@{ $args->{additional_packages} }) {
		$class .= "use $add_pkg;";
	}
	$class   .= "__PACKAGE__->set_db('Main',";
	$class   .= "   '$args->{dsn}',";
	$class   .= "   '$args->{username}',";
	$class   .= "   '$args->{password}',";
	$class   .= "   {";
	$class   .= join(',', map {"$_ => '$args->{options}->{$_}'"} keys %{$args->{options}});
	$class   .= "   });";
	$class   .= "__PACKAGE__->set_up_table('$table');";
	$class   .= "1;";
	
	eval($class);
	if(my $error = $@) {
		warn "An error occurred generating $package: $error";
	}
}

1;

=head1 NAME

Class::DBI::AutoLoader - Generates Class::DBI subclasses dynamically.

=head1 SYNOPSIS

  use Class::DBI::AutoLoader (
  	dsn       => 'dbi:mysql:database',
  	username  => 'username',
  	password  => 'passw0rd',
  	options   => { RaiseError => 1 },
  	namespace => 'Data'
  );
  
  my $row = Data::FavoriteFilms->retrieve(1);

=head1 DESCRIPTION

Class::DBI::AutoLoader scans the tables in a given database,
and auto-generates the Class::DBI classes. These are loaded into
your package when you import Class::DBI::AutoLoader, as though
you had created the Data::FavoriteFilms class and "use"d that
directly.

=head1 NOTE

Class::DBI::AutoLoader messes with your table names to make them
look more like regular class names. Specifically it turns table_name
into TableName. The actual function is just:

 $table = join('', map { ucfirst($_) } split(/[^a-zA-Z0-9]/, $table));

=head1 WARNING

I haven't tested this with any database but MySQL. Let me know if you 
use it with PostgreSQL or SQLite. Success or failure.

=head1 OPTIONS

Options that can be used in the import:

=over 4

=item * dsn

The standard DBI style DSN that you always pass.

=item * username

The username for the database.

=item * password

The password for the database.

=item * options

A hashref of options such as you'd pass to the DBI->connect() method.
This can contain any option that is valid for your database.

=item * namespace

The master namespace you would like your packages declared in. See the
example above.

=item * additional_packages

An array reference of additional packages you would like each class to "use".
For example:

 use Class::DBI::AutoLoader (
 	...
 	additional_packages => ['Class::DBI::AbstractSearch']
 );

This allows you to use Class::DBI plugins or other assorted goodies in the
generated class.

=back

=head1 SUPPORTED DATABASES

Currently this module supports MySQL, PostgreSQL, and SQLite.

=head1 TIPS AND TRICKS

=head2 USE ADDITIONAL_PACKAGES

Class::DBI::AbstractSearch is extremely useful for doing any kind of complex
query. Use it like this:

 use Class::DBI::AutoLoader (
 	...
 	additional_packages => ['Class::DBI::AbstractSearch']
 );
 
 my @records = MyDBI::Table->search_where( fname => ['me','you','another'] );

Please see L<Class::DBI::AbstractSearch> for full details

=head2 USE IN MOD_PERL

Put your use Class::DBI::AutoLoader(...) call in your startup.pl file. Then
all your mod_perl packages can use the generated classes directly.

=head2 WRAP IT IN A SUBCLASS

You probably want to wrap this in a subclass so you don't have to go through
all of the dsn, user, blah blah everytime you use it. Additionally, you can
put any __PACKAGE__->set_sql(...) type stuff in your subclass. That's helpful
since you can't edit the generated classes.

=head1 SEE ALSO

L<Class::DBI>, L<Class::DBI::mysql>, L<Class::DBI::Pg>, L<Class::DBI::SQLite>

=head1 AUTHOR

Ryan Parr, E<lt>ryanparr@thejamescompany.comE<gt>

This software is based off the original work performed by
Ikebe Tomohiro on the Class::DBI::Loader module.

=head1 COPYRIGHT AND LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
