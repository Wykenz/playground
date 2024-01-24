#!/bin/bash

source ./_liferay_common.sh

function clean_up_nulls {
	sed -i 's*/null**g' "${MAIN_DIR}"/versions/"${LIFERAY_VERSION}"/release.properties
	sed -i 's/null//g' "${MAIN_DIR}"/versions/"${LIFERAY_VERSION}"/release.properties
	sed -i 's/"//g' "${MAIN_DIR}"/versions/"${LIFERAY_VERSION}"/release.properties
}

function download_zip_files {
	local archive="${BUNDLE_URL##*/}"

	mkdir -p versions/"${LIFERAY_VERSION}"
	mkdir -p versions/downloads/"${LIFERAY_VERSION}"

	lc_download "https://${BUNDLE_URL}" versions/downloads/"${LIFERAY_VERSION}"/"${archive}"

	lc_download "https://${LIFERAY_DOCKER_FIX_PACK_URL}" versions/"${LIFERAY_VERSION}"/"${archive}"

	lc_download "https://${LIFERAY_DOCKER_TEST_HOTFIX_URL}" versions/"${LIFERAY_VERSION}"/"${LIFERAY_DOCKER_TEST_HOTFIX_URL##*/}"

	7z e -y versions/downloads/"${LIFERAY_VERSION}"/"${archive}" -o/"$PWD"/downloads/"${LIFERAY_VERSION}"/ ".githash" -r

	GIT_HASH_LIFERAY_PORTAL_EE=$(cat /"${MAIN_DIR}"/downloads/"${LIFERAY_VERSION}"/.githash)

	generate_checksum_files

	rm -r "${MAIN_DIR}"/versions/downloads
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
		echo "bundle.checksum.sha512=${BUNDLE_CHECKSUM_SHA512}"
		echo "bundle.url=${BUNDLE_URL}"
		echo "git.hash.liferay-docker="
		echo "git.hash.liferay-portal-ee=${GIT_HASH_LIFERAY_PORTAL_EE}"
		echo "liferay.docker.fix.pack.url=${LIFERAY_DOCKER_FIX_PACK_URL}"
		echo "liferay.docker.image=liferay/dxp:${LIFERAY_DOCKER_IMAGE}"
		echo "liferay.docker.tags=liferay/dxp:${LIFERAY_DOCKER_IMAGE}/${LIFERAY_DOCKER_TAGS}"
		echo "liferay.docker.test.hotfix.url=${LIFERAY_DOCKER_TEST_HOTFIX_URL}"
		echo "liferay.docker.test.installed.patch=${LIFERAY_DOCKER_TEST_INSTALLED_PATCH}"
		echo "liferay.product.version=${PRODUCT_VERSION}"
		echo "release.date=${RELEASE_DATE}" #rewrite this to the correct format
		echo "target.platform.version=${TARGET_PLATFORM_VERSION}"
	) > "${MAIN_DIR}"/versions/"${LIFERAY_VERSION}"/release.properties
}

function generate_checksum_files {
	local file_name="${BUNDLE_URL##*/}"

	sha512sum versions/downloads/"${LIFERAY_VERSION}"/"${file_name}" | sed -e "s/ .*//"  > "${MAIN_DIR}"/versions/"${LIFERAY_VERSION}"/"${file_name}.sha512"

	BUNDLE_CHECKSUM_SHA512="${file_name}.sha512"
}

function get_time_stamp {
	local version="${1}"

	url="https://releases.liferay.com/dxp/${version}/"
	filename=$(curl -s "$url" | grep -oP 'href="\K[^"?]+' | grep -vE '\?C=|;O=' | grep -E 'tomcat' | grep -E '\.7z$|\.zip$')
	numeric_part=${filename%.*}
	numeric_part=${numeric_part##*-}
 	TIME_STAMP="${numeric_part}"


}

function get_tomcat_version_from_file {
	local file_name="${1}"
	local name

		curl -o ./"${file_name}" "https://${BUNDLE_URL}"
		if [[ "${file_name}" == *.7z ]]
		then
			name=$(7z l "${file_name}" | grep -m 1 "/tomcat")
			echo "${name##*-}"
		else
			name=$(unzip l "${file_name}" | grep -m 1 "/tomcat")
			echo "${name##*-}"
		fi
	rm -r "${file_name}"
}

function get_json {
	local version="${1}"
	local tag="${2}"
	local file_name="${BUNDLE_URL##*/}"
	local name

	result=$(curl -s "https://releases.liferay.com/tools/workspace/.product_info.json" | jq '.[] | select(.liferayDockerImage | tostring | test("'${version}'")) | '${tag}'')

	if [[ -z "${result}" ]] && [[ "${tag}" == ".appServerTomcatVersion" ]]
	then
		name=$(get_tomcat_version_from_file "${file_name}")
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
	local date

	date=$(get_json "${LIFERAY_VERSION}" .releaseDate)

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

	if [ -n "${date}" ]
	then
		RELEASE_DATE=$(date -d "${date//\"/}" +"%Y-%-m-%-d")
	fi
	
	TARGET_PLATFORM_VERSION=$(get_json "${LIFERAY_VERSION}" .targetPlatformVersion)
}

function main {
	MAIN_DIR="${PWD}"
	version=$1
	mkdir -p "versions"

	#while read version; do
		get_time_stamp "${version}"

		if [[ $(grep -c "${TIME_STAMP}" bundles.yml) -gt 0 ]]
		then
			set_value "${version}"
			download_zip_files
			generate_release_properties_file
			clean_up_nulls
		#else
			#continue
		fi
	#done < versions.txt

}

main $1