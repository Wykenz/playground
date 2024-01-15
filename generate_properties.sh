#!/bin/bash


function generate_release_properties_file {
	local tomcat_version=$(curl -s https://releases.liferay.com/tools/workspace/.product_info.json | jq -r '."dxp-'${1}'".appServerTomcatVersion')

	local product_version=$(curl -s https://releases.liferay.com/tools/workspace/.product_info.json | jq -r '."dxp-'${1}'".liferayProductVersion')

	local release_date=$(curl -s https://releases.liferay.com/tools/workspace/.product_info.json | jq -r '."dxp-'${1}'".releaseDate')

	local target_platform_version=$(curl -s https://releases.liferay.com/tools/workspace/.product_info.json | jq -r '."dxp-'${1}'".targetPlatformVersion')

	(
		echo "app.server.tomcat.version=${tomcat_version}"
		echo "build.timestamp="
		echo "bundle.checksum.sha512="
		echo "bundle.url="
		echo "git.hash.liferay-docker="
		echo "git.hash.liferay-portal-ee="
		echo "liferay.docker.fix.pack.url="
		echo "liferay.docker.image="
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