#!/bin/bash

source ./_liferay_common.sh

function clean_up_nulls {
	sed -i 's*/null**g' "${MAIN_DIR}"/versions/"${DIR_VERSION}"/release.properties
	sed -i 's/null//g' "${MAIN_DIR}"/versions/"${DIR_VERSION}"/release.properties
	sed -i 's/"//g' "${MAIN_DIR}"/versions/"${DIR_VERSION}"/release.properties
}

function download_zip_files {
	local bundle_archive="${BUNDLE_URL##*/}"

	mkdir -p versions/"${DIR_VERSION}"

	lc_download "https://${LIFERAY_DOCKER_FIX_PACK_URL}" versions/"${DIR_VERSION}"/"${LIFERAY_DOCKER_FIX_PACK_URL##*/}"
	lc_download "https://${LIFERAY_DOCKER_TEST_HOTFIX_URL}" versions/"${DIR_VERSION}"/"${LIFERAY_DOCKER_TEST_HOTFIX_URL##*/}"

	if [[ "${bundle_archive}" == *.7z ]]
	then
		7z e -y downloads/"${DIR_VERSION}"/"${bundle_archive}" -o/"${MAIN_DIR}"/downloads/"${DIR_VERSION}"/ ".githash" -r
	else
		unzip -o downloads/"${DIR_VERSION}"/"${bundle_archive}" -d "${MAIN_DIR}"/downloads/"${DIR_VERSION}"/ ".githash" -x "*.zip"
	fi

	GIT_HASH_LIFERAY_PORTAL_EE=$(cat "${MAIN_DIR}"/downloads/"${DIR_VERSION}"/.githash)

	generate_checksum_files

	rm -r "${MAIN_DIR}"/downloads
}

function get_liferay_version_format {
LIFERAY_VERSION=$(grep -v additional_tags bundles.yml | grep -B 1 -E ".${TIME_STAMP}." | head -1 | tr -d '\r: ')
echo "Current version: ${LIFERAY_VERSION}"
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
	) > "${MAIN_DIR}"/versions/"${DIR_VERSION}"/release.properties
}

function generate_checksum_files {
	local file_name="${BUNDLE_URL##*/}"

	sha512sum downloads/"${DIR_VERSION}"/"${file_name}" | sed -e "s/ .*//"  > "${MAIN_DIR}"/versions/"${DIR_VERSION}"/"${file_name}.sha512"

	BUNDLE_CHECKSUM_SHA512="${file_name}.sha512"
}

function get_time_stamp {
	url="https://releases.liferay.com/dxp/${DIR_VERSION}/"
	filename=$(curl -s "$url" | grep -oP 'href="\K[^"?]+' | grep -vE '\?C=|;O=' | grep -E 'tomcat' | grep -E '\.7z$|\.zip$')
	numeric_part=${filename%.*}
	numeric_part=${numeric_part##*-}
 	TIME_STAMP="${numeric_part}"
}

function get_tomcat_version_from_file {
	local bundle_archive="${1}"
	local name

	mkdir -p downloads/"${DIR_VERSION}"

	lc_download "https://${BUNDLE_URL}" downloads/"${DIR_VERSION}"/"${bundle_archive}"

	if [[ "${bundle_archive}" == *.7z ]]
	then
		name=$(7z l "${bundle_archive}" | grep -m 1 "/tomcat" | tr -d '/')
		echo "${name##*-}"
	else
		name=$(unzip -l "${bundle_archive}" | grep -m 1 "/tomcat" | tr -d '/')
		echo "${name##*-}"
	fi
}

function get_json {
	local version="${1}"
	local tag="${2}"
	local bundle_archive="${BUNDLE_URL##*/}"
	local name

	result=$(curl -s "https://releases.liferay.com/tools/workspace/.product_info.json" | jq '.[] | select(.liferayDockerImage | tostring | test("'${version}'")) | '${tag}'')

	if [[ -z "${result}" ]] && [[ "${tag}" == ".appServerTomcatVersion" ]]
	then
		name=$(get_tomcat_version_from_file "${bundle_archive}")
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

	main_key=$(echo "${LIFERAY_VERSION}" | grep -oE "^[0-9]+\.[0-9]+\.[0-9]+")

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

	mkdir -p "versions"

	while read DIR_VERSION
	do
		get_time_stamp "${DIR_VERSION}"

		if [[ $(grep -c -w "${DIR_VERSION}" bundles.yml) -gt 0 ]]
		then
			lc_time_run set_value
			lc_time_run download_zip_files
			lc_time_run generate_release_properties_file
			lc_time_run clean_up_nulls
		else
			continue
		fi
	done < versions.txt
}

main