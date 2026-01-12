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

function aivepipeline
    cd ~/aive/;
    set changed_pkgs (tools/list-changed-packages.py origin/main | jq '.[]' -r | sort)
    for pkg in $changed_pkgs
        echo " "
        echo " "
        set pkg_len (string length $pkg)
        set limiter_str ""
        for i in (seq $pkg_len)
            set limiter_str "$limiter_str-"
        end
        echo " $limiter_str "
        echo " $pkg "
        echo " $limiter_str "
        if not string match -q '*/*' -- $pkg
            make build-ci pkg=$pkg
        end
        make test-ci pkg=$pkg
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

function aivedeploy -d "End-to-end deploy: tag, push, update kustomization, and diff"
    if test (count $argv) -eq 0
        echo "⚠️  No arguments provided."
        echo "Usage: aivedeploy [patch|minor|major] [services...]"
        return 1
    end
    cd ~/aive || begin
        echo "❌ Error: Could not change directory to ~/aive"
        return 1
    end

    echo "🚀 Running auto-tag..."
    set tags (~/aive/tools/auto-tag $argv)
    if test (count $tags) -eq 0
        echo "⚠️  No tags were output by auto-tag. Aborting deploy."
        return 1
    end

    echo "📦 Captured tags:"
    for t in $tags
        echo "  - $t"
    end
    aivetag $tags

    cd ~/stack || begin
        echo "❌ Error: Could not change directory to ~/stack"
        return 1
    end
    echo "⬇️  Pulling latest 'stack' changes from git..."
    git pull || begin
        echo "❌ Error: Failed to git pull in ~/stack. Please resolve conflicts or stash changes."
        return 1
    end
    echo "📝 Updating kustomization.yaml..."
    aivetag_update $tags

    echo "🔍 Running kubediff..."
    kubediff
end
