unit class Audio::TagLib:auth<zef:avuserow>:ver<0.0.4>;

use NativeCall;

class X::Audio::TagLib::InvalidAudioFile is Exception {
    has $.file;
    has $.text;
    method message() {
        "Failed to parse file $.file: $.text"
    }
}

has Str $.file is readonly;

has Str $.title is readonly;
has Str $.artist is readonly;
has Str $.album is readonly;
has Str $.comment is readonly;
has Str $.genre is readonly;
has Int $.year is readonly;
has Int $.track is readonly;
has Int $.length is readonly;

has Int $.album-art-size is readonly;
has Str $.album-art-mime is readonly;

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
        taglib_file_free($taglib-file);
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

    my $album-art-metadata = taglib_get_image_md($taglib-file);
    $!album-art-size = $album-art-metadata.data_length;
    $!album-art-mime = $album-art-metadata.mimetype;

    taglib_file_free($taglib-file);
}

method !load-propertymap($taglib-file) {
    my uint32 $tagcount = 0;
    my $abstract = taglib_all_tags_pairs($taglib-file, $tagcount);
    @.propertymap = ($abstract[$_] for ^$tagcount).pairup;
}

method get-album-art-raw() {
    my $taglib-file = taglib_file_new($!file);
    LEAVE taglib_file_free($taglib-file);

    my $size = taglib_get_image_buf($taglib-file, Any, 0);

    if $size <= 0 {
        return CArray[uint8].new();
    }

    my $out = CArray[uint8].allocate($size);
    taglib_get_image_buf($taglib-file, $out, $size);

    return $out;
}

method get-album-art() {
    my $data = self.get-album-art-raw;
    return Blob[uint8].new: $data.list;
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

my class NativeImageMetadata is repr<CStruct> {
    has Str $.mimetype;
    has uint32 $.data_length;
}

my sub taglib_get_image_md(OpaquePointer) is native(&native-lib) returns NativeImageMetadata {*}
my sub taglib_get_image_buf(OpaquePointer, CArray[uint8], size_t) is native(&native-lib) returns ssize_t {*}

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

TagLib provides what is known as the "abstract API", which provides an easy
interface to common tags without having to know the format-specific identifier
for a given tag. This module provides these as attributes of C<Audio::TagLib>.
The following fields are available as strings (Str):

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

The raw tag values are available in the propertymap attribute as a List of
Pairs. It is possible to have duplicate keys (otherwise this would be a hash).

If you are looking for a tag that is not available in the abstract interface,
you can find it here.
O

=head2 Album Art

Album art can be extracted from most types of audio files. This module provides
access to the first picture data in the file. Most files only have a single
picture attached, so this is usually the album art.

=item album-art-size - the size of the album art in bytes
=item album-art-mime - the mime type of the album art, such as 'image/png'

The data can be retrieved by calling one of the following methods:

=item get-album-art - returns the data as a Blob[uint8]
=item get-album-art-raw - returns the data as a CArray (call .elems to get the size)

The raw variant is much faster if you are passing the data to another function
that uses a CArray. If speed is important, consider using
L<NativeHelpers::Blob> to convert the raw variant.

Note that the mime type is stored in the file, and not determined from the
image, so it may be inaccurate.

=head1 SEE ALSO

L<Audio::Taglib::Simple>

L<<https://taglib.org>>

=head1 AUTHOR

Adrian Kreher <avuserow@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2021-2022 Adrian Kreher

This library is free software; you can redistribute it and/or modify it under
the Artistic License 2.0.

=end pod
