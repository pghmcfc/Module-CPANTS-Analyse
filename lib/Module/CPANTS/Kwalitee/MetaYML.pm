package Module::CPANTS::Kwalitee::MetaYML;
use warnings;
use strict;
use File::Spec::Functions qw(catfile);
use CPAN::Meta::YAML;
use Test::CPAN::Meta::YAML::Version;

our $VERSION = '0.87';

sub order { 20 }

my $CURRENT_SPEC = '1.4';

##################################################################
# Analyse
##################################################################

sub analyse {
    my $class=shift;
    my $me=shift;
    my $files=$me->d->{files_array};
    my $distdir=$me->distdir;
    my $meta_yml=catfile($distdir,'META.yml');
    return unless -f $meta_yml;

    eval {
        open my $fh, '<:utf8', $meta_yml or die $!;
        my $yaml = do { local $/; <$fh> };
        my $meta = CPAN::Meta::YAML->read_string($yaml) or die CPAN::Meta::YAML->errstr;
        $me->d->{meta_yml}=$meta->[0];
        $me->d->{metayml_is_parsable}=1;
    };
    if ($@) {
        $me->d->{error}{metayml_is_parsable}=$@;
        return;
    }

    my $no_index = $me->d->{meta_yml}->{no_index};
    if ($no_index and ref $no_index eq ref {}) {
        my @ignore;
        foreach my $type (qw(file directory)) {
            next unless $no_index->{$type};
            unless (ref $no_index->{$type} eq ref []) {
              # no_index should be a list, though...
              $no_index->{$type} = [$no_index->{$type}];
            }
            foreach (@{$no_index->{$type}}) {
                next if /^x?t/; # won't ignore t, xt
                next if /^lib/; # and lib
                push(@ignore,$_);
            }
        }
        $me->d->{no_index}=join(';',@ignore);
        my @old=@{$me->d->{files_array}};
        my @new; my @ignored;
        foreach my $file (@old) {
            
            # me wants smart match!!!!

            if (grep { $file=~/^$_/ } @ignore) {
                delete $me->d->{files_hash}{$file};
                $me->d->{files}--;
                push(@ignored,$file);
            }
            else {
                push(@new,$file);
            }
        }
        $me->d->{files_array}=\@new;
        $me->d->{ignored_files_array}=\@ignored;
    }

}

##################################################################
# Kwalitee Indicators
##################################################################

