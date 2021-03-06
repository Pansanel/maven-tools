# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;

package Test::Quattor::Doc;

use base qw(Test::Quattor::Object Exporter);
use Test::More;
use Test::Pod;
use Pod::Simple 3.28;
use File::Path qw(mkpath);
use Test::Quattor::Panc qw(panc_annotations);

use Readonly;

Readonly our $DOC_TARGET_PERL => "target/lib/perl";
Readonly our $DOC_TARGET_POD => "target/doc/pod";
Readonly our $DOC_TARGET_PAN => "target/pan";
Readonly our $DOC_TARGET_PANOUT => "target/panannotations";
Readonly::Array our @DOC_TEST_PATHS => ($DOC_TARGET_PERL, $DOC_TARGET_POD);

our @EXPORT = qw($DOC_TARGET_PERL $DOC_TARGET_POD @DOC_TEST_PATHS
                 $DOC_TARGET_PAN $DOC_TARGET_PANOUT);

=pod

=head1 NAME

Test::Quattor::Doc - Class for unittesting documentation.

=head1 DESCRIPTION

This is a class to trigger documentation testing.
Should be used mainly as follows:

    use Test::Quattor::Doc;
    Test::Quattor::Doc->new()->test();

=head2 Public methods

=over

=item new

Returns a new object, accepts the following options

=over

=item poddirs

Array reference of directories to test for podfiles.
Default dirs are the relative paths C<target/lib/perl>
and C<target/doc/pod> (use the exported C<@DOC_TEST_PATHS>
list of defaults or resp. C<$DOC_TARGET_PERL> and <$DOC_TARGET_POD>)

=item podfiles

Array reference of podfiles to test (default empty)

=item panpaths

Array reference of paths that hold pan files to check for annotations.
Default is C<target/pan> (use the exported $DOC_TARGET_PAN).

=item panout

Output path for pan annotations. Default
target/panannotations (use exported $DOC_TARGET_PANOUT).

=back

=cut

sub _initialize
{
    my ($self) = @_;

    $self->{poddirs} = \@DOC_TEST_PATHS if (! defined($self->{poddirs}));
    $self->{podfiles} = [] if (! defined($self->{podfiles}));

    $self->{panpaths} = [$DOC_TARGET_PAN] if (! defined($self->{panpaths}));
    $self->{panout} = $DOC_TARGET_PANOUT if (! defined($self->{panout}));
}


=pod

=item pod_files

Test all files from C<podfiles> and C<poddirs>.
Based on C<all_pod_files_ok> from C<Test::Pod>.

Returns array refs of all ok and not ok files.

=cut

sub pod_files
{
    my $self = shift;

    my @files = @{$self->{podfiles}};
    foreach my $dir (@{$self->{poddirs}}) {
        $self->notok("poddir $dir is not a directory") if ! -d $dir;
        my @fs = all_pod_files($dir);
        # Do not allow empty pod dirs,
        # remove them from the poddirs if they are not relevant
        ok(@fs, "Directory $dir has files");
        push(@files, @fs);
    };

    my (@ok, @not_ok);
    foreach my $file (@files) {
        ok(-f $file, "pod file $file is a file");

        # each pod_file_ok is also a test.
        if(pod_file_ok($file)) {
            push(@ok, $file);
        } else {
            push(@not_ok, $file);
        }
    }

    return \@ok, \@not_ok;
}

=pod

=item pan_annotations

Generate annotations, return arrayref with templates that 
have valid annotations and one for templates with invalid annotations.

TODO: Does not require annotations at all nor validates 
minimal contents.

=cut

sub pan_annotations
{
    my $self = shift;

    mkpath($self->{panout}) if ! -d $self->{panout};
    ok(-d $self->{panout}, "annotations output dir $self->{panout} exists");

    my (@ok, @not_ok);
    foreach my $dir (@{$self->{panpaths}}) {
        my ($okpan, $notok_pan) = $self->gather_pan($dir, $dir, "");
        is(scalar @$notok_pan, 0, "No invalid pan files found in $dir (no namespace checked for annotations)");
        my @templates = keys %$okpan;
        ok(@templates, "Found valid templates in $dir");

        my $ec = panc_annotations($dir, $self->{panout}, \@templates);
        if($ec) {
            $self->notok("panc-annotations ended with ec 0");
            push(@not_ok, @templates);
        } else {
            foreach my $tmpl (@templates) {
                my $anno = "$self->{panout}/$tmpl.annotation.xml";
                if (-f $anno) {
                    push(@ok, $tmpl);
                } else {
                    push(@not_ok, $tmpl);
                }
            }
        }
    }

    return \@ok, \@not_ok;
}

=pod

=item test

Run all tests:
    pod_files
    pan_annotations

=cut

sub test
{
    my ($self) = @_;

    my ($ok, $not_ok) = $self->pod_files();
    is(scalar @$not_ok, 0, "No faulty pod files: ");

    ($ok, $not_ok) = $self->pan_annotations();
    is(scalar @$not_ok, 0, "No faulty pan annotation: ".join(",", @$not_ok));
}

=pod

=back

=cut

1;
