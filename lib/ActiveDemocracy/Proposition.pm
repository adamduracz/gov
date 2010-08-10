# -*-cperl-*-
package ActiveDemocracy::Proposition;

=head1 NAME

ActiveDemocracy::Proposition

=cut

use 5.010;
use strict;
use warnings;
use utf8;

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );
use Para::Frame::Widget qw( jump );
use Para::Frame::L10N qw( loc );

#use Rit::Base::Constants qw( $C_proposition_area_sweden );
use Rit::Base::Resource;
use Rit::Base::Utils qw( parse_propargs is_undef );
use Rit::Base::Literal::Time qw( now );

our %VOTE_COUNT;
our %ALL_VOTES;
our %PREDICTED_RESOLUTION_DATE;

##############################################################################

# Overloaded...
#sub wu_vote
#{
#    throw('incomplete', loc('Internal error: Proposition is without type.'));
#}


##############################################################################

sub wp_jump
{
    my( $proposition ) = @_;

    my $home = $Para::Frame::REQ->site->home_url_path;


    return jump($proposition->name->loc, $home ."/proposition/display.tt",
		{
		 id => $proposition->id,
		});
}

##############################################################################

sub area
{
    my( $proposition ) = @_;

    return $proposition->subsides_in->get_first_nos;
#      || $C_proposition_area_sweden;
}


##############################################################################

# Overloaded...
#sub register_vote
#{
#    throw('incomplete', loc('Internal error: Proposition is without type.'));
#}


##############################################################################

=head2 random_public_vote

Returns: A public vote placed on this proposition

Right now, all votes are public...

=cut

sub random_public_vote
{
    my( $proposition ) = @_;

    my $R = Rit::Base->Resource;
    my $public_votes = $R->find({
				 rev_has_vote => $proposition,
				});

    return $public_votes->randomized->get_first_nos();
}


##############################################################################

=head2 example_vote_html

Returns: An example vote text, e.g.: Fredrik has voted 'yay' on this.

=cut

sub example_vote_html
{
    my( $proposition ) = @_;

    my $vote = $proposition->random_public_vote; # TODO: or raise internal error
    my $user = $vote->rev_places_vote; # TODO: or raise internal error

    return '<em>'. $user->desig .'</em> would vote "'. $vote->desig
      .'" on this proposition.';
}


##############################################################################

=head2 get_all_votes

Returns: Sum of yay- and nay-votes.

=cut

sub get_all_votes
{
    my( $proposition, $wants_delegates ) = @_;

    my @complete_list;

    unless( 0 and exists $ALL_VOTES{$proposition->id} ) {
        my $R     = Rit::Base->Resource;

        my $area    = $proposition->area;
        my $members = $area->revlist( 'has_voting_jurisdiction' );
        my @votes;

        # To sum delegated votes, we loop through all with jurisdiction in area
        while( my $member = $members->get_next_nos ) {
            debug "Getting vote for " . $member->desig;
            my( $vote, $delegate ) = $member->find_vote( $proposition );

            push @votes, $vote
              if( $vote );
            push @complete_list, { member => $member, vote => $vote, delegate => $delegate };
        }

        $ALL_VOTES{$proposition->id} = new Rit::Base::List( \@votes );
    }

    if ($wants_delegates) {
        return \@complete_list;
    }
    else {
        return $ALL_VOTES{$proposition->id};
    }
}


##############################################################################

sub get_vote_count
{
    my( $proposition ) = @_;

    unless( 0 and exists $VOTE_COUNT{$proposition->id} ) {
        $VOTE_COUNT{$proposition->id} = $proposition->sum_all_votes;
    }

    return $VOTE_COUNT{$proposition->id};
}

##############################################################################

sub is_open
{
    my( $proposition ) = @_;

    return $proposition->is_resolved ? is_undef : $proposition;
}


##############################################################################

sub is_resolved
{
    my( $proposition ) = @_;

    return $proposition->count('has_resolution_vote') ? $proposition : is_undef;
}


##############################################################################

sub should_be_resolved
{
    my( $proposition ) = @_;

    return 0
      if( $proposition->is_resolved );
    my $method = $proposition->has_resolution_method
      or return 0;

    return $method->should_resolve( $proposition );
}


##############################################################################

sub has_predicted_resolution_date
{
    my( $proposition ) = @_;

    return defined $proposition->predicted_resolution_date ? $proposition : is_undef;
}

sub no_predicted_resolution_date
{
    my( $proposition ) = @_;

    return defined $proposition->predicted_resolution_date ? is_undef : $proposition;
}

sub predicted_resolution_date
{
    my( $proposition ) = @_;

    debug "Getting predicted_resolution_date for " . $proposition->sysdesig;

    return is_undef
      if( $proposition->is_resolved );
    my $method = $proposition->has_resolution_method
      or return is_undef;

    unless( 0 and exists $PREDICTED_RESOLUTION_DATE{$proposition->id} ) {
        $PREDICTED_RESOLUTION_DATE{$proposition->id}
          = $method->predicted_resolution_date( $proposition );
    }


    debug "   returning a " . ref $PREDICTED_RESOLUTION_DATE{$proposition->id};

    return $PREDICTED_RESOLUTION_DATE{$proposition->id};
}

##############################################################################

=head2 resolve

Adds has_resolution_vote and proposition_resolved_date to the proposition.

=cut

sub resolve
{
    my( $proposition ) = @_;

    return undef
      if( $proposition->is_resolved );

    my( $args, $arclim, $res ) = parse_propargs('relative');

    my $vote = $proposition->create_resolution_vote( $args );
    $proposition->add({ has_resolution_vote => $vote }, $args);

    $proposition->add({ proposition_resolved_date => now() }, $args);

    $res->autocommit({ activate => 1 });

    return;
}


1;