sub kwalitee_indicators{
    return [
        {
            name=>'metayml_is_parsable',
            error=>q{The META.yml file of this distributioncould not be parsed by the version of YAML.pm CPANTS is using.},
            remedy=>q{If you don't have one, add a META.yml file. Else, upgrade your YAML generator so it produces valid YAML.},
            code=>sub { shift->{metayml_is_parsable} ? 1 : 0 }
        },
        {
            name=>'metayml_has_license',
            error=>q{This distribution does not have a license defined in META.yml.},
            remedy=>q{Define the license if you are using in Build.PL. If you are using MakeMaker (Makefile.PL) you should upgrade to ExtUtils::MakeMaker version 6.31.},
            code=>sub { 
                my $d=shift;
                my $yaml=$d->{meta_yml};
                ($yaml->{license} and $yaml->{license} ne 'unknown') ? 1 : 0 }
        },
        {
            name=>'metayml_has_provides',
            is_experimental=>1,
            error=>q{This distribution does not have a list of provided modules defined in META.yml.},
            remedy=>q{Add all modules contained in this distribution to the META.yml field 'provides'. Module::Build does this automatically for you.},
            code=>sub { 
                my $d=shift;
                return 1 if $d->{meta_yml} && $d->{meta_yml}{provides};
                return 0;
            },
        },
        {
            name=>'metayml_conforms_to_known_spec',
            error=>q{META.yml does not conform to any recognised META.yml Spec. See 'metayml' in the dist error view for more info.},
            remedy=>q{Take a look at the META.yml Spec at http://module-build.sourceforge.net/META-spec-current.html and change your META.yml accordingly},
            code=>sub {
                my $d=shift;
                return check_spec_conformance($d);
            },
        },
    {
            name=>'metayml_conforms_spec_current',
            is_extra=>1,
            error=>qq{META.yml does not conform to the Current META.yml Spec ($CURRENT_SPEC). See 'metayml' in the dist error view for more info.},
            remedy=>q{Take a look at the META.yml Spec at http://module-build.sourceforge.net/META-spec-current.html and change your META.yml accordingly},
            code=>sub {
                my $d=shift;
                return check_spec_conformance($d,$CURRENT_SPEC,1);
            },
        },
        {
            name=>'metayml_declares_perl_version',
            error=>q{This distribution does not declare the minimum perl version in META.yml.},
            is_extra=>1,
            remedy=>q{If you are using Build.PL define the {requires}{perl} = VERSION field. If you are using MakeMaker (Makefile.PL) you should upgrade ExtUtils::MakeMaker to 6.48 and use MIN_PERL_VERSION parameter. Perl::MinimumVersion can help you determine which version of Perl your module needs.},
            code=>sub { 
                my $d=shift;
                my $yaml=$d->{meta_yml};
                return ref $yaml->{requires} eq ref {} && $yaml->{requires}{perl} ? 1 : 0;
            },
        },
    ];
}

sub check_spec_conformance {
    my ($d,$version,$check_current)=@_;
    
    my $yaml=$d->{meta_yml};
    my %hash=(
        data=>$yaml,	# Interface change in v0.21. Was 'yaml'.
    );

    if (!$version) {
        my $spec = $yaml->{'meta-spec'};
        if (ref $spec eq ref {} && $spec->{version}) {
            $version = $spec->{version};
        }
        else {
            $version='1.0';
        }
    }
    $hash{spec} = $version;
    my $spec = Test::CPAN::Meta::YAML::Version->new(%hash);
    if ($spec->parse()) {
        my $report_version= $version || 'known';
        my @errors;
        foreach my $e ($spec->errors) {
            next if $e=~/specification URL/ && $check_current;
            push @errors,$e;
        }
        if (@errors) {
            my $errorname='metayml_conforms_'.($check_current?'spec_current':'to_known_spec');
            $d->{error}{$errorname} = [$report_version, sort @errors];
            return 0;
        }
    }
    return 1;
}

q{Barbies Favourite record of the moment:
  Nine Inch Nails: Year Zero};

__END__

=encoding UTF-8

=head1 NAME

Module::CPANTS::Kwalitee::MetaYML - Checks data availabe in META.yml

=head1 SYNOPSIS

Checks various pieces of information in META.yml

=head1 DESCRIPTION

=head2 Methods

=head3 order

Defines the order in which Kwalitee tests should be run.

Returns C<11>.

=head3 analyse

C<MCK::MetaYML> checks C<META.yml>.

=head3 kwalitee_indicators

Returns the Kwalitee Indicators datastructure.

=over

=item * metayml_is_parsable

=item * metayml_has_license

=item * metayml_conforms_spec_1_0

=item * metayml_conforms_known_spec

=item * metayml_conforms_spec_current

=item * metayml_declares_perl_version

=back

=head3 check_spec_conformance

    check_spec_conformance($d,$version);

Validates META.yml using Test::CPAN::Meta.

=head1 SEE ALSO

L<Module::CPANTS::Analyse>

=head1 AUTHOR

L<Thomas Klausner|https://metacpan.org/author/domm>
and L<Gábor Szabó|https://metacpan.org/author/szabgab>

=head1 COPYRIGHT AND LICENSE

Copyright © 2003–2009 L<Thomas Klausner|https://metacpan.org/author/domm>

Copyright © 2006–2008 L<Gábor Szabó|https://metacpan.org/author/szabgab>

You may use and distribute this module according to the same terms
that Perl is distributed under.
