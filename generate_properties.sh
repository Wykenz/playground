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

function generate_release_properties_file {

	(
		echo "app.server.tomcat.version=${TOMCAT_VERSION}"
		echo "build.timestamp="
		echo "bundle.checksum.sha512="
		echo "bundle.url=${BUNDLE_URL}"
		echo "git.hash.liferay-docker="
		echo "git.hash.liferay-portal-ee="
		echo "liferay.docker.fix.pack.url=${LIFERAY_DOCKER_FIX_PACK_URL}"
		echo "liferay.docker.image=liferay/dxp:${LIFERAY_DOCKER_IMAGE}"
		echo "liferay.docker.tags=liferay/dxp:${LIFERAY_DOCKER_IMAGE}${LIFERAY_DOCKER_TAGS}"
		echo "liferay.docker.test.hotfix.url=${LIFERAY_DOCKER_TEST_HOTFIX_URL}"
		echo "liferay.docker.test.installed.patch=${LIFERAY_DOCKER_TEST_INSTALLED_PATCH}"
		echo "liferay.product.version=${PRODUCT_VERSION}"
		echo "release.date=${RELEASE_DATE}" #rewrite this to the correct format
		echo "target.platform.version=${TARGET_PLATFORM_VERSION}"
	) > release.properties
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

function get_value {
	check_version_format "${1}"

	local version
	local main_key

	version=$(check_version_format "${1}")

	main_key=$(get_main_key "${version}")

	TOMCAT_VERSION=$(get_json "${version}" .appServerTomcatVersion)

	BUNDLE_URL=$(get_yml "${main_key}" "${version}" bundle_url)

	LIFERAY_DOCKER_FIX_PACK_URL=$(get_yml "${main_key}" "${version}" fix_pack_url)

	LIFERAY_DOCKER_IMAGE="${version}"

	LIFERAY_DOCKER_TAGS=$(get_yml "${main_key}" "${version}" additional_tags)

	LIFERAY_DOCKER_TEST_HOTFIX_URL=$(get_yml "${main_key}" "${version}" test_hotfix_url)

	LIFERAY_DOCKER_TEST_INSTALLED_PATCH=$(get_yml "${main_key}" "${version}" test_installed_patch)

	PRODUCT_VERSION=$(get_json "${version}" .liferayProductVersion)

	RELEASE_DATE=$(get_json "${version}" .releaseDate)

	TARGET_PLATFORM_VERSION=$(get_json "${version}" .targetPlatformVersion)
}

function main {
	get_value "${1}"
	generate_release_properties_file "${1}"
}

main "${1}"