#!/bin/bash

function kustomize_build {
    # gather output
    echo "build: info: kustomize build in directory ${kustomize_build_dir}."
    build_output=$(kustomize build ${kustomize_build_dir} 2>&1)

    build_exit_code=${?}

    # exit code 0 - success
    if [ ${build_exit_code} -eq 0 ];then
        build_comment_status="Success"
        echo "build: info: successfully executed kustomize build in ${kustomize_build_dir}."
        echo "${build_output}"
        echo
    fi

    if [ -n ${kustomize_set_image} ]; then
      echo "set image: info: set image ${kustomize_set_image}"
      cd ${kustomize_build_dir}
      set_image_output=$(kustomize edit set image ${kustomize_set_image} 2>&1)
      cd -
      set_image_exit_code=${?}

      # exit code 0 - success
      if [ ${set_image_exit_code} -eq 0 ]; then
          echo "set image: info: successfully set image ${kustomize_set_image}."
          echo "${set_image_output}"
          echo
      fi
    fi

    # exit code !0 - failure
    if [ ${build_exit_code} -ne 0 ]; then
        build_comment_status="Failed"
        echo "build: error: failed to execute kustomize build in ${kustomize_build_dir}."
        echo "${build_output}"
        echo
    fi

    # write output to file
    if [ -n ${kustomize_output_file} ]; then
      echo "build: writing output to ${kustomize_output_file}"
      cat > "${kustomize_output_file}" <<EOF
${build_output}
EOF
    fi

    # comment
    if [ "${GITHUB_EVENT_NAME}" == "pull_request" ] && [ "${kustomize_comment}" == "1" ]; then
        build_comment_wrapper="#### \`kustomize build\` ${build_comment_status}
<details><summary>Show Output</summary>

\`\`\`
${build_output}
 \`\`\`
</details>

*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`, Build Directory: \`${kustomize_build_dir}\`*"

        echo "build: info: creating json"
        build_payload=$(echo "${build_comment_wrapper}" | jq -R --slurp '{body: .}')
        build_comment_url=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)
        echo "build: info: commenting on the pull request"
        echo "${build_payload}" | curl -s -S -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" --header "Content-Type: application/json" --data @- "${build_comment_url}" > /dev/null
    fi

    echo ::set-output name=kustomize_build_output::${build_output}
    exit ${build_exit_code}
}
