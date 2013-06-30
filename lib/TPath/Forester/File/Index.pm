package TPath::Forester::File::Index;

# ABSTRACT: index used by L<TPath::Forester::File>

=head1 DESCRIPTION

Since L<TPath::Forester::File::Node> objects know their own parents, this index
mostly just delegates to their methods.

=cut

use Moose;

extends 'TPath::Index';

sub is_root { $_[1]->is_root }

sub index { }

sub parent { $_[1]->parent }

sub id { }

__PACKAGE__->meta->make_immutable;

1;
