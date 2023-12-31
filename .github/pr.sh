#!/bin/bash

set GH_DEFAULT_BRANCH
set GH_DEPLOY_STATUS
set GH_PR_ACTION
set GH_PR_ACTION_MESSAGE
set GH_PR_MESSAGE
set GH_PR_STATUS

# Create or edit a pull request
gh pr create --draft --fill \
  --base "$GH_DEFAULT_BRANCH" \
  --title "Release v${GITHUB_REF_NAME##*/}" && GH_PR_MESSAGE="PR was created and marked as a draft" || \
  gh pr edit \
    --base "$GH_DEFAULT_BRANCH" \
    --title "Release v${GITHUB_REF_NAME##*/}" && GH_PR_MESSAGE="PR was updated"

# Get deployment outcome. Change PR status to draft if deployment fails
if [[ $GH_DEPLOY_STATUS == "success" ]]; then
  GH_PR_ACTION="add"
  GH_PR_ACTION_MESSAGE="added"
else
  GH_PR_ACTION="remove"
  GH_PR_ACTION_MESSAGE="removed"
fi

# Update labels based on deployment outcome
gh pr edit --${GH_PR_ACTION}-label "$GH_ENVIRONMENT" && \
  GH_PR_MESSAGE+=", label '$GH_ENVIRONMENT' $GH_PR_ACTION_MESSAGE"

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
  if [[ "$GH_ENVIRONMENT" == "$GH_ENV_TST" && $GH_DEPLOY_STATUS == "success" ]]; then
    GH_PR_STATUS="::notice::Use manual deployment of your application to the '$GH_ENV_STG' environment"
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
