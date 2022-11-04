[![Actions Status](https://github.com/avuserow/raku-audio-taglib/workflows/test/badge.svg)](https://github.com/avuserow/raku-audio-taglib/actions)

NAME
====

Audio::TagLib - Read ID3 and other audio metadata with TagLib

SYNOPSIS
========

```raku
use Audio::TagLib;

my $taglib = Audio::TagLib.new($path);

# Abstract API - aliases for simple fields
say $taglib.title ~ " by " ~ $taglib.artist;
say "$path has no album field set" unless $taglib.album.defined;

# Raw access to all tags in the file (as a list of pairs)
.say for $taglib.propertymap.grep(*.key eq 'ALBUMARTIST' | 'ALBUM ARTIST');
```

DESCRIPTION
===========

Audio::TagLib provides Raku bindings to the TagLib audio metadata library, providing a fast way to read metadata from many audio file formats: mp3, m4a, ogg, flac, opus, and more. See [https://taglib.org](https://taglib.org) for more details.

Audio::TagLib vs Audio::Taglib::Simple
======================================

This module uses the C++ interface to TagLib rather than the C bindings. This means installation requires a C++ compiler, but provides the full API rather than the "abstract only" API.

This module is newer than Simple and does not yet provide tag writing functions.

This module does not keep a taglib object open and reads everything into memory initially, meaning there is no `free` method needed (unlike Simple).

`Audio::Taglib::Simple` has a lowercase 'l' in its name, where this module uses `TagLib` (as does the official website). I thought adjusting the case was a good idea at the time.

### Abstract API

TagLib provides what is known as the "abstract API", which provides an easy interface to common tags without having to know the format-specific identifier for a given tag. This module provides these as attributes of `Audio::TagLib`. The following fields are available as strings (Str):

  * title

  * artist

  * album

  * comment

  * genre

The following are provided as integers (Int):

  * year

  * track

  * length - length of the file, in seconds

These attributes will be undefined if they are not present in the file.

### @.propertymap

The raw tag values are available in the propertymap attribute as a List of Pairs. It is possible to have duplicate keys (otherwise this would be a hash).

If you are looking for a tag that is not available in the abstract interface, you can find it here. O

Album Art
---------

Album art can be extracted from most types of audio files. This module provides access to the first picture data in the file. Most files only have a single picture attached, so this is usually the album art.

  * album-art-size - the size of the album art in bytes

  * album-art-mime - the mime type of the album art, such as 'image/png'

The data can be retrieved by calling one of the following methods:

  * get-album-art - returns the data as a Blob[uint8]

  * get-album-art-raw - returns the data as a CArray (call .elems to get the size)

The raw variant is much faster if you are passing the data to another function that uses a CArray. If speed is important, consider using [NativeHelpers::Blob](NativeHelpers::Blob) to convert the raw variant.

Note that the mime type is stored in the file, and not determined from the image, so it may be inaccurate.

SEE ALSO
========

[Audio::Taglib::Simple](Audio::Taglib::Simple)

[https://taglib.org](https://taglib.org)

AUTHOR
======

Adrian Kreher <avuserow@gmail.com>

COPYRIGHT AND LICENSE
=====================

Copyright 2021-2022 Adrian Kreher

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

