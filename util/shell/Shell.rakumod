unit module Tools::Util::Shell;

sub bash($cmd, :$proc, :$pipe, *%other) is export {
	my $process = run('/bin/bash', '-c', "source \$TOOLS/tools.sh; $cmd", :out, |%other);

	if $proc    { $process }
	elsif $pipe { $process.out }
	else        { $process.out.slurp }
}

#= Like prompt(), but using stderr (file descriptor 2)
sub prompt2($msg) is export {
	my $err := $*ERR;
	$err.print($msg);
	$err.flush();
	return $*IN.get;
}

sub EXPORT {
    Map.new:
      'JSON' => JSON::Fast;
}
