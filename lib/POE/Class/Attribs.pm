package POE::Class::Attribs;

use strict;

use Carp;

sub import {
    my $class = shift;
    croak "Arguments to import() must be a hash" if @_ & 1;

    my %opts = @_;

    no strict 'refs';
    my $pkg = caller;
    my %internal_class_data;
    *{$pkg . '::_destroy_internal_data'} = sub {
        croak "Trying to access private data" if caller ne $pkg;
        delete $internal_class_data{$_[0]};
        undef;
    };
    *{$pkg . '::_get_internal_data'} = sub {
        croak "Trying to access private data" if caller ne $pkg;
        return $internal_class_data{$_[0]};
    };
    *{$pkg . '::_init_internal_data'} = sub {
        croak "Trying to access private data" if caller ne $pkg;
        $internal_class_data{$_[0]} ||= {};
    };
    while (my ($key, $value) = each %opts) {
        my $private = $key =~ /^_/;
        my $set = $private ? $pkg . "::_set$key" : $pkg . "::set_$key";
        my $get = $private ? $pkg . "::_get$key" : $pkg . "::get_$key";
        my $setget = $pkg . "::$key";
        if ($private) {
            *$setget = sub {
                croak "Trying to access private data" if caller ne $pkg;
                my $self = shift;
                if (@_) {
                    $self->$set(@_);
                }
                return $self->$get(@_);
            };
            *$set = sub {
                croak "Trying to access private data" if caller ne $pkg;
                $internal_class_data{$_[0]}{$key} = $_[1];
                return $_[0];
            };
        }
        else {
            *$setget = sub {
                my $self = shift;
                if (@_) {
                    $self->$set(@_);
                }
                return $self->$get(@_);
            };
            *$set = sub {
                $internal_class_data{$_[0]}{$key} = $_[1];
                return $_[0];
            };
        }
        if (defined $value) {
            if (ref $value eq 'CODE') {
                if ($private) {
                    *$get = sub {
                        croak "Trying to access private data" if caller ne $pkg;
                        unless (exists $internal_class_data{$_[0]}{$key}) {
                            $internal_class_data{$_[0]}{$key} = $value->(@_);
                        }
                        return $internal_class_data{$_[0]}{$key};
                    };
                }
                else {
                    *$get = sub {
                        unless (exists $internal_class_data{$_[0]}{$key}) {
                            $internal_class_data{$_[0]}{$key} = $value->(@_);
                        }
                        return $internal_class_data{$_[0]}{$key};
                    };
                }
            }
            else {
                if ($private) {
                    *$get = sub {
                        croak "Trying to access private data" if caller ne $pkg;
                        unless (exists $internal_class_data{$_[0]}{$key}) {
                            $internal_class_data{$_[0]}{$key} = $value;
                        }
                        return $internal_class_data{$_[0]}{$key};
                    };
                }
                else {
                    *$get = sub {
                        unless (exists $internal_class_data{$_[0]}{$key}) {
                            $internal_class_data{$_[0]}{$key} = $value;
                        }
                        return $internal_class_data{$_[0]}{$key};
                    };
                }
            }
        }
        else {
            if ($private) {
                *$get = sub {
                    croak "Trying to access private data" if caller ne $pkg;
                    return $internal_class_data{$_[0]}{$key};
                };
            }
            else {
                *$get = sub {
                    return $internal_class_data{$_[0]}{$key};
                };
            }
        }
    }
}

1;

__END__

=head1 DESCRIPTION

POE::Class::Attribs - A module to simplify creation of private instance data
and accessors.

=head1 SYNOPSIS

    package Foo;

    use POE::Class::Attribs
        # no default value
        bar => undef,

        # defaults to "foo"
        baz => "foo",

        # private data
        _bat => "boo";

    # the object reference doesn't matter
    sub new { return bless [], shift }

    package main;

    my $obj = new Foo;

    # set
    $obj->set_baz("foo");

    # get
    print $obj->get_baz, "\n";

    # set or get
    $obj->baz("bar");


    package main;

    # will fatal
    $obj->_get_bat;

=head1 DESCRIPTION

POE::Class::Attribs provides a simple interface to create attribute functions.
It does not require the object to be a reference to a specific type of data as
it does not store any information in the object.

=head1 USAGE

POE::Class::Attribs exports three private functions into your namespace by
default.

=over

=item _init_internal_data

This should be called in you constructor method with the object as the
argument. It sets up the default storage hash reference for your object. It
doesn't matter if this is called multiple times.

    sub new {
        my $class = shift;
        my $self = $class->SUPER::new(@_);
        _init_internal_data($self);
    }

=item _destroy_internal_data

This function needs to be called when you which to destroy the data stored for
your object, usually in DESTROY. It takes the object at the only argument.
Failing to call this function will result in memory leaks.

    sub DESTROY {
        my $self = shift;
        $self->SUPER::DESTROY;
        _destroy_internal_data($self);
    }

=item _get_internal_data

This function can be used to get a reference to the hash that stores your
objects data. You can use this to define more complex accessor methods. For
example:

    sub get_array {
        my $data = _get_internal_data(shift);
        $data->{array} ||= [];
        return wantarray ? @{$data->{array}} : $data->{array};
    }

=back

C<import()> takes a hash of key value pairs. Keys are the names of set/get
attributes you wish created. The values, if defined, are the defaults those
methods will use when it is not set. For each key three methods are exported
to your name space.

METHOD is the key name.

=over

=item set_METHOD

This is only usable to set the attributes value. It returns the object that was
passed in so you can do chaining of sets if you want.

=item get_METHOD

Sets the attribute to the default value if it has not been set yet and returns
it.

=item METHOD

This is set/get. If any arguments are passed it calles C<set_METHOD()>. It then
returns C<get_METHOD()>.

=back

For private attributes (attributes that begin with an underscore) the names of the set
and get methods are slightly different. For example:

    use POE::Class::Attribs _bar => "foo";

you would have the methods:

    _set_bar

    _get_bar

    _bar

The main purpose for this is aesthetics.

Private accessors check C<caller()> to make sure packages other than your own
do not call these methods.

=head1 TODO

Write better documentation.

=head1 AUTHOR

Scott Beck E<lt>sbeck@gossamer-threads.comE<gt>

=cut


