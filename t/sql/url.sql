BEGIN;
SET client_min_messages TO 'warning';

TRUNCATE url CASCADE;
INSERT INTO url (id, gid, url, description, refcount)
    VALUES (1, '9201840b-d810-4e0f-bb75-c791205f5b24', 'http://musicbrainz.org/',
        'MusicBrainz', 2);

INSERT INTO url (id, gid, url, description, refcount)
    VALUES (2, '25d6b63a-12dc-41c9-858a-2f42ae610a7d', 'http://zh-yue.wikipedia.org/wiki/王菲',
        'Cantonese wikipedia page of Faye Wong', 1);

COMMIT;
