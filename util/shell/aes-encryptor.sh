#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$AES_ENCRYPTION_KEY" == "" ]];then
	echo "Please set the AES_ENCRYPTION_KEY environment variable first. (you can use: \`read -p \"Encryption Key: \" -s AES_ENCRYPTION_KEY && export AES_ENCRYPTION_KEY\`)"
	exit 1
fi

$DIR/.aes-encryptor.linux "$@"
