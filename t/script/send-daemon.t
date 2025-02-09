#!/usr/bin/env perl
#
# send-daemon.t
# FixMyStreet test for reports- and updates-sending daemon.

use warnings;
use v5.14;

use Class::Accessor::Fast;
use Test::MockModule;
use FixMyStreet::Script::SendDaemon;
use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;
my $body = $mech->create_body_ok(2514, 'Birmingham');
$mech->create_contact_ok(email => 'g@example.org', category => 'Graffiti', body => $body);
my ($p) = $mech->create_problems_for_body(1, $body->id, 'Title', { category => 'Graffiti', state => 'unconfirmed' });

package TestObj;
use base 'Class::Accessor::Fast';
TestObj->mk_ro_accessors(qw(debug verbose nomail));
package main;

my $opts = TestObj->new({ debug => 0, verbose => 0, nomail => 0 });
FixMyStreet::Script::SendDaemon::setverboselevel(-1); # Nothing

subtest 'Unconfirmed reports ignored' => sub {
    FixMyStreet::Script::SendDaemon::look_for_report($opts);
    $p->discard_changes;
    is $p->send_state, 'unprocessed';
    is $p->send_fail_count, 0;
};

$p->update({ state => 'confirmed' });

subtest 'Error in sending caught okay' => sub {
    my $mock = Test::MockModule->new('FixMyStreet::Cobrand::Default');
    $mock->mock('find_closest', sub {
        die q[Can't use string ("<h1>Server Error (500)</h1>")]
        . q[ as a HASH ref while "strict refs" in use ]
    });

    FixMyStreet::Script::SendDaemon::look_for_report($opts);

    # check that problem has send fail count > 0 etc.
    $p->discard_changes;
    is $p->send_fail_count, 1;
    is $p->send_state, 'unprocessed';
};

subtest 'Normal sending works' => sub {
    $p->update({ send_fail_count => 0 });
    is $p->whensent, undef;
    FixMyStreet::Script::SendDaemon::look_for_report($opts);
    $p->discard_changes;
    isnt $p->whensent, undef;
    is $p->send_state, 'sent';
};

done_testing;
