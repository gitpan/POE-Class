#!/usr/bin/perl

use lib '../lib';

package Foo;


use strict;

use POE qw(Class);
@Foo::ISA = qw(POE::Class);

use constant DEPTH_START => 1;
use constant DEPTH_STOP  => 4;
use constant CHILDREN    => 3;

use POE::Class::Attribs depth => 1;

my $num_sessions = 0;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    _init_internal_data($self);
    return $self;
}

sub DESTROY {
    my $self = shift;
    $self->SUPER::DESTROY;
    _destroy_internal_data($self);
}

sub handler_start {
    my $self = $_[OBJECT];
    $num_sessions++;
    $self->SUPER::handler_start(@_[1 .. $#_]);

    my $depth = $self->get_depth;
    if ($depth == DEPTH_STOP) {
        return;
    }
    for (1 .. CHILDREN) {
        Foo->new(
            depth => $depth + 1,
            alias => "Child$num_sessions",
        )->start;
    }
    if ($depth == 1) {
        $self->dump_hierarchy(DEPTH_START);
        $self->post('shutdown');
    }
}

sub handler_shutdown {
    my $self = $_[OBJECT];
    $self->SUPER::handler_shutdown(@_[1 .. $#_]);
    $self->post_children('shutdown');
}

my @indent;
sub dump_hierarchy {
    my ($self, $last) = @_;
    my $depth = $self->get_depth;
    print join "", @indent;
    if ($last) {
        push @indent, "    ";
        print "`-- ";
    }
    else {
        push @indent, "|   ";
        print "|-- ";
    }
    my $parent = $self->get_parent_object;
    if ($parent) {
        printf "%s:%d - %s:%d\n",
            $self->get_alias,
            $self->ID,
            $parent->get_alias,
            $parent->ID;
    }
    else {
        printf "%s:%d\n", $self->get_alias, $self->ID;
    }
    my @children = $self->get_child_objects;
    if (@children) {
        for (0 .. $#children - 1) {
            $children[$_]->dump_hierarchy;
        }
        $children[-1]->dump_hierarchy(1);
    }
    pop @indent;
}

Foo->new(alias => 'Top')->start;

$poe_kernel->run;

