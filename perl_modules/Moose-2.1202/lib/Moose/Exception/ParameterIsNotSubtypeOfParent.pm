package Moose::Exception::ParameterIsNotSubtypeOfParent;
BEGIN {
  $Moose::Exception::ParameterIsNotSubtypeOfParent::AUTHORITY = 'cpan:STEVAN';
}
$Moose::Exception::ParameterIsNotSubtypeOfParent::VERSION = '2.1202';
use Moose;
extends 'Moose::Exception';
with 'Moose::Exception::Role::TypeConstraint';

has 'type_parameter' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

sub _build_message {
    my $self = shift;
    my $type_parameter = $self->type_parameter;
    my $parent = $self->type->parent->type_parameter;

    return "$type_parameter is not a subtype of $parent";
}

1;
