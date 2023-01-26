use CGI::Simple;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use t::Mock::Tilma;
use Test::MockTime qw(:all);
use Test::MockModule;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

# Mock fetching bank holidays
my $uk = Test::MockModule->new('FixMyStreet::Cobrand::UK');
$uk->mock('_fetch_url', sub { '{}' });

use_ok 'FixMyStreet::Cobrand::Brent';

my $brent = $mech->create_body_ok(2488, 'Brent', {
    api_key => 'abc',
    jurisdiction => 'brent',
    endpoint => 'http://endpoint.example.org',
    send_method => 'Open311',
}, {
    cobrand => 'brent'
});
my $contact = $mech->create_contact_ok(body_id => $brent->id, category => 'Graffiti', email => 'graffiti@example.org');
my $gully = $mech->create_contact_ok(body_id => $brent->id, category => 'Gully grid missing',
    email => 'Symology-gully', group => ['Drains and gullies']);
my $user1 = $mech->create_user_ok('user1@example.org', email_verified => 1, name => 'User 1');

$mech->create_contact_ok(body_id => $brent->id, category => 'Potholes', email => 'potholes@brent.example.org');

sub create_contact {
    my ($params, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $brent, %$params, extra => { type => 'waste' });
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        { code => 'property_id', required => 1, automated => 'hidden_field' },
        { code => 'service_id', required => 0, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

create_contact({ category => 'Report missed collection', email => 'missed' });
create_contact({ category => 'Request new container', email => 'request@example.org' },
    { code => 'Container_Task_New_Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Container_Task_New_Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Container_Task_New_Actions', required => 0, automated => 'hidden_field' },
    { code => 'Container_Task_New_Notes', required => 0, automated => 'hidden_field' },
);

for my $test (
    {
        desc => 'Problem has stayed open when user reported fixed with update',
        report_status => 'confirmed',
        fields => { been_fixed => 'Yes', reported => 'No', another => 'No', update => 'Test' },
    },
    {
        desc => 'Problem has stayed open when user reported fixed without update',
        report_status => 'confirmed',
        fields => { been_fixed => 'Yes', reported => 'No', another => 'No' },
    },
    {
        desc => 'Problem has stayed fixed when user reported not fixed with update',
        report_status => 'fixed - council',
        fields => { been_fixed => 'No', reported => 'No', another => 'No', update => 'Test' },
    },
 ) { subtest "Response to questionnaire doesn't update problem state" => sub {
        my $dt = DateTime->now()->subtract( weeks => 5 );
        my $report_time = $dt->ymd . ' ' . $dt->hms;
        my $sent = $dt->add( minutes => 5 );
        my $sent_time = $sent->ymd . ' ' . $sent->hms;

        my ($problem) = $mech->create_problems_for_body(1, $brent->id, 'Title', {
        areas => "2488", category => 'Graffiti', cobrand => 'brent', user => $user1, confirmed => $report_time,
        lastupdate => $report_time, whensent => $sent_time, state => $test->{report_status}});


        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'brent',
        }, sub {

        FixMyStreet::DB->resultset('Questionnaire')->send_questionnaires( {
            site => 'fixmystreet'
        } );

        my $email = $mech->get_email;
        my $url = $mech->get_link_from_email($email, 0, 1);
        $mech->clear_emails_ok;
        $mech->get_ok($url);
        $mech->submit_form_ok( { with_fields => $test->{fields} }, "Questionnaire submitted");
        $mech->get_ok('/report/' . $problem->id);
        $problem = FixMyStreet::DB->resultset('Problem')->find_or_create( { id => $problem->id } );
        is $problem->state, $test->{report_status}, $test->{desc};
        my $questionnaire = FixMyStreet::DB->resultset('Questionnaire')->find( {
            problem_id => $problem->id
        } );

        $questionnaire->delete;
        $problem->comments->first->delete;
        $problem->delete;
        }
    };
};

subtest "Open311 attribute changes" => sub {
    my ($problem) = $mech->create_problems_for_body(1, $brent->id, 'Gully', {
        areas => "2488", category => 'Gully grid missing', cobrand => 'brent',
    });
    $problem->update_extra_field({ name => 'UnitID', value => '234' });
    $problem->update;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'brent',
        MAPIT_URL => 'http://mapit.uk/',
        STAGING_FLAGS => { send_reports => 1 },
        COBRAND_FEATURES => {
            anonymous_account => {
                brent => 'anonymous'
            },
        },
    }, sub {
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        is $c->param('attribute[UnitID]'), undef, 'UnitID removed from attributes';
        like $c->param('description'), qr/ukey: 234/, 'UnitID on gully sent across in detail';
        is $c->param('attribute[title]'), $problem->title, 'Report title passed as attribute for Open311';
    };
};

