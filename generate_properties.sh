#!/bin/bash

source ./_liferay_common.sh

set -o pipefail

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

	if [[ "${LIFERAY_DOCKER_FIX_PACK_URL}" != null ]]
	then
		lc_download "https://${LIFERAY_DOCKER_FIX_PACK_URL}" versions/"${DIR_VERSION}"/"${LIFERAY_DOCKER_FIX_PACK_URL##*/}"
	else
		lc_log DEBUG "There is no fix_pack_url for ${LIFERAY_VERSION}"
	fi

	if [[ "${LIFERAY_DOCKER_TEST_HOTFIX_URL}" != null ]]
	then
		lc_download "https://${LIFERAY_DOCKER_TEST_HOTFIX_URL}" versions/"${DIR_VERSION}"/"${LIFERAY_DOCKER_TEST_HOTFIX_URL##*/}"
	else
		lc_log DEBUG "There is no hotfix_url for ${LIFERAY_VERSION}"
	fi

	generate_checksum_files "${bundle_archive}"

	rm -rf "${MAIN_DIR}"/downloads
}

function get_liferay_version_format {
	LIFERAY_VERSION=$(grep -v additional_tags bundles.yml | grep -B 1 -E ".${TIME_STAMP}." | head -1 | tr -d '\r: ')

	if [[ -z ${LIFERAY_VERSION} ]]
	then
		lc_log ERROR "LIFERAY_VERSION is not specified, the searched timestamp is ${TIME_STAMP}"
		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function generate_release_properties_file {
	BUNDLE_URL="https://${BUNDLE_URL}"
	LIFERAY_DOCKER_FIX_PACK_URL="https://${LIFERAY_DOCKER_FIX_PACK_URL}"
	LIFERAY_DOCKER_TEST_HOTFIX_URL="https://${LIFERAY_DOCKER_TEST_HOTFIX_URL}"

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
		if ( ! sha512sum "${LIFERAY_COMMON_DOWNLOAD_CACHE_DIR}"/releases-cdn.liferay.com/dxp/"${DIR_VERSION}"/"${bundle_archive}" | sed -e "s/ .*//"  > "${MAIN_DIR}"/versions/"${DIR_VERSION}"/"${bundle_archive}.sha512"	)
		then
			lc_log ERROR "Couldn't generate sha512 for ${DIR_VERSION}"
			exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		else
			BUNDLE_CHECKSUM_SHA512="${bundle_archive}.sha512"
		fi
	else
		BUNDLE_CHECKSUM_SHA512="${bundle_archive}.sha512"
	fi
}

function get_time_stamp {
	url="https://releases-cdn.liferay.com/dxp/${DIR_VERSION}"/
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

	bundle_archive="${MAIN_DIR}"/downloads/"${DIR_VERSION}"/"${bundle_archive}"

	if [[ "${bundle_archive}" == *.7z ]]
	then
		FILE_TOMCAT_VERSION=$(7z l "${bundle_archive}" | grep -m 1 "/tomcat" | tr -d '/')
		FILE_TOMCAT_VERSION="${FILE_TOMCAT_VERSION##*-}"
	else
		FILE_TOMCAT_VERSION=$(unzip -l "${bundle_archive}" | grep -m 1 "/tomcat" | tr -d '/')
		FILE_TOMCAT_VERSION="${FILE_TOMCAT_VERSION##*-}"
	fi
}

function get_json {
	local version="${1}"
	local tag="${2}"
	local bundle_archive="${BUNDLE_URL##*/}"

	result=$(curl -s "https://releases.liferay.com/tools/workspace/.product_info.json" | jq '.[] | select((.liferayDockerImage | tostring) as $image | ($image == "docker pull Liferay/dxp:'${version}'" or $image == "liferay/dxp:'${version}'")) | '${tag}'')

	if [[ -z "${result}" ]]
	then
		if [[ "${tag}" == ".appServerTomcatVersion" ]]
		then
			get_tomcat_version_from_file "${bundle_archive}"
			if [[ "${FILE_TOMCAT_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ -n "${FILE_TOMCAT_VERSION}" ]]
			then
				echo "${FILE_TOMCAT_VERSION}"
			else
				lc_log ERROR "Failed to retrieve tomcat version"
				exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
			fi
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
	
	if [[ -n "${result}" ]]
	then
		echo "${result}"
	else
		lc_log ERROR "Failed to retrieve ${tag} from yml"
		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
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

	if ( ! lc_download "https://${BUNDLE_URL}" "${MAIN_DIR}"/downloads/"${DIR_VERSION}"/"${BUNDLE_URL##*/}")
	then
		lc_log ERROR "Failed to download bundle"
		exti "${LIFERAY_COMMON_CODE_BAD}"
	fi

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
		mkdir -p "${MAIN_DIR}"/downloads/"${DIR_VERSION}"

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