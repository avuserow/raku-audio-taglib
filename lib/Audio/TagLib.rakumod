unit class Audio::TagLib:ver<0.0.1>;

class X::Audio::TagLib::InvalidAudioFile is Exception {
    has $.file;
    has $.text;
    method message() {
        "Failed to parse file $.file: $.text"
    }
}

use NativeCall;

has Str $.file is readonly;

has Str $.title is readonly;
has Str $.artist is readonly;
has Str $.album is readonly;
has Str $.comment is readonly;
has Str $.genre is readonly;
has Int $.year is readonly;
has Int $.track is readonly;
has Int $.length is readonly;

has @.propertymap is readonly;

multi method new($file) {
    self.bless(:$file);
}

submethod BUILD(IO() :$file) {
    unless $file ~~ :e {
        die X::Audio::TagLib::InvalidAudioFile.new(
            file => $file,
            text => 'File does not exist',
        );
    }
    unless $file ~~ :f {
        die X::Audio::TagLib::InvalidAudioFile.new(
            file => $file,
            text => 'Not a file',
        );
    }
    $!file = $file.path;

    my $taglib-file = taglib_file_new($!file);

    unless $taglib-file {
        die X::Audio::TagLib::InvalidAudioFile.new(
            file => $file,
            text => 'File not recognized or parseable by TagLib',
        );
    }

    unless taglib_file_is_valid($taglib-file) {
        die X::Audio::TagLib::InvalidAudioFile.new(
            file => $file,
            text => 'TagLib reports file is invalid',
        );
    }

    my $filetag = taglib_file_tag($taglib-file);

    $!title = taglib_tag_title($filetag);
    $!artist = taglib_tag_artist($filetag);
    $!album = taglib_tag_album($filetag);
    $!comment = taglib_tag_comment($filetag);
    $!genre = taglib_tag_genre($filetag);
    $!year = taglib_tag_year($filetag);
    $!track = taglib_tag_track($filetag);

    $!length = taglib_file_length($taglib-file);

    self!load-propertymap($taglib-file);

    taglib_file_free($taglib-file);
}

method !load-propertymap($taglib-file) {
    my uint32 $tagcount = 0;
    my $abstract = taglib_all_tags_pairs($taglib-file, $tagcount);
    @.propertymap = ($abstract[$_] for ^$tagcount).pairup;
}

sub native-lib {
    my $lib-name = sprintf($*VM.config<dll>, "taglib_raku");
    return ~(%?RESOURCES{$lib-name} // "resources/$lib-name");
}
my sub taglib_file_new(Str) returns OpaquePointer is native(&native-lib) {*}
my sub taglib_file_tag(OpaquePointer) returns OpaquePointer is native(&native-lib) {*}
my sub taglib_file_is_valid(OpaquePointer) returns Bool is native(&native-lib) {*}
my sub taglib_file_free(OpaquePointer) is native(&native-lib) {*}
my sub taglib_all_tags_pairs(OpaquePointer, uint32 is rw) returns CArray[Str] is native(&native-lib) {*}

my sub taglib_tag_title(OpaquePointer) returns Str is native(&native-lib) {*}
my sub taglib_tag_artist(OpaquePointer) returns Str is native(&native-lib) {*}
my sub taglib_tag_album(OpaquePointer) returns Str is native(&native-lib) {*}
my sub taglib_tag_comment(OpaquePointer) returns Str is native(&native-lib) {*}
my sub taglib_tag_genre(OpaquePointer) returns Str is native(&native-lib) {*}
my sub taglib_tag_year(OpaquePointer) returns uint32 is native(&native-lib) {*}
my sub taglib_tag_track(OpaquePointer) returns uint32 is native(&native-lib) {*}

my sub taglib_file_length(OpaquePointer) returns int32 is native(&native-lib) {*}

=begin pod

=head1 NAME

Audio::TagLib - Read ID3 and other audio metadata with TagLib

=head1 SYNOPSIS

=begin code :lang<raku>

use Audio::TagLib;

my $taglib = Audio::TagLib.new($path);

# Abstract API - aliases for simple fields
say $taglib.title ~ " by " ~ $taglib.artist;
say "$path has no album field set" unless $taglib.album.defined;

# Raw access to all tags in the file (as a list of pairs)
.say for $taglib.propertymap.grep(*.key eq 'ALBUMARTIST' | 'ALBUM ARTIST');

=end code

=head1 DESCRIPTION

Audio::TagLib provides Raku bindings to the TagLib audio metadata library,
providing a fast way to read metadata from many audio file formats: mp3, m4a,
ogg, flac, opus, and more. See L<<https://taglib.org>> for more details.

=head1 Audio::TagLib vs Audio::Taglib::Simple

This module uses the C++ interface to TagLib rather than the C bindings. This
means installation requires a C++ compiler, but provides the full API rather
than the "abstract only" API.

This module is newer than Simple and does not yet provide tag writing
functions.

This module does not keep a taglib object open and reads everything into memory
initially, meaning there is no C<free> method needed (unlike Simple).

C<Audio::Taglib::Simple> has a lowercase 'l' in its name, where this module
uses C<TagLib> (as does the official website). I thought adjusting the case was
a good idea at the time.

=head3 Abstract API

TagLib provides what is known as the "abstract API", which provides an easy interface to common tags without having to know the format-specific identifier for a given tag. This module provides these as attributes of C<Audio::TagLib>. The following fields are available as strings (Str):

=item title
=item artist
=item album
=item comment
=item genre

The following are provided as integers (Int):

=item year
=item track
=item length - length of the file, in seconds

These attributes will be undefined if they are not present in the file.

=head3 @.propertymap

The raw tag values are available in the propertymap attribute as a List of Pairs. It is possible to have duplicate keys (otherwise this would be a hash).

If you are looking for a tag that is not available in the abstract interface, you can find it here.

=head1 SEE ALSO

L<Audio::Taglib::Simple>

L<<https://taglib.org>>

=head1 AUTHOR

Adrian Kreher <avuserow@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2021 Adrian Kreher

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
