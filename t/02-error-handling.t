use v6;

use Test;
use Audio::TagLib;

plan 2;

throws-like({
	Audio::TagLib.new('non-existent-file.invalid');
}, X::Audio::TagLib::InvalidAudioFile, 'non-existent file', message => /'does not exist'/);

throws-like({
	Audio::TagLib.new('META6.json');
}, X::Audio::TagLib::InvalidAudioFile, 'non-music file', message => /'file is invalid'/);
