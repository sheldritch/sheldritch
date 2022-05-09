# System management for Linux

ipaddr() {
	hostname -I | awk '{print $1}'
}

gimme() {
	sudo chown -R $USER "${1:-$_}"
}
