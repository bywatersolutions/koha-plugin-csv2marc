package Koha::Plugin::Com::ByWaterSolutions::CSV2MARC;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use JSON;
use MARC::Batch;
use MARC::Record;
use Text::CSV;
use YAML;

our $VERSION = "{VERSION}";

our $metadata = {
    name            => 'CSV2MARC plugin',
    author          => 'Kyle M Hall',
    description     => 'Import CSV File as MARC records',
    date_authored   => '2015-05-29',
    date_updated    => '2024-10-16',
    minimum_version => '24.05',
    maximum_version => undef,
    version         => $VERSION,
};

our $fixed_length_size = {
    '000' => 24,
    '006' => 18,
    '008' => 40
};

our $fixed_length_empty = {
    '000' => ' 'x$fixed_length_size->{'000'},
    '006' => ' 'x$fixed_length_size->{'006'},
    '008' => ' 'x$fixed_length_size->{'008'}
};

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    my $self = $class->SUPER::new($args);

    return $self;
}

sub to_marc {
    my ( $self, $args ) = @_;

    my $mappings;
    eval { $mappings = YAML::Load( $self->retrieve_data('mapping') . "\n\n" ); };
    die($@) if $@;

    my $csv = Text::CSV->new({ binary => 1 }) # binary to support characters above 0x7e (tilde)
      or die "Cannot use CSV: " . Text::CSV->error_diag();

    my @lines = split(/\n/, $args->{data} );

    my $batch = q{};
    foreach my $line ( @lines ) {
        $line =~ s/[\r\n]+$//; # Remove remaining line separators
            
        my $record = MARC::Record->new();

        $csv->parse($line);
        my @columns = $csv->fields();
        my $row = \@columns;

        my @fields;

        foreach my $field_name ( keys %$mappings ) {

            # Read the mappings
            my $subfield_data = $mappings->{$field_name};

            if ( $field_name =~ m/(?<field_name>\d\d\d)_.*/ ) {
                # multiple occurences use case, fix the field name
                $field_name = $+{field_name};
            }

            if ( $field_name + 0 < 10 ) {
                # control field
                my $control_field = $self->_handle_control_field( $field_name, $subfield_data, $row );
                if ( $field_name + 0 > 0 ) {
                    # not the leader
                    push @fields, MARC::Field->new( $field_name, $control_field )
                        if $control_field;
                }
                else {
                    # the leader
                    $record->leader( $control_field )
                        if $control_field;
                }
            }
            else {

                my $ind1 = ' ';
                my $ind2 = ' ';

                my @subfields;
                my $required_subfield_missing = 0;

                foreach my $mapping ( @{$subfield_data} ) {

                    if ( exists $mapping->{indicator} ) {
                        $ind1 = $row->[ $mapping->{column} ]
                            if $mapping->{indicator} == 1;
                        $ind2 = $row->[ $mapping->{column} ]
                            if $mapping->{indicator} == 2;
                    }
                    else {
                        if ( exists $mapping->{subfield} && $row->[ $mapping->{column} ] ne '' ) {
                            push @subfields, $mapping->{subfield} => $row->[ $mapping->{column} ];
                        }
                        else {
                            if ( exists $mapping->{required} and $mapping->{required} ) {
                                # subfield marked as required is missing or empty
                                # let the code know this field needs to be skipped
                                $required_subfield_missing = 1;
                                # stop processing the field
                                last;
                            }
                        }
                    }
                }

                unless ( $required_subfield_missing ) {
                    # there's no required field missing. this
                    # catches partially created records (with some subfields)
                    push @fields, MARC::Field->new( $field_name, $ind1, $ind2, @subfields )
                        if @subfields;
                }
            }
        }

        $record->insert_fields_ordered(@fields);

        $batch .= $record->as_usmarc() . "\x1D";
    }

    return $batch;
}

sub _handle_control_field {
    my ( $self, $tag, $tag_mapping, $row ) = @_;

    my $basis = $fixed_length_empty->{$tag} // q{};

    # look for a basis
    foreach my $mapping ( @{$tag_mapping} ) {
        # no 'position', then assume is the basis to work on
        if ( !exists $mapping->{position} ) {
            $basis = $row->[ $mapping->{column} ];
            last;
        }
    }

    # apply offsets
    foreach my $mapping ( @{$tag_mapping} ) {
        # no 'position', then assume is the basis to work on
        if (exists $mapping->{position} ) {
            my $offset = $mapping->{position};
            my $offset_value = $row->[ $mapping->{column} ];
            substr( $basis, $offset, length($offset_value) ) = $offset_value;
        }
    }

    return $basis;
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $op = $cgi->param('op');

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template( { file => 'configure.tt' } );

        ## Grab the values we already have for our settings, if any exist
        $template->param( mapping => $self->retrieve_data('mapping'), );

        print $cgi->header();
        print $template->output();
    }
    elsif( $op eq 'cud-update-config' ) {
        $self->store_data(
            {
                mapping            => scalar $cgi->param('mapping'),
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

sub static_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('staticapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub api_namespace {
    my ($self) = @_;

    return 'csv2marc';
}

1;
