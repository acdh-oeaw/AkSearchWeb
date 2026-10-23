#!/usr/bin/env bash
set -euo pipefail

web_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme_dir="${web_dir}/../AkSearchAcdhTheme-vufind10"
extend_dir="${web_dir}/../AkSearchExtend-vufind10"
solr_dir="${web_dir}/../AkSearchSolr-vufind10"
theme_commit="$(git -C "$theme_dir" rev-parse --short=12 HEAD)"
extend_commit="$(git -C "$extend_dir" rev-parse --short=12 HEAD)"

if [[ -n "$(git -C "$theme_dir" status --porcelain --untracked-files=no)" || -n "$(git -C "$extend_dir" status --porcelain --untracked-files=no)" ]]; then
    echo 'Companion worktrees contain uncommitted changes; image labels identify their HEAD commits.' >&2
fi

docker build -t acdhch/aksearch-solr:vufind10 "$solr_dir"
docker build -f "$web_dir/Dockerfile.dev" \
    --build-context "theme=$theme_dir" \
    --build-context "extend=$extend_dir" \
    --build-arg "THEME_COMMIT=$theme_commit" \
    --build-arg "EXTEND_COMMIT=$extend_commit" \
    -t aksearch-vufind10-web:latest "$web_dir"

labels="$(docker image inspect aksearch-vufind10-web:latest --format '{{index .Config.Labels "org.aksearch.theme-commit"}} {{index .Config.Labels "org.aksearch.extend-commit"}}')"
[[ "$labels" == "$theme_commit $extend_commit" ]]
docker run --rm --entrypoint cat aksearch-vufind10-web:latest \
    /usr/local/vufind/themes/AcdhchTheme/templates/RecordDriver/DefaultRecord/data-allSubjectHeadings.phtml \
    | cmp - "$theme_dir/templates/RecordDriver/DefaultRecord/data-allSubjectHeadings.phtml"
docker run --rm --entrypoint cat aksearch-vufind10-web:latest \
    /usr/local/vufind/vendor/acdh-oeaw/aksearch-ext/src/aksearchExt/SolrMarc.php \
    | cmp - "$extend_dir/src/aksearchExt/SolrMarc.php"
printf 'Verified Theme %s and Extend %s in the local Web image.\n' "$theme_commit" "$extend_commit"
