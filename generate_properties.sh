#!/bin/bash

function check_version_format {
	local version=${1}

	if [[ "${version}" =~ ^7\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
	then
		tag="${version##*.}"
		base="${version%.*}"
		echo "${base}-sp${tag}"
	else
		echo "${version}"
	fi

}

function get_main_key {
	local key="${1}"

	echo "${key%%-*}"
}

function get_json {
	local version="${1}"
	local tag="${2}"

	curl -s https://releases.liferay.com/tools/workspace/.product_info.json | jq '.[] | select(.liferayDockerImage=="liferay/dxp:'${version}'") | '${tag}''

}

function get_yml {
	local main_key="${1}"
	local version="${2}"
	local tag="${3}"

	yq '."'"${main_key}"'"."'"${version}"'"."'"${tag}"'"' bundles.yml

}

function generate_release_properties_file {

	check_version_format "${1}"

	local version=$(check_version_format "${1}")

	local tomcat_version=$(get_json ${version} .appServerTomcatVersion)

	local product_version=$(get_json ${version} .liferayProductVersion)

	local release_date=$(get_json ${version} .releaseDate)

	local target_platform_version=$(get_json ${version} .targetPlatformVersion)

	local main_key=$(get_main_key "${version}")

	local bundle_url=$(get_yml "${main_key}" "${version}" bundle_url)

	local liferay_docker_image="${version}"

	local liferay_docker_test_installed_patch=$(get_yml "${main_key}" "${version}" test_installed_patch)

	local liferay_docker_fix_pack_url=$(get_yml "${main_key}" "${version}" fix_pack_url)

	local liferay_docker_test_hotfix_url=$(get_yml "${main_key}" "${version}" test_hotfix_url)

	local liferay_docker_tags=$(get_yml "${main_key}" "${version}" additional_tags)

	(
		echo "app.server.tomcat.version=${tomcat_version}"
		echo "build.timestamp="
		echo "bundle.checksum.sha512="
		echo "bundle.url=${bundle_url}"
		echo "git.hash.liferay-docker="
		echo "git.hash.liferay-portal-ee="
		echo "liferay.docker.fix.pack.url=${liferay_docker_fix_pack_url}"
		echo "liferay.docker.image=liferay/dxp:${liferay_docker_image}"
		echo "liferay.docker.tags=liferay/dxp:${liferay_docker_image}${liferay_docker_tags}"
		echo "liferay.docker.test.hotfix.url=${liferay_docker_test_hotfix_url}"
		echo "liferay.docker.test.installed.patch=${liferay_docker_test_installed_patch}"
		echo "liferay.product.version=${product_version}"
		echo "release.date=${release_date}" #rewrite this to the correct format
		echo "target.platform.version=${target_platform_version}"
	) > release.properties
}

function main {
	generate_release_properties_file "${1}"
}

main "${1}"