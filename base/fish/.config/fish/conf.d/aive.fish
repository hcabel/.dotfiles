set -gx CLOUDSDK_CONFIG "$HOME/.config/gcloud"
set -gx GOOGLE_APPLICATION_CREDENTIALS "$HOME/.config/gcloud/application_default_credentials.json"

if status is-interactive
    if test -f '/home/hcabel/google-cloud-sdk/path.fish.inc'
        source '/home/hcabel/google-cloud-sdk/path.fish.inc'
    end

    if test -f '/home/hcabel/google-cloud-sdk/completion.fish.inc'
        source '/home/hcabel/google-cloud-sdk/completion.fish.inc'
    end
end

function portfwd
    sudo -E kubefwd -A --tui -d staging -n default --kubeconfig=$HOME/.kube/config
end

function aive
    cd ~/aive/;
    if test (count $argv) -eq 0
        echo "Usage: aive <package> [args...]"
        return 1
    end

    set pkg $argv[1]
    set args $argv[2..-1]

    aivebuild $pkg
    set build_status $status
    if test $build_status -ne 0
        echo "Build failed for package $pkg"
        notify-send "Build failed: '$pkg'"
        return $build_status
    end
    if test $pkg = "graphql" -o $pkg = "sql"
        return
    end
    aiverun $pkg $args
end
function aivemake
    aive $argv
end

function aivebuild
    cd ~/aive/;
    if test (count $argv) -eq 0
        echo "Usage: aivebuild <package> [args...]"
        return 1
    end

    set pkg $argv[1]
    set args $argv[2..-1]

    make build pkg=$pkg $args
end

function aiverun
    cd ~/aive/;
    if test (count $argv) -eq 0
        echo "Usage: aiverun <package> [args...]"
        return 1
    end

    set pkg $argv[1]
    set args $argv[2..-1]

    if string match "*-app" $pkg
        make serve pkg=$pkg $args
    else if string match "analyser-*" $pkg
        bin/$pkg $args
    else
        source bin/$pkg.env; and bin/$pkg $args
    end
end
function aivestart
    aiverun $argv
end

function aivetest
    cd ~/aive/;
    if test (count $argv) -eq 0
        echo "Usage: aivetest <package> [args...]"
        return 1
    end

    set pkg $argv[1]
    set args $argv[2..-1]

    make test pkg=$pkg $args
end

function aivefmtgo
    cd ~/aive/;
    set pkgs (rg -l "type=go" (fd pkg "./src") | sed -E 's|./src/(.*)/pkg$|\\1|' | sort -u)
    for pkg in $pkgs
        echo "Running gofmt on package: $pkg"
        make fmt pkg=$pkg
        if test $status -ne 0
            echo "🚨 gofmt failed for package $pkg"
            notify-send "🚨 gofmt failed for package $pkg"
            return 1
        else
            echo "✅ gofmt succeeded for package $pkg"
        end
    end
end

function aivepipeline
    cd ~/aive/;
    set pkgs (tools/list-changed-packages.py origin/main | jq '.[]' -r | sort)
    aivepipeline_inner $pkgs
    return $status
end

function aivepipelineall
    cd ~/aive/;
    set pkgs (fd pkg "./src" | sed -E 's|^./src/([^/]+)/.*$|\1|' | sort -u)
    aivepipeline_inner $pkgs
    return $status
end

function aivepipelinego
    cd ~/aive/;
    set pkgs (rg -l "type=go" (fd pkg "./src") | sed -E 's|./src/(.*)/pkg$|\\1|' | sort -u)
    aivepipeline_inner $pkgs
    return $status
end

function aivepipeline_inner
    for pkg in $argv
        echo " "
        echo " "
        echo "------------------------------------"
        echo " $pkg  "
        echo ""
        if not string match -q '*/*' -- $pkg
            make build-ci pkg=$pkg
            if test $status -ne 0
                echo ""
                echo "🚨 Build failed for package $pkg"
                echo "------------------------------------"
                notify-send "🚨 Build failed for package $pkg"
                return 1
            end
        end
        make test-ci pkg=$pkg
        if test $status -ne 0
            echo ""
            echo "🚨 Tests failed for package $pkg"
            echo "------------------------------------"
            notify-send "🚨 Tests failed for package $pkg"
            return 1
        else
            echo ""
            echo "✅ Package $pkg passed all checks!"
            echo "------------------------------------"
        end
    end
end

function kubediff
    cd ~/stack/;
    if test (count $argv) -gt 0
        set target $argv[1]
    else
        set target "staging-main"
    end

    kubectl diff -k k8s/$target/ | grep -E '^(\+|-)'
end

