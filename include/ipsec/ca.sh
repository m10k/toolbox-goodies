#!/bin/bash

# ipsec/ca.sh - Toolbox module for CAs for use with IPsec
# Copyright (C) 2022 Matthias Kruk
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

__init() {
	if ! include "log" "ipsec/key"; then
		return 1
	fi

	declare -grxi __ipsec_ca_default_lifetime_days=3650
	declare -grxi __ipsec_ca_default_rsa_keylen=4096

	return 0
}

_ipsec_ca_init_cleanup() {
	local root="$1"

	local cakey
	local cacert
	local -i err

	cakey="$root/private/cakey.der"
	cacert="$root/cacerts/cacert.der"
	err=0

	if [ -e "$cakey" ] &&
	   ! rm -f "$cakey"; then
		log_error "Could not remove $cakey"
		err=1

	elif [ -d "$root/private" ] &&
	     ! rmdir "$root/private"; then
		log_error "Could not remove $root/private"
		err=1
	fi

	if [ -e "$cacert" ] &&
	   ! rm -f "$cacert"; then
		log_error "Could not remove $cacert"
		err=1

	elif [ -d "$root/cacerts" ] &&
	     ! rmdir "$root/cacerts"; then
		log_error "Could not remove $root/cacerts"
		err=1
	fi

	if [ -d "$root/certs" ] &&
	   ! rmdir "$root/certs"; then
		log_error "Could not remove $root/certs"
		err=1
	fi

	return "$err"
}

ipsec_ca_init() {
	local root="$1"
	local country="$2"
	local organization="$3"
	local common_name="$4"
	local -i lifetime_days="$5"
	local -i rsa_keylen="$6"

	local distinguished_name
	local cakey
	local cacert
	local -i err

	distinguished_name="C=$country,O=$organization,CN=$common_name"
	cakey="$root/private/cakey.pem"
	cacert="$root/cacerts/cacert.pem"
	err=0

	if (( lifetime_days == 0 )); then
		lifetime_days="$__ipsec_ca_default_lifetime_days"
	fi

	if (( rsa_keylen == 0 )); then
		rsa_keylen="$__ipsec_ca_default_rsa_keylen"
	fi

	if ! mkdir -p "$root/private" \
	              "$root/cacerts" \
	              "$root/certs"; then
		log_error "Could not create CA directory structure in $root"
		err=1

	elif [ -e "$cakey" ]; then
		log_error "CA private key $cakey already exists"
		err=2

	elif ! ipsec_key_new "rsa" "$rsa_keylen" "pem" > "$cakey"; then
		log_error "Could not generate CA private key $cakey (len: $rsa_keylen)"
		err=3

	elif ! pki --self --ca --type rsa --lifetime "$lifetime_days" \
	           --dn "$distinguished_name" --in "$cakey"           \
	           --outform "pem" > "$cacert"; then
		log_error "Coiuld not generate CA certificate $cacert"
		err=4
	fi

	if (( err != 0 )); then
		_ipsec_ca_init_cleanup "$root"
	fi

	return "$err"
}

ipsec_ca_generate_server_cert() {
	local root="$1"
	local country="$2"
	local organization="$3"
	local common_name="$4"
	local -i lifetime_days="$5"
	local -i rsa_keylen="$6"

	if ! _ipsec_ca_generate_cert "$root" "$country" "$organization" \
	                             "$common_name" "$lifetime_days"    \
	                             "$rsa_keylen"                      \
	                             "serverAuth" "ikeIntermediate"; then
		return 1
	fi

	return 0
}

ipsec_ca_generate_client_cert() {
	local root="$1"
	local country="$2"
	local organization="$3"
	local common_name="$4"
	local -i lifetime_days="$5"
	local -i rsa_keylen="$6"

	if ! _ipsec_ca_generate_cert "$root" "$country" "$organization" \
	                             "$common_name" "$lifetime_days"    \
	                             "$rsa_keylen"; then
		return 1
	fi

	return 0
}

_ipsec_ca_generate_cert() {
	local root="$1"
	local country="$2"
	local organization="$3"
	local common_name="$4"
	local -i lifetime_days="$5"
	local -i rsa_keylen="$6"
	local flags=("${@:7}")

	local distinguished_name
	local subject_key
	local subject_cert
	local cacert
	local cakey
	local pubkey_data
	local pki_args
	local flag

	if (( lifetime_days == 0 )); then
		lifetime_days="$__ipsec_ca_default_lifetime_days"
	fi

	if (( rsa_keylen == 0 )); then
		rsa_keylen="$__ipsec_ca_default_rsa_keylen"
	fi

	distinguished_name="C=$country,O=$organization,CN=$common_name"
	subject_key="$root/private/$common_name.pem"
        subject_cert="$root/certs/$common_name.pem"
	cacert="$root/cacerts/cacert.pem"
	cakey="$root/private/cakey.pem"

	if ! ipsec_key_new "rsa" "$rsa_keylen" "pem" > "$subject_key"; then
		log_error "Could not generate key for $common_name"
		return 1
	fi

	if ! pubkey_data=$(ipsec_key_get_pubkey "pem" < "$subject_key"); then
		log_error "Could not get public key from $subject_key"

		if ! rm -f "$subject_key"; then
			log_warn "Could not clean up $subject_key"
		fi

		return 2
	fi

	pki_args=(
		--issue
		--lifetime "$lifetime_days"
		--cacert   "$cacert"
		--cakey    "$cakey"
		--dn       "$distinguished_name"
		--san      "$common_name"
		--outform  "pem"
	)
	for flag in "${flags[@]}"; do
		pki_args+=(--flag "$flag")
	done

	if ! pki "${pki_args[@]}" <<< "$pubkey_data" > "$subject_cert"; then
		log_error "Could not issue certificate for $common_name"

		if ! rm -f "$subject_key"; then
			log_warn "Could not clean up $subject_key"
		fi

		return 3
	fi

	return 0
}
