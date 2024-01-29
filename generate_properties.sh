#!/bin/bash

source ./_liferay_common.sh

function clean_up_nulls {
	sed -i 's*/null**g' "${MAIN_DIR}"/versions/"${DIR_VERSION}"/release.properties
	sed -i 's/null//g' "${MAIN_DIR}"/versions/"${DIR_VERSION}"/release.properties
	sed -i 's/"//g' "${MAIN_DIR}"/versions/"${DIR_VERSION}"/release.properties
}

function download_zip_files {
	local bundle_archive="${BUNDLE_URL##*/}"
	echo "${bundle_archive}"
	mkdir -p versions/"${DIR_VERSION}"

	if [[ "${bundle_archive}" == *.7z ]]
	then
		if ( ! 7z e -y "${MAIN_DIR}"/downloads/"${DIR_VERSION}"/"${bundle_archive}" -o/"${MAIN_DIR}"/downloads/"${DIR_VERSION}"/ ".githash" -r )
		then
			lc_log "ERROR" "There is no .githash in the 7z file"
		fi
	else
		if ( ! unzip -o "${MAIN_DIR}"/downloads/"${DIR_VERSION}"/"${bundle_archive}" -d "${MAIN_DIR}"/downloads/"${DIR_VERSION}" ".githash" -x "*.zip" )
		then
			lc_log "ERROR" "There is no .githash in the zip file"
		fi
	fi

	GIT_HASH_LIFERAY_PORTAL_EE=$(cat "${MAIN_DIR}"/downloads/"${DIR_VERSION}"/.githash)

	lc_download "https://${LIFERAY_DOCKER_FIX_PACK_URL}" versions/"${DIR_VERSION}"/"${LIFERAY_DOCKER_FIX_PACK_URL##*/}"

	lc_download "https://${LIFERAY_DOCKER_TEST_HOTFIX_URL}" versions/"${DIR_VERSION}"/"${LIFERAY_DOCKER_TEST_HOTFIX_URL##*/}"

	generate_checksum_files "${bundle_archive}"

	rm -rf "${MAIN_DIR}"/downloads
}

function get_liferay_version_format {
	LIFERAY_VERSION=$(grep -v additional_tags bundles.yml | grep -B 1 -E ".${TIME_STAMP}." | head -1 | tr -d '\r: ')

	if [[ -z ${LIFERAY_VERSION} ]]
	then
		lc_log ERROR "LIFERAY_VERSION is not specified"
		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
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
		echo "release.date=${RELEASE_DATE}"
		echo "target.platform.version=${TARGET_PLATFORM_VERSION}"
	) > "${MAIN_DIR}"/versions/"${DIR_VERSION}"/release.properties
}

function generate_checksum_files {
	local bundle_archive="${1}"

	if ( ! sha512sum downloads/"${DIR_VERSION}"/"${bundle_archive}" | sed -e "s/ .*//"  > "${MAIN_DIR}"/versions/"${DIR_VERSION}"/"${bundle_archive}.sha512")
	then
		lc_log ERROR "Failed to generate sha521"
		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	BUNDLE_CHECKSUM_SHA512="${bundle_archive}.sha512"
}

function get_time_stamp {
	url="https://releases.liferay.com/dxp/${DIR_VERSION}"/
	filename=$(curl -s "$url" | grep -oP 'href="\K[^"?]+' | grep -vE '\?C=|;O=' | grep -E 'tomcat' | grep -E '\.7z$|\.zip$')
	numeric_part=${filename%.*}
	numeric_part=${numeric_part##*-}
 	TIME_STAMP="${numeric_part}"

	if [[ -z "${TIME_STAMP}" ]]
	then
		lc_log ERROR "Failed to retrieve timestamp"
		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function get_tomcat_version_from_file {
	local bundle_archive="${1}"
	local name

	mkdir -p "${MAIN_DIR}"/downloads/"${DIR_VERSION}"

	if ( lc_download "https://${BUNDLE_URL}" "${MAIN_DIR}"/downloads/"${DIR_VERSION}"/"${bundle_archive}" )
	then
		bundle_archive="${MAIN_DIR}"/downloads/"${DIR_VERSION}"/"${bundle_archive}"

		if [[ "${bundle_archive}" == *.7z ]]
		then
			name=$(7z l "${bundle_archive}" | grep -m 1 "/tomcat" | tr -d '/')
			echo "${name##*-}"
		else
			name=$(unzip -l "${bundle_archive}" | grep -m 1 "/tomcat" | tr -d '/')
			echo "${name##*-}"
		fi
	else
		lc_log ERROR "Failed to download bundle file for tomcat"
		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function get_json {
	local version="${1}"
	local tag="${2}"
	local bundle_archive="${BUNDLE_URL##*/}"
	local name

	result=$(curl -s "https://releases.liferay.com/tools/workspace/.product_info.json" | jq '.[] | select(.liferayDockerImage | tostring | test("'${version}'")) | '${tag}'')

	if [[ -z "${result}" ]]
	then
		if [[ "${tag}" == ".appServerTomcatVersion" ]]
		then
			name=$(get_tomcat_version_from_file "${bundle_archive}")

			echo "${name}"
		else
			echo ""
		fi
	else
		echo "${result}"
	fi

}

function get_yml {
	local main_key="${1}"
	local version="${2}"
	local tag="${3}"

	result=$(yq '."'"${main_key}"'"."'"${version}"'"."'"${tag}"'"' bundles.yml)
	
	echo "${result}"
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
		LIFERAY_COMMON_LOG_DIR="${MAIN_DIR}"/logs/"${DIR_VERSION}"
		if [[ $(grep -c -w "${DIR_VERSION}" bundles.yml) -gt 0 ]]
		then
			lc_time_run get_time_stamp "${DIR_VERSION}"
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