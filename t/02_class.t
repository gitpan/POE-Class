#!/usr/bin/perl

use POE;

use Test::More tests => 27;

BEGIN { use_ok('POE::Class') }
require_ok('POE::Class');

my %Called;

package Foo;

use strict;
use POE;
import Test::More;

@Foo::ISA = qw(POE::Class);

sub create_states {
    $Called{create_states} = 1;
    my $self = shift;
    ok(@_ == 0, 'No extra arguments passed to create_states()');
    ok($self->can('SUPER::create_states'), 'SUPER::create_states exists');
    for (qw/check_post check_call check_signal check_post_parent check_child/) {
        $poe_kernel->state($_ => $self, "handler_$_");
    }
    $poe_kernel->sig(foo => 'check_signal');
}

sub handler_start {
    $_[OBJECT]->SUPER::handler_start(@_[1 .. $#_]);
    $Called{start} = 1;
    my $obj = Bar->new(alias => 'Bar');
    $obj->start;
    $_[KERNEL]->yield(check_child => $obj);
    $_[OBJECT]->post('check_post');
    $_[OBJECT]->call('check_call');
    $_[OBJECT]->signal('foo');
    $_[KERNEL]->yield('shutdown');
}

sub handler_check_child {
    my @children = $_[OBJECT]->get_child_objects();
    ok($_[ARG0] == $children[0], 'children tracked');
}

sub handler_check_post {
    $Called{post} = 1;
}

sub handler_check_call {
    $Called{call} = 1;
}

sub handler_check_signal {
    $Called{signal} = 1;
    $_[KERNEL]->sig_handled;
}

sub handler_check_post_parent {
    $Called{post_parent} = 1;
}

sub handler_stop {
    $Called{stop} = 1;
    $_[OBJECT]->SUPER::handler_stop(@_[1 .. $#_]);
}

sub handler_child {
    $Called{child} = 1;
    $_[OBJECT]->SUPER::handler_child(@_[1 .. $#_]);
    if ($_[ARG0] eq 'lose') {
        my @children = $_[OBJECT]->get_child_objects;
        is(scalar(@children), 0, 'children being removed');
    }
}

sub handler_shutdown {
    $Called{shutdown} = 1;
    $_[OBJECT]->SUPER::handler_shutdown(@_[1 .. $#_]);
    ok($_[OBJECT]->get_shutdown, 'handler_shutdown() set shutdown flag');
    $_[OBJECT]->post_children('shutdown');
}

# XXX check this
sub handler_parent {
    $Called{parent} = 1;
    $_[OBJECT]->SUPER::handler_parent(@_[1 .. $#_]);
}

package Bar;

use strict;
use POE;
import Test::More;

@Bar::ISA = qw(POE::Class);

sub handler_start {
    $Called{child_start} = 1;
    $_[OBJECT]->SUPER::handler_start(@_[1 .. $#_]);
    isa_ok($_[OBJECT]->get_parent_object, 'Foo', 'handler_start() set parent correctly');
    isa_ok($_[OBJECT]->get_session, 'POE::Session', 'handler_start() set session correctly');
    is($_[OBJECT]->get_alias, 'Bar', 'Alias was stored');
    $_[OBJECT]->post_parent('check_post_parent');
    ok(defined $_[KERNEL]->alias_resolve('Bar'), 'handler_start() created our alias');
}

sub handler_shutdown {
    $Called{child_shutdown} = 1;
    $_[OBJECT]->SUPER::handler_shutdown(@_[1 .. $#_]);
    $_[KERNEL]->alias_remove('Bar');
}

package main;

use strict;

use POE;
import Test::More;

my $obj = Foo->new;
isa_ok($obj, 'POE::Class');

can_ok($obj, qw(
    handler_start
    handler_stop
    handler_shutdown
    handler_child
    handler_parent

    DESTROY
    create_states
    start
    configure
    resolve_session
    post_children
    post_parent
    ID
    get_child_objects

    post
    call
    signal
    refcount_increment
    refcount_decrement
));

ok(defined $obj->ID, 'objects ID is defined');
ok($obj->ID =~ /^\d+$/, 'object id is a number');

my $session = $obj->start;
ok(defined $session, 'start() returned a defined value');

$poe_kernel->run;

ok(exists $Called{create_states}, 'create_states() called');
for (qw/start stop child shutdown/) {
    ok(exists $Called{$_}, "handler_$_() called");
}

ok(exists $Called{child_start}, 'handler_start() called in child session');
ok(exists $Called{child_shutdown}, 'handler_shutdown() called in child');

for (qw/post call signal post_parent/) {
    ok(exists $Called{$_}, "$_ method works");
}

