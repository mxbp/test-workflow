#!/bin/bash

set GH_PR_MESSAGE
set GH_PR_STATUS
set GH_PR_ACTION

# Create or edit a pull request
gh pr create --draft --fill \
  --base "${{ github.event.repository.default_branch }}" \
  --title "Release v${GITHUB_REF_NAME##*/}" && GH_PR_MESSAGE="PR was created and marked as a draft" || \
  gh pr edit \
    --base "${{ github.event.repository.default_branch }}" \
    --title "Release v${GITHUB_REF_NAME##*/}" && GH_PR_MESSAGE="PR was updated"

# Get deployment outcome. Change PR status to draft if deployment fails
if [[ ${{ steps.deploy.outcome }} == "success" ]]; then
  GH_PR_ACTION="add"
else
  GH_PR_ACTION="remove"
fi

# Update labels based on deployment outcome
gh pr edit --${GH_PR_ACTION}-label "$GH_ENVIRONMENT" && \
  GH_PR_MESSAGE+=", label '$GH_ENVIRONMENT' ${GH_PR_ACTION}d"

# Get specific labels
GH_LABEL_TST=false
GH_LABEL_STG=false

while IFS= read -r GH_LABEL; do
  case $GH_LABEL in
    "$GH_ENV_TST") GH_LABEL_TST=true ;;
    "$GH_ENV_STG") GH_LABEL_STG=true ;;
  esac
done < <(gh pr view --json labels --jq '.labels[].name')

# Reset label status and move PR to draft if deploying to TEST environment
if [[ "$GH_ENVIRONMENT" == "$GH_ENV_TST" && "$GH_LABEL_STG" == true ]]; then
  gh pr edit --remove-label "$GH_ENV_STG" && \
    GH_PR_MESSAGE+=", label '$GH_ENV_STG' removed"
fi

# Check for specific labels and update PR status
if $GH_LABEL_TST && $GH_LABEL_STG; then
  gh pr ready && GH_PR_STATUS="Pull request has been updated, marked as 'ready for review' 👍"
else
  gh pr ready --undo
  if [[ "$GH_ENVIRONMENT" == "$GH_ENV_TST" && ${{ steps.deploy.outcome }} == "success" ]]; then
    GH_PR_STATUS="Use manual deployment of your application to the '$GH_ENV_STG' environment"
  elif [[ "$GH_ENVIRONMENT" == "$GH_ENV_STG" ]]; then
    GH_PR_STATUS="::warning::Check that your application has been successfully deployed to '$GH_ENV_TST' environment"
  else
    GH_PR_STATUS="::warning::Check that your application has been successfully deployed to '$GH_ENV_TST' and '$GH_ENV_STG' environments"
  fi
fi

echo "::group::Debug Info"
echo "$GH_PR_MESSAGE"
echo "$GH_PR_STATUS"
echo "::endgroup::"