# System management for Linux

ipaddr() {
	ip route get 1 | perl -ne ' /src (\S+)/ && print "$1\n" '
}

gimme() {
	sudo chown -R $USER "${1:-$_}"
}
