#!/bin/bash

set GH_ENVIRONMENT

## Manual trigger - workflow_dispatch
if [[ "${{ inputs.environment }}" != "" ]]; then
  GH_ENVIRONMENT=$(echo "${{ inputs.environment }}" | tr [:upper:] [:lower:])
  GH_DEFAULT_BRANCH=${{ github.event.repository.default_branch }}
  GH_CURRENT_BRANCH=${{ github.ref_name }}

  # The PROD environment can use the $GH_DEFAULT_BRANCH branches
  if [[ "$GH_ENVIRONMENT" == "$GH_ENV_PROD" &&
      "$GH_CURRENT_BRANCH" == "$GH_DEFAULT_BRANCH" ]]; then :

  # TEST and STAGE environments can use the $GH_DEFAULT_BRANCH and release/hotfix branches
  elif [[ "$GH_ENVIRONMENT" =~ ^($GH_ENV_TST|$GH_ENV_STG)$ &&
      "$GH_CURRENT_BRANCH" =~ ^(release|hotfix|$GH_DEFAULT_BRANCH)\/?([a-z0-9._-]*)$ ]]; then :

  # The DEVELOP environment can use the main/master, release/hotfix and develop branches
  elif [[ "$GH_ENVIRONMENT" == "$GH_ENV_DEV" &&
      "$GH_CURRENT_BRANCH" =~ ^(develop|release|hotfix|$GH_DEFAULT_BRANCH)\/?([a-z0-9._-]*)$ ]]; then :

  # The SANDBOX environment can use all branches
  elif [[ "$GH_ENVIRONMENT" == "$GH_ENV_SBX" ]]; then :

  # Exit on invalid condition
  else
    echo "::error::Incorrect environment has been selected. Cannot use environment '${{ inputs.environment }}' for branch '$GH_CURRENT_BRANCH' 👎"
    exit 1
  fi

  GH_ENVIRONMENT=${{ inputs.environment }}

## Automated trigger - workflow_call
# The DEVELOP environment can use the develop branch
elif [[ "$GH_CURRENT_BRANCH" == "develop" ]]; then
  GH_ENVIRONMENT=$GH_ENV_DEV
# The TEST environments can use release/hotfix branches
elif [[ "$GH_CURRENT_BRANCH" =~ ^(release|hotfix)\/([0-9.]+)$ ]]; then
  GH_ENVIRONMENT=$GH_ENV_TST
else
  echo "::error::Cannot define the environment for '$GH_CURRENT_BRANCH' branch 👎"
  exit 1
fi

echo "environment=$GH_ENVIRONMENT" >> "$GITHUB_OUTPUT"

echo "::group::Debug Info"
echo "Branch      - $GH_CURRENT_BRANCH 👍"
echo "Environment - $GH_ENVIRONMENT 👍"
echo "::endgroup::"
