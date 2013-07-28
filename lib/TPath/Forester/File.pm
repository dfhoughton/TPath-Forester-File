package TPath::Forester::File;

# ABSTRACT: L<TPath::Forester> that understands file systems

$TPath::Forester::File::VERSION ||= .001; # Dist::Zilla will automatically update this
                                                                                
use v5.10;
use Moose;
use Moose::Exporter;
use namespace::autoclean;

use Module::Load::Conditional qw(can_load);
use TPath::Forester::File::Node;
use TPath::Forester::File::Index;

with
  'TPath::Forester' => { -excludes => [qw(wrap index)] },
  'TPath::Forester::File::Attributes';

Moose::Exporter->setup_import_methods( as_is => [ tff => \&tff ], );

=method children

A file's children are the files it contains, if any. Links are regarded as having no children
even if they are directory links.

=cut

sub children { my ( $self, $n ) = @_; @{ $n->children } }

=method tag

A file's "tag" is its name.

=cut

sub tag { my ( $self, $n ) = @_; $n->name }

#sub id { my ( $self, $n )   = @_; $n->attribute('id') }

=attr encoding_detector

A code reference that when given a L<TPath::Forester::File::Node> will return a
guess as to its encoding, or some false value if it cannot hazard a guess. If
no value is set for this attribute, the forester will attempt to construct one
using L<Encode::Detect::Detector>. If this proves impossible, it will provide
a detector that never guesses. If you wish the latter -- just go with the system's
default encoding -- set C<encoding_detector> to C<undef>.

B<Note>, if you have a non-trivial encoding detector and you wish to access a file's
text, you will end up reading the file's contents twice. If you want to save this
expense and take your chances with the encoding, explicity set C<encoding_detector> to
C<undef>.

=cut

has encoding_detector => ( is => 'ro', isa => 'CodeRef' );

around BUILDARGS => sub {
    my ( $orig, $class, %params ) = @_;
    unless ( exists $params{encoding_detector} ) {
        state $can =
          can_load( modules => { 'Encode::Detect::Detector' => undef } );
        if ($can) {
            require Encode::Detect::Detector;
            state $detector = Encode::Detect::Detector->new;
            $params{encoding_detector} = sub {
                my $n = shift;
                return unless $n;
                my $data = $n->octets;
                return unless $data;
                $detector->handle($data);
                $detector->eof;
                my $cs = $detector->getresult;
                $detector->reset;
                return $cs;
            };
        }
    }
    unless ( defined $params{encoding_detector} ) {
        $params{encoding_detector} = sub { return };
    }
    $class->$orig(%params);
};

sub BUILD { $_[0]->_node_type('TPath::Forester::File::Node') }

has roots => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
    writer  => '_roots'
);

=method clean

C<clean> purges all cached information about the
file system. Because nodes only know their parents through weak references. If
you clean the cache, all ancestor nodes which are not themselves descendants of
some other node whose reference is still retained will be garbage collected.

TODO: explain the necessity of this method.

=cut

sub clean { shift->_roots( {} ) }

# coercion mechanism that turns strings into TPath::Forester::Ref::Node objects
sub wrap {
    my ( $self, $n ) = @_;
    return $n if blessed($n) && $n->isa('TPath::Forester::Ref::Node');
    if ( -e $n ) {
        $n = Cwd::realpath($n);

        # for now we ignore the volume
        my ( $volume, $directories, $file ) = File::Spec->splitpath($n);
        if ($file) {
            my $p = $self->wrap($directories);
            return $p->_find_child($file);
        }
        else {
            my $root = $self->roots->{$volume};
            unless ($root) {
                $root = TPath::Forester::File::Node->new(
                    name              => File::Spec->rootdir,
                    real              => 1,
                    parent            => undef,
                    volume            => $volume,
                    encoding_detector => $self->encoding_detector,
                );
                $self->roots->{$volume} = $root;
            }
            return $root;
        }
    }
    else {
        return TPath::Forester::File::Node->new(
            name              => $n,
            real              => 0,
            encoding_detector => $self->encoding_detector,
            parent            => undef
        );
    }
}

=func tfr

Returns singleton C<TPath::Forester::File>. This function has an empty prototype, so
it may be used like a scalar.

  # collect all the text files under the first argument
  my @files = tff->path('//@txt')->select(shift);

=cut

sub tff() { state $singleton = TPath::Forester::File->new }

sub index {
    my $self = shift;
    state $idx = TPath::Forester::File::Index->new(
        f         => $self,
        root      => File::Spec->rootdir,
        node_type => $self->node_type
    );
}

__PACKAGE__->meta->make_immutable;

1;
