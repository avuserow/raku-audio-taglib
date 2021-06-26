#!/usr/bin/env raku

use v6.d;

use Audio::TagLib;

multi MAIN() {
    say "Provide one or more audio files as arguments.";
    exit 1;
}

multi MAIN(*@files) {
    my $music = 0;
    my $non-music = 0;
    for @files -> $file {
        try {
            CATCH {
                when X::Audio::TagLib::InvalidAudioFile {
                    say "{.file} was not a recognized audio format: {.text}";
                    $non-music++;
                    next;
                }
            }
            my $tl = Audio::TagLib.new($file);
            say $tl.file;

            for <title artist album comment genre year track length> {
                say "$_: ", $tl."$_"();
            }
            $music++;
        }
        say '';
    }

    say "Took ", (now - BEGIN now), " seconds";
    say "Found $music music files, $non-music non-music.";
}
