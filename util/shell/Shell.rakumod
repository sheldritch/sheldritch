unit module Tools::Util::Shell;

sub bash($cmd, :$stdout, :$proc, :$pipe, :$out = $stdout ?? '-' !! True, *%other) is export {
	# See https://docs.raku.org/routine/run for other available args
	my $process = run('/bin/bash', '-c', "source \$TOOLS/tools.sh; $cmd", :$out, |%other);

	if $proc || $out !=== True { $process }
	elsif $pipe                { $process.out }
	else                       { $process.out.slurp }
}

sub pwsh($cmd, :$proc, :$pipe, *%other) is export {
	my $process = run('/usr/bin/env powershell', '-c', $cmd, :out, |%other);

	if $proc    { $process }
	elsif $pipe { $process.out }
	else        { $process.out.slurp }
}

#= Like prompt(), but using stderr (file descriptor 2)
sub prompt2($msg) is export {
	my $err := $*ERR;
	$err.print($msg);
	$*OUT.flush();
	$err.flush();
	return $*IN.get;
}

# Map the given list of arguments to the given flag
sub mapArgs(@args, $flag) is export {
	@args.map({ qq{$flag "$_"} }).join(' ');
}

sub EXPORT {
    Map.new:
      'JSON' => JSON::Fast;
}
