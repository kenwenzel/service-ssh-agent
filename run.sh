#!/bin/bash

HOST_SSH_KEY_PATH="${HOST_SSH_KEY_PATH:-"/host/.ssh"}"
CREATE_KEY="${CREATE_KEY:-"false"}"

# Print a debug message if debug mode is on ($DEBUG is not empty)
# @param message
debug_msg ()
{
	if [ -n "$DEBUG" ]; then
		echo "$@"
	fi
}

createKey() {
	if [ -n "$HOST_SSH_KEY_PATH" ]; then
		parent=$(dirname "$HOST_SSH_KEY_PATH")
		if [[ "$parent" != "/" && -d "$parent" ]]; then
			echo "Creating .ssh folder..."
			mkdir -p "$HOST_SSH_KEY_PATH"
		fi
	fi

	if [ -d "$HOST_SSH_KEY_PATH" ]; then
		mkdir -p "$HOST_SSH_KEY_PATH"
		key_file="$HOST_SSH_KEY_PATH/id_rsa"
		if [ ! -f "$key_file" ]; then
			echo "Creating SSH key pair..."
			IP_ADDRESS=$(ifconfig | grep -Pazo 'eth[0-9]\s+\N+\n\s+inet (addr:)?([0-9]*.){3}[0-9]*' | grep -Eao '([0-9]*\.){3}[0-9]*' | grep -va '127.0.0.1'| head -n1)
			ssh-keygen -t rsa -b 4096 -C "$IP_ADDRESS" -N "" -f "$key_file"
			chmod 600 "$key_file" 2>&1 || true
			chmod 644 "${key_file}.pub" >/dev/null 2>&1 || true
		fi
	fi
}

addKey() {
	# We copy keys from there into /root/.ssh and fix permissions (necessary on Windows hosts)
	if [ -d "$HOST_SSH_KEY_PATH" ]; then
		debug_msg "Copying host SSH keys and setting proper permissions..."
		for f in "$HOST_SSH_KEY_PATH"/*.pub; do
			[ -e "$f" ] || continue
			cp "$f" $HOME/.ssh/
			cp "${f%.*}" $HOME/.ssh/
		done
		chmod 700 $HOME/.ssh
		chmod 600 $HOME/.ssh/* >/dev/null 2>&1 || true
		chmod 644 $HOME/.ssh/*.pub >/dev/null 2>&1 || true
	fi

	# Make sure the key exists if provided.
	# Otherwise we may be getting an argumet, which we'll handle late.
	# When $ssh_key_path is empty, ssh-agent will be looking for both id_rsa and id_dsa in the home directory.
	ssh_key_path=""
	if [ -n "$1" ] && [ -f "$HOST_SSH_KEY_PATH/$1" ]; then
		ssh_key_path="$HOST_SSH_KEY_PATH/$1"
		shift # remove argument from the array
	fi

	# Calling ssh-add. This should handle all arguments cases.
	_command="ssh-add $ssh_key_path $@"
	debug_msg "Executing: $_command"
	# When $ssh_key_path is empty, ssh-agent will be looking for both id_rsa and id_dsa in the home directory.
	# We do a sed hack here to strip out '/root/.ssh' from the key path in the output from ssh-add, since this path may confuse people.
	# echo "Press ENTER or CTRL+C to skip entering passphrase (if any)."
	$_command 2>&1 0>&1 | sed 's/\/root\/.ssh\///g'
}

case "$1" in
	# Start ssh-agent
	ssh-agent)
		echo "Create SSH directory: $HOME/.ssh"
		mkdir -p $HOME/.ssh

		if [ -n "$CREATE_KEY" ] ; then
			createKey
		fi

		echo "Launching ssh-agent..."
		# Start ssh-agent
		/usr/bin/ssh-agent -a ${SSH_AUTH_SOCK}

		addKey

		for f in $HOME/.ssh/*.pub; do
			[ -e "$f" ] || continue
			printf "SSH Public Key $(basename $f):\n\n"
			cat "$f"
			printf "\n\n"
		done

		# Create proxy-socket for ssh-agent (to give anyone accees to the ssh-agent socket)
		echo "Creating proxy socket..."
		rm ${SSH_AUTH_SOCK} ${SSH_AUTH_PROXY_SOCK} > /dev/null 2>&1
		exec socat UNIX-LISTEN:${SSH_AUTH_PROXY_SOCK},perm=0666,fork UNIX-CONNECT:${SSH_AUTH_SOCK}

		;;

	# Manage SSH identities
	ssh-add)
		shift # remove argument from the array

		addKey $@

		# Retune command exit code
		exit ${PIPESTATUS[0]}
		;;
	*)
		exec $@
		;;
esac
