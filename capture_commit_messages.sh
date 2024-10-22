#!/bin/bash


if [ -f .env ]; then
  export $(cat .env | xargs)
fi


if [ -z "$GITHUB_TOKEN" ] || [ -z "$OWNER" ] || [ -z "$REPO" ]; then
  echo "Error: GITHUB_TOKEN, OWNER, and REPO must be set."
  exit 1
fi


BASE_URL="https://api.github.com"
AUTH_HEADER="Authorization: token $GITHUB_TOKEN"


get_prs_to_dev() {
  response=$(curl -s -H "$AUTH_HEADER" \
    -H "Accept: application/vnd.github.v3+json" \
    "$BASE_URL/repos/$OWNER/$REPO/pulls?base=dev&state=all")


  if ! echo "$response" | jq . >/dev/null 2>&1; then
    echo "Error fetching PRs: Invalid JSON response."
    echo "$response"  
    exit 1
  fi

  echo "$response"
}


get_commit_messages() {
  local pr_number=$1
  response=$(curl -s -H "$AUTH_HEADER" \
    -H "Accept: application/vnd.github.v3+json" \
    "$BASE_URL/repos/$OWNER/$REPO/pulls/$pr_number/commits")

  
  if ! echo "$response" | jq . >/dev/null 2>&1; then
    echo "Error fetching commits for PR #$pr_number: Invalid JSON response."
    echo "$response"  
    exit 1
  fi

  echo "$response"
}


capture_commit_messages() {
  echo "Fetching PRs targeting the 'dev' branch..."


  prs=$(get_prs_to_dev)

  pr_count=$(echo "$prs" | jq '. | length')

  if [ "$pr_count" -eq 0 ]; then
    echo "No PRs found targeting the 'dev' branch."
    exit 0
  fi

  echo "Found $pr_count PR(s):"
  
  for ((i = 0; i < pr_count; i++)); do
    pr_number=$(echo "$prs" | jq -r ".[$i].number")
    pr_title=$(echo "$prs" | jq -r ".[$i].title")

    echo -e "\nPR #$pr_number - $pr_title"
    echo "Commit Messages:"

    
    commit_messages=$(get_commit_messages "$pr_number" | jq -r '.[].commit.message')
    if [ -z "$commit_messages" ]; then
      echo "  No commits found for PR #$pr_number."
    else
      echo "$commit_messages" | sed 's/^/  - /'
    fi
  done
}


capture_commit_messages
            
           

































