my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register($tilma->to_psgi_app, host => 'tilma.mysociety.org');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'brent', 'tfl' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest "hides the TfL River Piers category" => sub {

        my $tfl = $mech->create_body_ok(2488, 'TfL');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers', email => 'tfl@example.org');

        ok $mech->host('brent.fixmystreet.com'), 'set host';
        my $json = $mech->get_ok_json('/report/new/ajax?latitude=51.55904&longitude=-0.28168');
        is $json->{by_category}->{"River Piers"}, undef, "Brent doesn't have River Piers category";
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'brent',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { brent => { sample_data => 1 } },
        waste => { brent => 1 },
        anonymous_account => { brent => 'anonymous' },
    },
}, sub {
    my $echo = shared_echo_mocks();
    $echo->mock('GetServiceUnitsForObject' => sub {
    return [
        {
            Id => 1001,
            ServiceId => 262,
            ServiceName => 'Domestic Dry Recycling Collection',
            ServiceTasks => { ServiceTask => {
                Id => 401,
                ServiceTaskSchedules => { ServiceTaskSchedule => {
                    ScheduleDescription => 'every Wednesday',
                    StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                    },
                    LastInstance => {
                        OriginalScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                        CurrentScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                        Ref => { Value => { anyType => [ 123, 456 ] } },
                    },
                } },
            } },
        }, {
            Id => 1002,
            ServiceId => 265,
            ServiceName => 'Domestic Refuse Collection',
            ServiceTasks => { ServiceTask => {
                Id => 402,
                ServiceTaskSchedules => { ServiceTaskSchedule => {
                    ScheduleDescription => 'every other Wednesday',
                    StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-10T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-10T00:00:00Z' },
                    },
                    LastInstance => {
                        OriginalScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                        CurrentScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                        Ref => { Value => { anyType => [ 234, 567 ] } },
                    },
                } },
            } },
        }, {
            Id => 1003,
            ServiceId => 316,
            ServiceName => 'Domestic Food Waste Collection',
            ServiceTasks => { ServiceTask => {
                Id => 403,
                ServiceTaskSchedules => { ServiceTaskSchedule => {
                    ScheduleDescription => 'every other Wednesday',
                    StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                    },
                    LastInstance => {
                        OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                        CurrentScheduledDate => { DateTime => '2020-05-20T00:00:00Z' },
                        Ref => { Value => { anyType => [ 345, 678 ] } },
                    },
                } },
            } },
        }, ]
    });

    subtest 'test report missed container' => sub {
        set_fixed_time('2020-05-19T12:00:00Z'); # After sample food waste collection
        $mech->get_ok('/waste/12345');
        restore_time();
    };

    subtest 'test requesting a container' => sub {
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Request a domestic dry recycling collection container');
        $mech->follow_link_ok({url => 'http://brent.fixmystreet.com/waste/12345/request'});
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 3 } }, "Choose general rubbish bin");

        $mech->content_contains("Why do you need a replacement container?");
        $mech->content_contains("My container is damaged", "Can report damaged container");
        $mech->content_contains("My container is missing", "Can report missing container");
        $mech->content_lacks("I am a new resident without a container", "Can not request new container as new resident");
        $mech->content_lacks("I would like an extra container", "Can not request an extra container");
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' } }, "Choose damaged as replacement reason");

        $mech->content_contains("Damaged during collection");
        $mech->content_contains("Wear and tear");
        $mech->content_contains("Other damage");
        $mech->submit_form_ok({ with_fields => { 'notes_damaged' => 'collection' } });

        $mech->content_contains("Collection damage");
        $mech->submit_form_ok({ with_fields => { 'details_damaged' => '' } }, "Put nothing in obligatory field");
        $mech->content_contains("Please describe how your container was damaged field is required", "Error message for empty field");
        $mech->submit_form_ok({ with_fields => { 'details_damaged' => 'Bin man brutalised my bin' } }, "Put reason in for obligatory field");
        $mech->content_contains("About you");

        $mech->back; $mech->back; $mech->back; # Going back to choose different type of damage

        $mech->submit_form_ok({ with_fields => { 'notes_damaged' => 'wear' } });
        $mech->content_contains("About you", "No notes required for wear and tear damage");
        $mech->back;

        $mech->submit_form_ok({ with_fields => { 'notes_damaged' => 'other' } });
        $mech->content_contains("About you", "No notes required for other damage");

        for my $test ({ id => 23, name => 'food waste caddy'}, { id => 11, name => 'Recycling bin (blue bin)'}) {
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok({url => 'http://brent.fixmystreet.com/waste/12345/request'});
            $mech->submit_form_ok({ with_fields => { 'container-choice' => $test->{id} } }, "Choose " . $test->{name});
            $mech->content_contains("Why do you need a replacement container?");
            $mech->content_contains("My container is damaged", "Can report damaged container");
            $mech->content_contains("My container is missing", "Can report missing container");
            $mech->content_contains("I am a new resident without a container", "Can request new container as new resident");
            $mech->content_contains("I would like an extra container", "Can request an extra container");
            for my $radio (
                    {choice => 'new_build', type => 'new resident needs container'},
                    {choice => 'damaged', type => 'damaged container'},
                    {choice => 'missing', type => 'missing container'},
                    {choice => 'extra', type => 'extra container'}
            ) {
                $mech->submit_form_ok({ with_fields => { 'request_reason' => $radio->{choice} } });
                $mech->content_contains("About you", "No further questions for " . $radio->{type});
                $mech->back;
            }
        }

        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user1->email } });
        $mech->submit_form_ok({ with_fields => { 'process' => 'summary' } });
        $mech->content_contains('Your container request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->get_extra_field_value('Container_Task_New_Container_Type'), '11::11';
        is $report->get_extra_field_value('Container_Task_New_Actions'), '2::1';
        is $report->get_extra_field_value('Container_Task_New_Notes'), '';
    };
};

sub shared_echo_mocks {
    my $e = Test::MockModule->new('Integrations::Echo');
    $e->mock('GetPointAddress', sub {
        return {
            Id => 12345,
            SharedRef => { Value => { anyType => '1000000002' } },
            PointType => 'PointAddress',
            PointAddressType => { Name => 'House' },
            Coordinates => { GeoPoint => { Latitude => 51.55904, Longitude => -0.28168 } },
            Description => '2 Example Street, Brent, NW2 1AA',
        };
    });
    $e->mock('GetEventsForObject', sub { [] });
    $e->mock('GetTasks', sub { [] });
    return $e;
}

done_testing();
