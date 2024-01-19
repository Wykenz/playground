#!/bin/bash

function clean_up_nulls {
	sed -i 's/null//g' release.properties 
}

function download_zip_files {
	mkdir -p downloads
	
	curl -o downloads/"${BUNDLE_URL##*/}" "${BUNDLE_URL}"

}

function get_liferay_version_format {
	local file_url="${url##*: }"
	local base="${file_url%/*}"
	local url

	url=$(grep -E ".${TIME_STAMP}." bundles.yml)
	LIFERAY_VERSION="${base##*/}"

	if [[ "${LIFERAY_VERSION}" =~ ^7\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
	then
		tag="${LIFERAY_VERSION##*.}"
		base="${LIFERAY_VERSION%.*}"
		LIFERAY_VERSION="${base}-sp${tag}"
	fi
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
		echo "liferay.docker.tags=liferay/dxp:${LIFERAY_DOCKER_IMAGE}/${LIFERAY_DOCKER_TAGS}"
		echo "liferay.docker.test.hotfix.url=${LIFERAY_DOCKER_TEST_HOTFIX_URL}"
		echo "liferay.docker.test.installed.patch=${LIFERAY_DOCKER_TEST_INSTALLED_PATCH}"
		echo "liferay.product.version=${PRODUCT_VERSION}"
		echo "release.date=${RELEASE_DATE}" #rewrite this to the correct format
		echo "target.platform.version=${TARGET_PLATFORM_VERSION}"
	) > release.properties
}

function get_time_stamp {
	local version="${1}"

	url="https://releases.liferay.com/dxp/${version}/"
	filename=$(curl -s "$url" | grep -oP 'href="\K[^"?]+' | grep -vE '\?C=|;O=' | grep -E 'tomcat' | grep -E '\.7z$|\.zip$')
	numeric_part=${filename%.*}
	numeric_part=${numeric_part##*-}
 	TIME_STAMP="${numeric_part}"


}

function get_value_from_files {
	local file_name="${1}"
	local name

	if [[ "${tag}" == ".appServerTomcatVersion" ]]
	then
		curl -o ./"${file_name}" "https://${BUNDLE_URL}"
		if [[ "${file_name}" == *.7z ]]
		then
			name=$(7z l "${file_name}" | grep -m 1 "/tomcat")
			echo "${name##*-}"
		else
			name=$(unzip l "${file_name}" | grep -m 1 "/tomcat")
			echo "${name##*-}"
		fi
	fi
	rm -r "${file_name}"
}

function get_json {
	local version="${1}"
	local tag="${2}"
	local file_name="${BUNDLE_URL##*/}"
	local name

	result=$(curl -s "https://releases.liferay.com/tools/workspace/.product_info.json" | jq '.[] | select(.liferayDockerImage=="liferay/dxp:'${version}'") | '${tag}'')

	if [[ -z "${result}" ]]
	then
		name=$(get_value_from_files "${file_name}")
		echo "${name}"
	else
		echo "${result}"
	fi

}

function get_yml {
	local main_key="${1}"
	local version="${2}"
	local tag="${3}"

	result=$(yq '."'"${main_key}"'"."'"${version}"'"."'"${tag}"'"' bundles.yml)

	if [[ -z "${result}" ]]
	then
		echo ""
	else
		echo "${result}"
	fi
}

function set_value {
	get_liferay_version_format

	local main_key

	main_key="${LIFERAY_VERSION%%-*}"

	BUILD_TIMESTAMP="${TIME_STAMP}"

	BUNDLE_URL=$(get_yml "${main_key}" "${LIFERAY_VERSION}" bundle_url)

	TOMCAT_VERSION=$(get_json "${LIFERAY_VERSION}" .appServerTomcatVersion)

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

	if [[ $(grep -c "${TIME_STAMP}" bundles.yml) -gt 0 ]]
	then
		echo "${TIME_STAMP}"
		echo "It's in bundle.yml"

		set_value "${1}"
		download_zip_files
		generate_release_properties_file
	else
		echo "${TIME_STAMP}"
		echo "It's not in bundle.yml"
	fi

	clean_up_nulls

}

main "${1}"