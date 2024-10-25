#!/bin/bash


if [ -f .env ]; then
  export $(cat .env | xargs)
fi


if [ -z "$GITHUB_TOKEN" ] || [ -z "$OWNER" ] || [ -z "$REPO" ]; then
  echo "Error: GITHUB_TOKEN, OWNER, and REPO must be set."
  exit 1
fi

SENDGRID_API_KEY=$SENDGRID_API_KEY
BASE_URL=$BASE_URL
AUTH_HEADER="Authorization: token $GITHUB_TOKEN"
TO_EMAIL=$TO_EMAIL
FROM_EMAIL=$FROM_EMAIL


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


send_email() {
  local pr_number=$1
  local pr_title=$2
  local pr_body=$3
  local pr_url=$4

  curl --request POST \
    --url https://api.sendgrid.com/v3/mail/send \
    --header "Authorization: Bearer $SENDGRID_API_KEY" \
    --header "Content-Type: application/json" \
    --data '{
      "personalizations": [{
        "to": [{"email": "'"$TO_EMAIL"'"}]
      }],
      "from": {"email": "'"$FROM_EMAIL"'"},
      "subject": "New PR Notification: '"$pr_title"'",
      "content": [{
        "type": "text/plain",
        "value": "PR Number: '"$pr_number"'\nTitle: '"$pr_title"'\nBody:\n'"$pr_body"'\nLink: '"$pr_url"'"
      }]
    }'
}


capture_pr_details() {
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
    pr_body=$(echo "$prs" | jq -r ".[$i].body")
    pr_url=$(echo "$prs" | jq -r ".[$i].html_url")

    echo -e "\nPR #$pr_number - $pr_title"
    echo "Body:"
    if [ -z "$pr_body" ]; then
      pr_body="No body content for PR #$pr_number."
    fi
    echo "$pr_body" | sed 's/^/  - /'

    
    send_email "$pr_number" "$pr_title" "$pr_body" "$pr_url"
  done
}


capture_pr_details