function kubeapply
    cd ~/stack/;
    if test (count $argv) -gt 0
        set target $argv[1]
    else
        set target "staging-main"
    end

    kubectl apply -k k8s/$target/ | grep -v unchanged
end

function kconfig -d "fetch configMap for a given service in current context via kubectl"
    kubectl get configMap/$argv -o json | jq '.data.LOGGER_FORMAT = "text" | .data | to_entries[] | "export "+.key+"=\""+.value+"\""' -r
end

function kuberestartedpods
    kubectl get pods | grep -e "\s[0-9]\{1,2\}\(m\|s\)\$"
end

function naive
    cd ~/aive/;
    nvim .;
end

function update-credentials
    kubectl get secret main-bucket-operator-credentials -o json | jq '.data["application_default_credentials.json"]' -r | base64 -d > /home/hcabel/.config/gcloud/main-bucket-operator.json
    cp ~/.config/gcloud/main-bucket-operator.json ~/.config/gcloud/application_default_credentials.json
end

function aivetag
    set -l tags $argv
    while test (count $tags) -gt 0
        set -l chunk
        if test (count $tags) -ge 3
            set chunk $tags[1..3]
            set -e tags[1..3]
        else
            set chunk $tags
            set tags
        end
        git push origin tag $chunk
    end
end

function aivetag_update -d "Update kustomization.yaml image tags based on arguments"
    set file_path ~/stack/k8s/staging-main/kustomization.yaml

    if test (count $argv) -eq 0
        echo "⚠️  No tags provided."
        echo "Usage: aivetag_update <tag1> <tag2> ..."
        return 1
    end

    if not test -f $file_path
        echo "❌ Error: File not found at $file_path"
        return 1
    end

    for line in $argv
        set match (string match -r '^(.*)-(v[0-9].*)$' $line)

        if test -z "$match"
            echo "⚠️  Skipping malformed tag format: $line"
            continue
        end

        set app_name $match[2]
        set new_tag $match[3]

        if test "$app_name" = "analyser-procesor"
            set app_name "analyser-processor"
        end

        awk -v app="aivetech/$app_name" -v tag="$new_tag" '
            $0 ~ "name:[[:space:]]*" app {
                print
                getline
                sub(/newTag:[[:space:]]*.*/, "newTag: " tag)
                print
                next
            }
            {print}
        ' $file_path > $file_path.tmp

        mv $file_path.tmp $file_path

        echo "✅ Updated aivetech/$app_name -> $new_tag"
    end

    echo ""
    echo "🎉 All done! Your kustomization.yaml has been successfully updated."
end

