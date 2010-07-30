package MusicBrainz::Server::Controller::WS::1::Artist;
use Moose;
BEGIN { extends 'MusicBrainz::Server::Controller::WS::1' }

my $ws_defs = Data::OptList::mkopt([
    artist => {
        method   => 'GET',
        inc      => [
            qw( aliases release-groups _rel_status _rg_type counts
                release-events discs labels _relations tags ) ],
    },
]);

with 'MusicBrainz::Server::WebService::Validator' => {
     defs    => $ws_defs,
     version => 1,
};

sub lookup : Path('') Args(1)
{
    my ($self, $c, $gid) = @_;

    if (!MusicBrainz::Server::Validation::IsGUID($gid))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    my $artist = $c->model('Artist')->get_by_gid($gid);
    unless ($artist) {
        $c->detach('not_found');
    }

    $c->model('ArtistType')->load($artist);

    my $opts = {};
    $opts->{aliases} = $c->model('Artist')->alias->find_by_entity_id($artist->id)
        if ($c->stash->{inc}->aliases);

    if ($c->stash->{inc}->tags) {
        my ($tags, $hits) = $c->model('Artist')->tags->find_tags($artist->id);
        $opts->{tags} = $tags;
    }


    if ($c->stash->{inc}->rg_type)
    {
        my @rg;

        if ($c->stash->{inc}->various_artists)
        {
            @rg = $c->model('ReleaseGroup')->filter_by_track_artist($artist->id, $c->stash->{inc}->rg_type);
        }
        else
        {
            @rg = $c->model('ReleaseGroup')->filter_by_artist($artist->id, $c->stash->{inc}->rg_type);
        }

        $c->model('ArtistCredit')->load(@rg);
        $c->model('ReleaseGroupType')->load(@rg);
        $opts->{release_groups} = \@rg;

        if (@rg)
        {
            my ($results, $hits) = $self->_load_paged($c, sub {
                $c->model('Release')->find_by_release_group([ map { $_->id } @rg ], shift, shift)
            });

            $c->model('ReleaseStatus')->load(@$results);

            my @releases;
            if ($c->stash->{inc}->rel_status && @rg)
            {
                @releases = grep { $_->status->id == $c->stash->{inc}->rel_status } @$results;
            }
            else
            {
                @releases = @$results;
            }

            # make sure the release groups are hooked up to the releases, so
            # the serializer can get the release type from the release group.
            my %rel_to_rg_map = map { ( $_->id => $_ ) } @rg;
            map { $_->release_group($rel_to_rg_map{$_->release_group_id}) } @releases;

            if ($c->stash->{inc}->discs)
            {
                $c->model('Medium')->load_for_releases(@releases);
                my @medium_cdtocs = $c->model('MediumCDTOC')->load_for_mediums(map { $_->all_mediums } @releases);
                $c->model('CDTOC')->load(@medium_cdtocs);
            }

            $c->model('ReleaseStatus')->load(@releases);
            $c->model('Language')->load(@releases);
            $c->model('Script')->load(@releases);

            $c->model('Relationship')->load_subset([ 'url' ], @releases);
            $c->stash->{inc}->asin(1);

            $c->stash->{inc}->releases(1);
            $opts->{releases} = \@releases;
        }
    }

    if ($c->stash->{inc}->labels)
    {
         my @labels = $c->model('Label')->find_by_artist($artist->id);
         $opts->{labels} = \@labels;
    }

     if ($c->stash->{inc}->has_rels)
     {
         my $types = $c->stash->{inc}->get_rel_types;
         my @rels = $c->model('Relationship')->load_subset($types, $artist);
     }

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('artist', $artist, $c->stash->{inc}, $opts));
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=head1 COPYRIGHT

Copyright (C) 2010 MetaBrainz Foundation

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=cut
