#!/bin/bash

function get_liferay_version_format {
	local url=$(grep -E ".${TIME_STAMP}." bundles.yml)
	local file_url="${url##*: }"
	local base="${file_url%/*}"

	LIFERAY_VERSION="${base##*/}"

}

function generate_release_properties_file {

	(
		echo "app.server.tomcat.version=${TOMCAT_VERSION}"
		echo "build.timestamp=${BUILD_TIMESTAMP}"
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

function get_time_stamp {
	local version="${1}"

	url="https://releases.liferay.com/dxp/${version}/"
	filename=$(curl -s "$url" | grep -oP 'href="\K[^"?]+' | grep -vE '\?C=|;O=' | grep 'tomcat' | grep -E '\.7z$')
	numeric_part=${filename%.*}
	numeric_part=${numeric_part##*-}
 	TIME_STAMP="${numeric_part}"


}

function get_json {
	local version="${1}"
	local tag="${2}"
	local url=$(grep -E ".${TIME_STAMP}." bundles.yml)
	local file_url="${url##*: }"
	local file_name="${file_url##*/}"

	result=$(curl -s "${file_url}" | jq '.[] | select(.liferayDockerImage=="liferay/dxp:'${version}'") | '${tag}'')

	if [[ -n "${result}" ]] && [[ "${tag}" == ".appServerTomcatVersion" ]]
	then
		curl -o "${file_name}" ./"${file_name}"

		##tomcat_folder=$(find <output_directory> -type d -name "tomcat*")
	fi

}

function get_yml {
	local main_key="${1}"
	local version="${2}"
	local tag="${3}"

	yq '."'"${main_key}"'"."'"${version}"'"."'"${tag}"'"' bundles.yml

}

function set_value {
	get_liferay_version_format

	local main_key

	main_key=$(get_main_key "${LIFERAY_VERSION}")

	TOMCAT_VERSION=$(get_json "${LIFERAY_VERSION}" .appServerTomcatVersion)

	BUILD_TIMESTAMP="${TIME_STAMP}"

	BUNDLE_URL=$(get_yml "${main_key}" "${LIFERAY_VERSION}" bundle_url)

	LIFERAY_DOCKER_FIX_PACK_URL=$(get_yml "${main_key}" "${LIFERAY_VERSION}" fix_pack_url)

	LIFERAY_DOCKER_IMAGE="${LIFERAY_VERSION}"

	LIFERAY_DOCKER_TAGS=$(get_yml "${main_key}" "${LIFERAY_VERSION}" additional_tags)

	LIFERAY_DOCKER_TEST_HOTFIX_URL=$(get_yml "${main_key}" "${LIFERAY_VERSION}" test_hotfix_url)

	LIFERAY_DOCKER_TEST_INSTALLED_PATCH=$(get_yml "${main_key}" "${LIFERAY_VERSION}" test_installed_patch)

	PRODUCT_VERSION=$(get_json "${LIFERAY_VERSION}" .liferayProductVersion)

	RELEASE_DATE=$(get_json "${LIFERAY_VERSION}" .releaseDate)

	TARGET_PLATFORM_VERSION=$(get_json "${LIFERAY_VERSION}" .targetPlatformVersion)
}

function main {
	get_time_stamp "${1}"
	give_version_format
	if [[ $(grep -c "${TIME_STAMP}" bundles.yml) -gt 0 ]]
	then
		echo "${TIME_STAMP}"
		echo "It's in bundle.yml"
		#set_value "${1}"
		#generate_release_properties_file
	else
		echo "${TIME_STAMP}"
		echo "It's not in there"
	fi

}

main "${1}"