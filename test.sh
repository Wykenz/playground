#!/bin/bash
LIFERAY_VERSION=$1

version_tag="${LIFERAY_VERSION#*-}"
version_end=${LIFERAY_VERSION##*-}
version_front=${LIFERAY_VERSION%.*}

if [[ ${version_tag} =~ "de" ]]
then
	echo "DXP ${version_front} DE${version_end}"
elif [[ ${version_tag} =~ "dxp" ]]
then
	echo "DXP ${version_front} FP${version_end}"
elif [[ ${version_tag} =~ "sp" ]]
then
	echo "DXP ${version_front} ${version_end^^}"
fi