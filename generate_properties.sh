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

function generate_release_properties_file {

	check_version_format "${1}"

	local version=$(check_version_format "${1}")

	local tomcat_version=$(curl -s https://releases.liferay.com/tools/workspace/.product_info.json | jq '.[] | select(.liferayDockerImage=="liferay/dxp:'${version}'") | .appServerTomcatVersion')

	local product_version=$(curl -s https://releases.liferay.com/tools/workspace/.product_info.json | jq '.[] | select(.liferayDockerImage=="liferay/dxp:'${version}'") | .liferayProductVersion')

	local release_date=$(curl -s https://releases.liferay.com/tools/workspace/.product_info.json | jq '.[] | select(.liferayDockerImage=="liferay/dxp:'${version}'") | .releaseDate')

	local target_platform_version=$(curl -s https://releases.liferay.com/tools/workspace/.product_info.json | jq '.[] | select(.liferayDockerImage=="liferay/dxp:'${version}'") | .targetPlatformVersion')

	get_main_key "${version}"

	local main_key=$(get_main_key "${version}")

	local bundle_url=$(yq '."'"${main_key}"'"."'"${version}"'".bundle_url' < bundles.yml)

	local liferay_docker_image="${version}"

	(
		echo "app.server.tomcat.version=${tomcat_version}"
		echo "build.timestamp="
		echo "bundle.checksum.sha512="
		echo "bundle.url=${bundle_url}"
		echo "git.hash.liferay-docker="
		echo "git.hash.liferay-portal-ee="
		echo "liferay.docker.fix.pack.url="
		echo "liferay.docker.image=liferay/dxp:${liferay_docker_image}"
		echo "liferay.docker.tags="
		echo "liferay.docker.test.hotfix.url="
		echo "liferay.docker.test.installed.patch="
		echo "liferay.product.version=${product_version}"
		echo "release.date=${release_date}" #rewrite this to the correct format
		echo "target.platform.version=${target_platform_version}"
	) > release.properties
}

function main {
	generate_release_properties_file "${1}"
}

main "${1}"