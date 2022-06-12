## Audio::TagLib for Raku

Easy to use bindings to the great [TagLib](https://taglib.org/) project for reading audio metadata from all sorts of files: mp3, flac, opus, ogg, mp4, and more.

These bindings require a C++ compiler to give you the full power of the TagLib bindings. This allows you to read the common fields such as artist and album, but also provides the underlying raw values so you can access format-specific data not exposed in the simplified interface.
