use v6;

unit class Build;

method build($workdir) {
    my $config-proc = run('taglib-config', '--libs', '--cflags', :out);
    die "taglib-config failed: {$config-proc.exitcode}" if $config-proc.exitcode != 0;
    my @config-flags = $config-proc.out.slurp.words;

    my $destdir = "$workdir/resources";
    $destdir.IO.mkdir;

    # ensure platform-specific resources exists everywhere
    "$destdir/libtaglib_raku.$_".IO.spurt("") for <dll dylib so>;

    my $libname = sprintf($*VM.config<dll>, "taglib_raku");
    my $proc = run('g++', '-fPIC', '-shared', '-O3', '-Wall', '-o', "$destdir/$libname", 'src/taglib_raku.cpp', '-g', '-I/usr/include/cryptopp', |@config-flags, '-lz');

    return $proc.exitcode == 0;
}
