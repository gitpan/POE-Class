#!/usr/bin/perl

package My::Foo;
use Carp;

use Test::More tests => 19;

use POE::Class::Attribs
    bar   => undef,
    bar1  => 'foo',
    bar2  => sub { 2 },
    _boo  => undef,
    _boo1 => 'foo',
    _boo2 => sub { 3 };


my $obj = bless {}, __PACKAGE__;

_init_internal_data($obj);

my $data = _get_internal_data($obj);
ok(ref($data) eq 'HASH', "default private data");

ok(!defined $obj->get_bar, 'no default for public');
ok(!defined $obj->_get_boo, 'no default for private');

is($obj->get_bar1, 'foo', 'default for public');
is($obj->_get_boo1, 'foo', 'default for private');

is($obj->get_bar2, 2, 'default code for public');
is($obj->_get_boo2, 3, 'default code for private');

$obj->set_bar("foo");
is($obj->get_bar, 'foo', 'set not defaulted for public');
$obj->_set_boo("foo");
is($obj->_get_boo, 'foo', 'set not defaulted for private');

$obj->set_bar1("boo");
is($obj->get_bar1, 'boo', 'set defaulted for public');
$obj->_set_boo1("boo");
is($obj->_get_boo1, 'boo', 'set defaulted for private');

$obj->set_bar2("goo");
is($obj->get_bar2, 'goo', 'set code ref defaulted for public');
$obj->_set_boo2("goo");
is($obj->_get_boo2, 'goo', 'set code ref defaulted for private');

package My::Bar;

import Test::More;

isnt(eval { My::Foo::_init_internal_data($obj); 1 }, 1, '_init_private_data is private');
isnt(eval { My::Foo::_destroy_internal_data($obj); 1 }, 1, '_init_destroy_data is private');
isnt(eval { My::Foo::_get_internal_data($obj); 1 }, 1, '_init_get_data is private');

isnt(eval { $obj->_get_boo; 1 }, 1, 'get not defaulted is private');
isnt(eval { $obj->_get_boo1; 1 }, 1, 'get defaulted is private');
isnt(eval { $obj->_get_boo3; 1 }, 1, 'get code ref defaulted is private');


