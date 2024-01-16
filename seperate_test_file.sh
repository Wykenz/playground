#!/bin/bash

function bundle {
	liferay_docker_test_installed_patch=$(yq '."'"${1%%-*}"'"."'"${1}"'".test_installed_patch' bundles.yml)
	echo "${liferay_docker_test_installed_patch}"

	liferay_docker_fix_pack_url=$(yq '."'"${1%%-*}"'"."'"${1}"'".fix_pack_url' bundles.yml)
	echo "${liferay_docker_fix_pack_url}"

	liferay_docker_test_hotfix_url=$(yq '."'"${1%%-*}"'"."'"${1}"'".test_hotfix_url' bundles.yml)
	echo "${liferay_docker_test_hotfix_url}"

	liferay_docker_tags=$(yq '."'"${1%%-*}"'"."'"${1}"'".additional_tags' bundles.yml)
	echo "${liferay_docker_tags}"
}
bundle "${1}"
