package FixMyStreet::Cobrand::Camden;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { return 2505; }
sub council_area { return 'Camden'; }
sub council_name { return 'Camden Council'; }
sub council_url { return 'camden'; }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Camden';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.546390811297,-0.157422262955539',
        span   => '0.0603011959324533,0.108195286339115',
        bounds => [ 51.5126591342049, -0.213511484504216, 51.5729603301373, -0.105316198165101 ],
    };
}

sub send_questionnaires {
    return 0;
}

sub privacy_policy_url {
    'https://www.camden.gov.uk/data-protection-privacy-and-cookies'
}

sub admin_user_domain { 'camden.gov.uk' }

1;
