#!/usr/bin/env bash
set -euo pipefail

ORGS=(
  "713468743428"
  "532450477381"
)

OUT="org_custom_roles_permissions_long.csv"
echo "org_id,role_name,role_id,title,stage,description,permission,describe_status" > "$OUT"

for ORG in "${ORGS[@]}"; do
  echo "== ORG $ORG ==" >&2

  gcloud iam roles list --organization "$ORG" --format=json \
  | jq -r --arg ORG "$ORG" '
      .[]
      | select(.name | startswith("organizations/" + $ORG + "/roles/"))
      | .name
    ' \
  | while IFS= read -r ROLE_NAME; do
      [[ -z "$ROLE_NAME" ]] && continue
      ROLE_ID="$(cut -d/ -f4 <<<"$ROLE_NAME")"

      if DESC_JSON="$(gcloud iam roles describe "$ROLE_ID" --organization "$ORG" --format=json 2>/dev/null)"; then
        TITLE="$(jq -r '.title // ""' <<<"$DESC_JSON" | sed 's/"/""/g')"
        STAGE="$(jq -r '.stage // ""' <<<"$DESC_JSON" | sed 's/"/""/g')"
        DESCRIPTION="$(jq -r '.description // ""' <<<"$DESC_JSON" | sed 's/"/""/g')"

        jq -r '
          .includedPermissions[]?
        ' <<<"$DESC_JSON" | while IFS= read -r PERM; do
          PERM="${PERM//\"/\"\"}"
          echo "\"$ORG\",\"$ROLE_NAME\",\"$ROLE_ID\",\"$TITLE\",\"$STAGE\",\"$DESCRIPTION\",\"$PERM\",\"OK\"" >> "$OUT"
        done
      else
        # Si no se puede describir, deja una fila marcador
        echo "\"$ORG\",\"$ROLE_NAME\",\"$ROLE_ID\",,,,,\"\",\"DESCRIBE_FAILED\"" >> "$OUT"
      fi
    done
done

echo "OK → $OUT" >&2
