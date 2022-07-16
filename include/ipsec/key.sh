#!/bin/bash

# ipsec/key.sh - Toolbox module for key generation for use with IPsec
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
	if ! include "log" "array"; then
		return 1
	fi

	declare -gxr __ipsec_key_default_type="rsa"
	declare -gxra __ipsec_key_supported_types=(
		"rsa"
		"ecdsa"
		"ed25519"
	)
	declare -gxrA __ipsec_key_default_size=(
		["rsa"]=4096
		["ecdsa"]=384
		["ed25519"]=1
	)
	declare -gxr __ipsec_key_default_format="pem"

	return 0
}

ipsec_key_new() {
	local type="$1"
	local -i size="$2"
	local format="$3"

	if [[ -z "$1" ]]; then
		type="$__ipsec_key_default_type"
	fi

	if ! array_contains "$type" "${__ipsec_key_supported_types[@]}"; then
		log_error "Key type \"$type\" not supported"
		return 1
	fi

	if (( size == 0 )); then
		size="${__ipsec_key_default_size[$type]}"
	fi

	if [[ -z "$format" ]]; then
		format="$__ipsec_key_default_format"
	fi

	if ! pki --gen --type "$type" --size "$size" --outform "$format"; then
		return 1
	fi

	return 0
}

ipsec_key_get_pubkey() {
	local format="$1"
	local key="$2"

	if [[ -z "$format" ]]; then
		format="$__ipsec_key_default_format"
	fi

	if [[ -z "$key" ]]; then
		key="/dev/stdin"
	fi

	if ! pki --pub --outform "$format" < "$key"; then
		return 1
	fi

	return 0
}