function aivedeploy -d "End-to-end deploy: tag, push, update, commit, and diff"
    if test (count $argv) -lt 3
        echo "⚠️  Not enough arguments provided."
        echo "Usage: aivedeploy <ticket_id> [patch|minor|major] [services...]"
        return 1
    end
    set ticket_id $argv[1]
    set version_level $argv[2]
    set app_names $argv[3..-1]
    if not string match -q -r '^PF-[0-9]+$' $ticket_id
        echo "⚠️  Invalid ticket ID: $ticket_id"
        echo "Usage: aivedeploy <ticket_id> [patch|minor|major] [services...]"
        return 1
    end
    if not string match -q -r '^(patch|minor|major)$' $version_level
        echo "⚠️  Invalid version level: $version_level"
        echo "Usage: aivedeploy <ticket_id> [patch|minor|major] [services...]"
        return 1
    end

    echo "📁 ~/aive..."
    cd ~/aive || begin
        echo "❌ Error: Could not change directory to ~/aive"
        return 1
    end

    set current_branch (git branch --show-current)
    if test "$current_branch" != "main"
        echo "❌ Error: Must be on 'main' branch to deploy. Currently on '$current_branch'. Aborting."
        return 1
    end
    set current_commit_tags (git tag --points-at HEAD)
    for app in $app_names
        for existing_tag in $current_commit_tags
            if string match -q -r -- "^$app-v" "$existing_tag"
                echo "❌ Error: '$app' is already tagged on this commit as '$existing_tag'. Aborting to prevent duplicate bumps."
                return 1
            end
        end
    end

    echo "🚀 Running auto-tag..."
    set tags (~/aive/tools/auto-tag $version_level $app_names)
    if test (count $tags) -eq 0
        echo "⚠️  No tags were output by auto-tag. Aborting deploy."
        return 1
    end

    set suspicious_tag 0
    for t in $tags
        if string match -q -r -- '-(v1\.0\.0|v0\.1\.0|v0\.0\.1)$' $t
            echo "- $t ⚠️"
            set suspicious_tag 1
        else
            echo "- $t"
        end
    end
    if test $suspicious_tag -eq 1
        echo "👀 At least one tag looks like a brand new first version (possible typo?)."
        read -P "Is this expected? [y/N]: " confirm
        if not string match -q -r -i '^y(es)?$' "$confirm"
            echo "🗑️  Rolling back... deleting locally created tags:"
            for t in $tags
                git tag -d $t
            end
            echo "❌ Deploy aborted to prevent bad tags."
            return 1
        end
    end

    echo ""
    echo "💬 --- COPY FOR SLACK ---"
    echo "https://aive.atlassian.net/browse/$ticket_id"
    for t in $tags
        echo "- `$t`"
    end
    echo "-------------------------"
    echo ""

    echo "☁️  Pushing tags to git..."
    aivetag $tags

    echo "📁 ~/stack..."
    cd ~/stack || begin
        echo "❌ Error: Could not change directory to ~/stack"
        return 1
    end

    set has_changes (git status --porcelain)
    if test -n "$has_changes"
        echo "📦 Uncommitted changes detected in ~/stack. Stashing..."
        git stash
    end

    echo "⬇️ Pulling latest changes from git..."
    git pull || begin
        echo "❌ Error: Failed to git pull in ~/stack. Please resolve issues manually."
        return 1
    end

    echo "📝 Updating kustomization.yaml..."
    aivetag_update $tags

    echo "💾 Committing changes to stack..."

    set commit_message "$ticket_id $tags"
    git add k8s/staging-main/kustomization.yaml
    git commit -m "$commit_message"
    echo "✅ Created commit: \"$commit_message\""

    echo ""
    echo "🔍 Running kubediff..."
    kubediff

    echo ""
    read -P "🤔 Do you want to apply this diff? [y/N]: " apply_confirm
    if not string match -q -r -i '^y(es)?$' "$apply_confirm"
        echo "🛑 Deployment paused. Changes are committed but not applied."
        return 0
    end

    echo "⏳ Waiting for Docker images to finish building..."
    set pending_tags $tags
    set ready_tags
    set num_tags (count $tags)
    set first_run 1

    while test (count $pending_tags) -gt 0
        # If it's not the first run, move the cursor UP by the number of tags
        if test $first_run -eq 0
            printf "\033[%dA" $num_tags
        end
        set first_run 0

        set new_pending

        for t in $tags
            if contains $t $ready_tags
                # \033[2K\r clears the line so we don't leave text artifacts behind
                printf "\033[2K\r  ✅ %s\n" $t
            else
                set image_tag "aivetech/"(string replace -r -- '-(v[0-9].*)$' ':$1' $t)

                if docker manifest inspect $image_tag >/dev/null 2>&1
                    printf "\033[2K\r  ✅ %s\n" $t
                    set -a ready_tags $t
                else
                    printf "\033[2K\r  ⏳ %s...\n" $t
                    set -a new_pending $t
                end
            end
        end

        set pending_tags $new_pending

        if test (count $pending_tags) -gt 0
            sleep 15
        end
    end
    echo "🎉 All Docker images are ready!"

    echo ""
    echo "🚀 Applying changes to cluster..."
    kubeapply

    set app_names
    for t in $tags
        set app_name (string replace -r -- '-v[0-9].*$' '' $t)
        set -a app_names $app_name
    end
    set grep_pattern (string join "|" $app_names)

    echo ""
    echo "👀 Monitoring pods for: $grep_pattern"
    sleep 5

    # Track how many lines we printed in the last loop
    set prev_lines 0
    while true
        set current_pods (kubectl get pods | grep -E "$grep_pattern")

        # If we printed lines previously, move the cursor UP by that exact amount
        if test $prev_lines -gt 0
            printf "\033[%dA" $prev_lines
        end

        set current_lines 0
        printf "\033[2K\r------------------------------------------------------\n"
        set current_lines (math $current_lines + 1)

        if test -z "$current_pods"
            printf "\033[2K\r⏳ No matching pods found yet. Waiting for Kubernetes to schedule...\n"
            set current_lines (math $current_lines + 1)
        else
            set pod_lines (string split \n (string trim "$current_pods"))

            for line in $pod_lines
                printf "\033[2K\r%s\n" $line
                set current_lines (math $current_lines + 1)
            end

            set pending_pods (echo "$current_pods" | grep -v -E '\b(Running)\b')

            if test -z "$pending_pods"
                printf "\033[2K\r------------------------------------------------------\n"
                printf "\033[2K\r🎉 All updated pods are successfully Running!\n"
                break
            end
        end

        set prev_lines $current_lines
        sleep 10
    end
end
