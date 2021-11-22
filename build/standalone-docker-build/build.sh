#!/bin/bash
#
#  Copyright 2019 The FATE Authors. All Rights Reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

set -e

source_dir=$(cd `dirname $0`; cd ../;cd ../;pwd)
echo "[INFO] source dir: ${source_dir}"
cd ${source_dir}
source ./bin/common.sh

if [[ -n ${1} ]]; then
    version_tag=$1
else
    version_tag="rc"
fi
replace_repo_file=$2

version=`grep "FATE=" fate.env | awk -F '=' '{print $2}'`
standalone_install_package_dir_name="standalone_fate_install_${version}_${version_tag}"
standalone_install_package_dir=${source_dir}/${standalone_install_package_dir_name}

package_dir_name="standalone_fate_docker_${version}_${version_tag}"
package_dir=${source_dir}/${package_dir_name}

image_namespace="federatedai"
image_name="standalone_fate"
if [[ ${version_tag} == ${RELEASE_VERSION_TAG_NAME} ]];then
  image_tag=${version}
else
  image_tag="${version}-${version_tag}"
fi
image_path=${image_namespace}/${image_name}:${image_tag}

echo "[INFO] build info"
echo "[INFO] version: "${version}
echo "[INFO] version tag: "${version_tag}
echo "[INFO] replace repo file: "${replace_repo_file}
echo "[INFO] image namespace: "${image_namespace}
echo "[INFO] image name: "${image_name}
echo "[INFO] image tag: "${image_tag}
echo "[INFO] image path: "${image_path}
echo "[INFO] package output dir is "${package_dir}

rm -rf ${package_dir}
mkdir -p ${package_dir}

build() {
  cd ${source_dir}

  cp ${source_dir}/build/standalone-docker-build/docker-entrypoint.sh ${package_dir}/
  cp ${source_dir}/build/standalone-docker-build/Dockerfile ${package_dir}/

  workdir=${package_dir}/fate
  if [[ -d ${workdir} ]]; then
    rm -rf ${workdir}
  fi
  mkdir -p ${workdir}

  echo "[INFO] get standalone install package"
  if [[ -d ${standalone_install_package_dir} ]];then
    echo "[INFO] standalone install package already exists, skip build"
  else
    sh build/standalone-install-build/build.sh ${version_tag} 1
  fi

  echo "[INFO] copy standalone install package"
  cp -r ${standalone_install_package_dir}/* ${workdir}/
  echo "[INFO] get standalone install package done"

  cd ${workdir}
  cp ${source_dir}/build/standalone-docker-build/init.sh ./
  if [[ -f ${replace_repo_file} ]];then
    cp ${replace_repo_file} ./CentOS-Base.repo
  fi
  tar -cf ../fate.tar ./*
  cd ../

  a=`docker images | grep "${image_namespace}/${image_name}" | grep "${image_tag} " | wc -l`
  if [[ a -ne 0 ]];then
    docker rmi ${image_path}
    if [[ $? -eq 0 ]];then
      echo "rm image ${image_path}"
    else
      echo "please rm image ${image_path}"
      exit 1
    fi
  fi
  docker build -t ${image_path} .

}

packaging() {
  cd ${package_dir}
  image_tar="standalone_fate_docker_image_"${version}_${version_tag}".tar"

  if [[ -f ${image_tar} ]]; then
    rm -rf ${image_tar}
  fi

  docker save ${image_path} -o ${image_tar}
}

usage() {
    echo "usage: $0 {version_tag} {replace_repo_file}"
}


case "$2" in
    usage)
        usage
        ;;
    *)
        build
        packaging
        ;;
esac