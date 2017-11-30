package Koha::Plugin::Com::ByWaterSolutions::CSV2MARC;

## It's good practive to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use MARC::Batch;
use MARC::Record;
use Text::CSV;

## Here we set our plugin version
our $VERSION = "{VERSION}";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'CSV2MARC plugin',
    author          => 'Kyle M Hall',
    description     => 'Import CSV File as MARC records',
    date_authored   => '2015-05-29',
    date_updated    => '2015-05-29',
    minimum_version => '3.20',
    maximum_version => undef,
    version         => $VERSION,
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

## The existiance of a 'to_marc' subroutine means the plugin is capable
## of converting some type of file to MARC for use from the stage records
## for import tool
##
## This example takes a text file of the arbtrary format:
## First name:Middle initial:Last name:Year of birth:Title
## and converts each line to a very very basic MARC record
sub to_marc {
    my ( $self, $args ) = @_;

    my $mapping;
    eval { $mapping = YAML::Load( $self->retrieve_data('mapping') . "\n\n" ); };
    die($@) if $@;

    my $csv = Text::CSV->new()    # should set binary attribute.
      or die "Cannot use CSV: " . Text::CSV->error_diag();

    my @lines = split(/\n/, $args->{data} );

    my $batch = q{};
    foreach my $line ( @lines ) {
        my $record = MARC::Record->new();

        $csv->parse($line);
        my @columns = $csv->fields();
        my $row = \@columns;

        foreach my $field_name ( keys %$mapping ) {
            my $subfield_data = $mapping->{$field_name};

            my $subfields;
            map { $subfields->{ $_->{subfield} } = $row->[ $_->{column} ] } @$subfield_data;

            my $field = MARC::Field->new(
                $field_name, ' ', ' ',    #TODO add indicator support
                %$subfields
            );

            $record->append_fields($field);
        }

        $batch .= $record->as_usmarc() . "\x1D";
    }

    return $batch;
}

## If your tool is complicated enough to needs it's own setting/configuration
## you will want to add a 'configure' method to your plugin like so.
## Here I am throwing all the logic into the 'configure' method, but it could
## be split up like the 'report' method is.
sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template( { file => 'configure.tt' } );

        ## Grab the values we already have for our settings, if any exist
        $template->param( mapping => $self->retrieve_data('mapping'), );

        print $cgi->header();
        print $template->output();
    }
    else {
        $self->store_data(
            {
                mapping            => $cgi->param('mapping'),
                last_configured_by => C4::Context->userenv->{'number'},
            }
        );

        my $error = q{};
        my $yaml  = $cgi->param('mapping') . "\n\n";
        if ( $yaml =~ /\S/ ) {
            my $mapping;
            eval { $mapping = YAML::Load($yaml); };
            my $error = $@;
            if ($error) {
                my $template = $self->get_template( { file => 'configure.tt' } );
                $template->param(
                    error   => $error,
                    mapping => $self->retrieve_data('mapping'),
                );
                print $cgi->header();
                print $template->output();
            }
            else {
                $self->go_home();
            }
        }
    }
}

## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
sub install() {
    my ( $self, $args ) = @_;

    return 1;
}

## This method will be run just before the plugin files are deleted
## when a plugin is uninstalled. It is good practice to clean up
## after ourselves!
sub uninstall() {
    my ( $self, $args ) = @_;
}

1;
